import { randomUUID } from 'node:crypto';
import { and, desc, eq, ilike, inArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { Db } from '../../db/client.js';
import { medicalRecords, pharmacyOrders, prescriptions, products } from '../../db/schema.js';
import { assertCanActForPatient, listActablePatients } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { envelope, list, pageFromQuery } from '../../lib/pagination.js';
import { iso } from '../../lib/time.js';
import { parse, zAddress, zUuid } from '../../lib/validate.js';
import { toPayment, type PaymentEffects, type PaymentRow } from '../payments/service.js';

export const PHARMACY_CATEGORIES = [
  { code: 'fever_pain', name: 'Fever & Pain', icon: 'thermometer' },
  { code: 'vitamins', name: 'Vitamins & Supplements', icon: 'pill' },
  { code: 'diabetes', name: 'Diabetes Care', icon: 'droplet' },
  { code: 'heart_bp', name: 'Heart & BP', icon: 'heart' },
  { code: 'antibiotics', name: 'Antibiotics (Rx)', icon: 'prescription' },
  { code: 'personal_care', name: 'Personal Care', icon: 'sparkles' },
  { code: 'devices', name: 'Health Devices', icon: 'activity' },
];

/** Partner adapter boundary (sandbox partner in dev). */
export const PARTNER_NAME = 'Partner Pharmacy (sandbox)';

const toProduct = (p: typeof products.$inferSelect) => ({
  id: p.id,
  name: p.name,
  packSize: p.packSize,
  mrp: p.mrp,
  price: p.price,
  category: p.category,
  requiresPrescription: p.requiresPrescription,
  imageUrl: p.imageUrl,
  inStock: p.inStock,
});

const toOrder = (o: typeof pharmacyOrders.$inferSelect) => ({
  id: o.id,
  patientId: o.patientId,
  items: o.items,
  total: o.total,
  status: o.status,
  partnerName: o.partnerName,
  createdAt: iso(o.createdAt),
});

export const pharmacyPaymentEffects: PaymentEffects = {
  async onSucceeded(db: Db, p: PaymentRow) {
    await db.update(pharmacyOrders).set({ status: 'placed' }).where(and(eq(pharmacyOrders.id, p.refId), eq(pharmacyOrders.status, 'pending_payment')));
  },
  async onFailed(db: Db, p: PaymentRow) {
    await db.update(pharmacyOrders).set({ status: 'cancelled' }).where(and(eq(pharmacyOrders.id, p.refId), eq(pharmacyOrders.status, 'pending_payment')));
  },
  async onRetry(tx, p: PaymentRow) {
    // An order cancelled only because its payment failed can be paid again.
    await tx.update(pharmacyOrders).set({ status: 'pending_payment' }).where(and(eq(pharmacyOrders.id, p.refId), eq(pharmacyOrders.status, 'cancelled')));
  },
};

export async function pharmacyRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/pharmacy/categories', async () => list(PHARMACY_CATEGORIES));

  app.get('/pharmacy/products', async (req) => {
    const q = parse(z.object({ q: z.string().max(100).optional(), category: z.string().max(40).optional() }), req.query);
    const page = pageFromQuery(req.query);
    const conds = [];
    if (q.q) conds.push(ilike(products.name, `%${q.q}%`));
    if (q.category) conds.push(eq(products.category, q.category));
    const rows = await db
      .select()
      .from(products)
      .where(conds.length ? and(...conds) : undefined)
      .orderBy(products.name)
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toProduct), page);
  });

  app.post('/pharmacy/orders', { config: { idempotent: true } }, async (req, reply) => {
    await svc.flags.require('pharmacy_orders');
    const body = parse(
      z.object({
        patientId: zUuid,
        items: z.array(z.object({ productId: zUuid, qty: z.number().int().min(1).max(20) })).min(1).max(30),
        prescriptionRecordId: zUuid.optional(),
        /** Contract section 31: an e-prescription id satisfies the Rx requirement in place of prescriptionRecordId. */
        prescriptionId: zUuid.optional(),
        address: zAddress,
      }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, 'book', 'pharmacy_order.create');
    const prods = await db.select().from(products).where(inArray(products.id, body.items.map((i) => i.productId)));
    const pm = new Map(prods.map((p) => [p.id, p]));
    for (const i of body.items) {
      const p = pm.get(i.productId);
      if (!p) throw errors.validation('Unknown product', { productId: i.productId });
      if (!p.inStock) throw errors.validation('Product out of stock', { productId: i.productId });
    }
    let prescriptionRecordId = body.prescriptionRecordId ?? null;
    if (body.prescriptionId) {
      const [rx] = await db.select().from(prescriptions).where(eq(prescriptions.id, body.prescriptionId));
      if (!rx || rx.patientId !== body.patientId) throw errors.validation('prescriptionId must be a prescription of this patient', { field: 'prescriptionId' });
      prescriptionRecordId = rx.recordId;
    }
    const needsRx = body.items.some((i) => pm.get(i.productId)!.requiresPrescription);
    if (needsRx) {
      if (!prescriptionRecordId) throw errors.validation('A prescription is required for one or more items', { field: 'prescriptionRecordId' });
      const [rec] = await db.select().from(medicalRecords).where(eq(medicalRecords.id, prescriptionRecordId));
      if (!rec || rec.patientId !== body.patientId || rec.type !== 'prescription') {
        throw errors.validation('prescriptionRecordId must be a prescription record of this patient');
      }
    }
    const items = body.items.map((i) => {
      const p = pm.get(i.productId)!;
      return { productId: p.id, name: p.name, qty: i.qty, price: p.price };
    });
    const total = items.reduce((s, i) => s + i.qty * i.price, 0);
    const result = await db.transaction(async (tx) => {
      const [order] = await tx
        .insert(pharmacyOrders)
        .values({
          id: randomUUID(),
          patientId: body.patientId,
          items,
          total,
          partnerName: PARTNER_NAME,
          prescriptionRecordId,
          address: body.address,
          createdByUserId: req.ctx.user.id,
        })
        .returning();
      const payment = await svc.payments.create(tx, { purpose: 'pharmacy_order', refId: order.id, patientId: body.patientId, amount: total, userId: req.ctx.user.id });
      await audit(tx, req.ctx.actor, { action: 'pharmacy_order.create', entityType: 'pharmacy_order', entityId: order.id, metadata: { itemCount: items.length } });
      return { order, payment };
    });
    return reply.code(201).send({ order: toOrder(result.order), payment: toPayment(result.payment) });
  });

  app.get('/pharmacy/orders', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional() }), req.query);
    const page = pageFromQuery(req.query);
    let ids: string[];
    if (q.patientId) {
      await assertCanActForPatient(db, req.ctx, q.patientId, 'book', 'pharmacy_order.list');
      ids = [q.patientId];
    } else {
      ids = (await listActablePatients(db, req.ctx.user)).filter((p) => p.permissions.includes('book')).map((p) => p.patientId);
    }
    if (!ids.length) return { items: [], nextCursor: null };
    const rows = await db
      .select()
      .from(pharmacyOrders)
      .where(inArray(pharmacyOrders.patientId, ids))
      .orderBy(desc(pharmacyOrders.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toOrder), page);
  });
}
