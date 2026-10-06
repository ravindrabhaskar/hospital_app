import { eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { payments } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { hasRole } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { parse, zDate, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { computeEarnings, currentIstMonth, ensureInvoice, invoicePdf, settlementsCsv, toInvoice } from './service.js';

const zRange = z.object({ from: zDate.optional(), to: zDate.optional() });

function range(q: { from?: string; to?: string }): { from: string; to: string } {
  const def = currentIstMonth();
  const from = q.from ?? (q.to ? `${q.to.slice(0, 7)}-01` : def.from);
  const to = q.to ?? (q.from ? currentIstMonthOf(q.from).to : def.to);
  if (from > to) throw errors.validation('from must not be after to');
  const days = (Date.parse(to) - Date.parse(from)) / 86400_000;
  if (days > 366) throw errors.validation('The range may span at most 366 days');
  return { from, to };
}
const currentIstMonthOf = (date: string) => currentIstMonth(new Date(`${date}T06:30:00Z`));

/** Contract section 32: invoices, earnings and settlements. */
export async function billingRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  const loadPaid = async (id: string, reqCtx: Parameters<typeof assertCanActForPatient>[1]) => {
    const [p] = await db.select().from(payments).where(eq(payments.id, id));
    if (!p) throw errors.notFound('Payment');
    const access = await assertCanActForPatient(db, reqCtx, p.patientId, ['book', 'staff_ops'], 'invoice.read');
    // B14: staff access to invoices is finance-only (ops_admin / super_admin); coordinators are refused.
    if (!access.permissions.has('book') && !hasRole(reqCtx.user, 'ops_admin', 'super_admin')) {
      await audit(db, reqCtx.actor, { action: 'invoice.read', entityType: 'payment', entityId: p.id, outcome: 'denied' });
      throw errors.forbidden();
    }
    const inv = await ensureInvoice(db, svc.config, p.id);
    const [fresh] = await db.select().from(payments).where(eq(payments.id, id));
    return { inv, pay: fresh };
  };

  app.get('/payments/:id/invoice', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const { inv, pay } = await loadPaid(id, req.ctx);
    return toInvoice(inv, pay);
  });

  app.get('/payments/:id/invoice.pdf', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const { inv, pay } = await loadPaid(id, req.ctx);
    const pdf = await invoicePdf(db, svc.storage, inv, pay);
    await audit(db, req.ctx.actor, { action: 'invoice.download', entityType: 'payment', entityId: id });
    return reply
      .header('content-type', 'application/pdf')
      .header('content-disposition', `inline; filename="invoice-${inv.number.replace(/\//g, '-')}.pdf"`)
      .header('cache-control', 'private, no-store')
      .send(pdf);
  });

  app.get('/provider/earnings', { preHandler: requireRoles(svc, 'doctor', 'provider') }, async (req) => {
    const r = range(parse(zRange, req.query));
    const providerId = req.ctx.user.providerId;
    if (!providerId) throw errors.forbidden('Provider profile required');
    const [e] = await computeEarnings(db, svc.config.PLATFORM_FEE_PCT, r.from, r.to, [providerId]);
    if (!e) throw errors.notFound('Provider');
    return e;
  });

  const opsFinance = requireRoles(svc, 'ops_admin', 'super_admin');

  app.get('/ops/settlements', { preHandler: opsFinance }, async (req) => {
    const r = range(parse(zRange, req.query));
    const page = pageFromQuery(req.query);
    const rows = (await computeEarnings(db, svc.config.PLATFORM_FEE_PCT, r.from, r.to)).filter((e) => e.completedServices > 0);
    return paginateArray(rows, page);
  });

  app.get('/ops/settlements.csv', { preHandler: opsFinance }, async (req, reply) => {
    const r = range(parse(zRange, req.query));
    const rows = (await computeEarnings(db, svc.config.PLATFORM_FEE_PCT, r.from, r.to)).filter((e) => e.completedServices > 0);
    await audit(db, req.ctx.actor, { action: 'settlements.export', entityType: 'settlement', metadata: { from: r.from, to: r.to, rows: rows.length } });
    return reply
      .header('content-type', 'text/csv; charset=utf-8')
      .header('content-disposition', `attachment; filename="settlements-${r.from}-to-${r.to}.csv"`)
      .header('cache-control', 'private, no-store')
      .send(settlementsCsv(rows));
  });
}
