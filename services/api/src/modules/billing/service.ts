import { and, eq, gte, inArray, lt, sql } from 'drizzle-orm';
import type { Config } from '../../config.js';
import type { Db, DbOrTx } from '../../db/client.js';
import {
  appointments,
  homeVisitServices,
  homeVisits,
  invoices,
  patients,
  payments,
  pharmacyOrders,
  providers,
  subscriptionPlans,
  subscriptions,
  users,
  type InvoiceLineJson,
} from '../../db/schema.js';
import { errors } from '../../lib/errors.js';
import { PLATFORM_NAME, PdfBuilder, pdfDate } from '../../lib/pdf.js';
import { addDays, istDate, istDayBounds, iso } from '../../lib/time.js';
import type { StorageAdapter } from '../records/storage.js';

export type InvoiceRow = typeof invoices.$inferSelect;
export type PaymentRow = typeof payments.$inferSelect;

export const INVOICEABLE = ['succeeded', 'refunded', 'partially_refunded'];

/** Indian financial year (April-March, IST) label, e.g. "2026-27". */
export function indianFy(d: Date): string {
  const [y, m] = istDate(d).split('-').map(Number);
  const start = m >= 4 ? y : y - 1;
  return `${start}-${String((start + 1) % 100).padStart(2, '0')}`;
}

export const invoiceNumber = (fy: string, seq: number): string => `CC/${fy}/${String(seq).padStart(6, '0')}`;

/** SAC codes are placeholders pending tax review [REQUIRES TAX REVIEW]. Goods (pharmacy) carry HSN codes per item, so null here. */
const SAC: Record<string, string | null> = { appointment: '999312', home_visit: '999319', subscription: '999319', pharmacy_order: null };
const MODE_LABEL: Record<string, string> = { video: 'Video', audio: 'Audio', chat: 'Chat', in_clinic: 'In-clinic' };

async function describePayment(db: DbOrTx, p: PaymentRow): Promise<string> {
  if (p.purpose === 'appointment') {
    const [a] = await db
      .select({ mode: appointments.mode, startAt: appointments.startAt, doctor: providers.name })
      .from(appointments)
      .innerJoin(providers, eq(providers.id, appointments.doctorId))
      .where(eq(appointments.id, p.refId));
    return a ? `${MODE_LABEL[a.mode] ?? 'Doctor'} consultation with ${a.doctor} on ${pdfDate(a.startAt)}` : 'Doctor consultation';
  }
  if (p.purpose === 'home_visit') {
    const [v] = await db
      .select({ name: homeVisitServices.name, at: homeVisits.preferredStart, discount: homeVisits.discountApplied })
      .from(homeVisits)
      .innerJoin(homeVisitServices, eq(homeVisitServices.code, homeVisits.serviceCode))
      .where(eq(homeVisits.id, p.refId));
    return v ? `Home visit: ${v.name} on ${pdfDate(v.at)}${v.discount ? ` (care plan discount INR ${v.discount} applied)` : ''}` : 'Home visit';
  }
  if (p.purpose === 'pharmacy_order') {
    const [o] = await db.select({ items: pharmacyOrders.items }).from(pharmacyOrders).where(eq(pharmacyOrders.id, p.refId));
    return o ? `Pharmacy order (${o.items.reduce((n, i) => n + i.qty, 0)} items) via partner pharmacy` : 'Pharmacy order';
  }
  if (p.purpose === 'subscription') {
    const [s] = await db
      .select({ name: subscriptionPlans.name, billing: subscriptions.billing })
      .from(subscriptions)
      .innerJoin(subscriptionPlans, eq(subscriptionPlans.code, subscriptions.planCode))
      .where(eq(subscriptions.id, p.refId));
    return s ? `Family Care Plan: ${s.name} (${s.billing})` : 'Family Care Plan subscription';
  }
  return 'CareCompanion service';
}

/**
 * Issue (once) the invoice of a paid payment. Numbering is sequential per Indian financial year and
 * concurrency-safe: the payment row is locked, then the FY counter row is incremented with an atomic upsert
 * inside the same transaction (a unique (fy, seq) index backs it up).
 */
export async function ensureInvoice(db: Db, config: Config, paymentId: string, now = new Date()): Promise<InvoiceRow> {
  const [existing] = await db.select().from(invoices).where(eq(invoices.paymentId, paymentId));
  if (existing) return existing;
  const [pay] = await db.select().from(payments).where(eq(payments.id, paymentId));
  if (!pay) throw errors.notFound('Payment');
  if (!INVOICEABLE.includes(pay.status)) throw errors.conflict('An invoice is available only for paid payments', { status: pay.status });
  const description = await describePayment(db, pay);
  const [payer] = pay.createdByUserId ? await db.select({ name: users.name, phone: users.phone }).from(users).where(eq(users.id, pay.createdByUserId)) : [];
  const [pat] = await db.select({ name: patients.name, phone: patients.phone }).from(patients).where(eq(patients.id, pay.patientId));
  const billedTo = { name: payer?.name ?? pat?.name ?? 'Customer', phone: payer?.phone ?? pat?.phone ?? '' };
  const rate = config.HEALTHCARE_GST_RATE;
  const total = pay.amount;
  const subtotal = rate > 0 ? Math.round((total * 100) / (100 + rate)) : total;
  const tax = total - subtotal;
  const lines: InvoiceLineJson[] = [{ description, sacCode: SAC[pay.purpose] ?? null, amount: subtotal, taxRate: rate, taxAmount: tax }];
  const seller = { legalName: config.SELLER_LEGAL_NAME, gstin: config.SELLER_GSTIN ?? null, address: config.SELLER_ADDRESS };
  const fy = indianFy(now);
  return db.transaction(async (tx) => {
    await tx.execute(sql`select id from payments where id = ${paymentId} for update`);
    const [again] = await tx.select().from(invoices).where(eq(invoices.paymentId, paymentId));
    if (again) return again;
    const res = await tx.execute(
      sql`insert into invoice_counters (fy, last_seq) values (${fy}, 1)
          on conflict (fy) do update set last_seq = invoice_counters.last_seq + 1
          returning last_seq`,
    );
    const rows = ((res as unknown as { rows?: Array<{ last_seq: number }> }).rows ?? (res as unknown as Array<{ last_seq: number }>)) as Array<{ last_seq: number }>;
    const seq = Number(rows[0].last_seq);
    const [row] = await tx
      .insert(invoices)
      .values({ paymentId, number: invoiceNumber(fy, seq), fy, seq, issuedAt: now, billedTo, seller, lines, subtotal, tax, total })
      .returning();
    return row;
  });
}

export const toInvoice = (inv: InvoiceRow, pay: PaymentRow) => ({
  number: inv.number,
  paymentId: inv.paymentId,
  issuedAt: iso(inv.issuedAt),
  billedTo: inv.billedTo,
  seller: inv.seller,
  lines: inv.lines,
  subtotal: inv.subtotal,
  tax: inv.tax,
  total: inv.total,
  refundedAmount: pay.refundedAmount,
  currency: 'INR' as const,
});

const inr = (n: number) => `INR ${n.toLocaleString('en-IN')}`;

export async function renderInvoicePdf(inv: InvoiceRow, pay: PaymentRow): Promise<Buffer> {
  const b = new PdfBuilder(inv.tax > 0 ? 'Tax Invoice' : 'Invoice', `${inv.number}  |  ${pdfDate(inv.issuedAt)}`, { subject: 'Invoice' });
  b.infoBoxes([
    {
      title: 'Seller',
      rows: [
        ['Name', inv.seller.legalName],
        ['GSTIN', inv.seller.gstin ?? 'Not applicable'],
        ['Address', inv.seller.address],
      ],
    },
    {
      title: 'Billed to',
      rows: [
        ['Name', inv.billedTo.name],
        ['Phone', inv.billedTo.phone],
        ['Invoice no.', inv.number],
        ['Date', pdfDate(inv.issuedAt)],
      ],
    },
  ]);
  b.heading('Details');
  b.table(
    [
      { header: 'Description', width: 250 },
      { header: 'SAC', width: 60 },
      { header: 'Amount', width: 80, align: 'right' },
      { header: 'Tax rate', width: 60, align: 'right' },
      { header: 'Tax', width: 70, align: 'right' },
    ],
    inv.lines.map((l) => [l.description, l.sacCode ?? '-', inr(l.amount), `${l.taxRate}%`, inr(l.taxAmount)]),
  );
  const rows: Array<[string, string]> = [
    ['Subtotal', inr(inv.subtotal)],
    ['Tax', inr(inv.tax)],
  ];
  if (pay.refundedAmount > 0) rows.push(['Refunded', `- ${inr(pay.refundedAmount)}`]);
  rows.push(['Total paid', inr(inv.total)]);
  b.totals(rows);
  b.spacer(1);
  b.paragraph(`Payment reference: ${pay.gatewayPaymentId ?? pay.gatewayOrderId} (${pay.gateway}). Amounts in Indian Rupees.`, { size: 8.5, color: '#6B7280' });
  return b.finish([`Computer-generated invoice issued by ${PLATFORM_NAME}; no signature required.`, 'For billing questions contact support from the app.']);
}

/** Stored once through the storage abstraction, then served from storage. */
export async function invoicePdf(db: Db, storage: StorageAdapter, inv: InvoiceRow, pay: PaymentRow): Promise<Buffer> {
  if (inv.pdfStorageKey) {
    try {
      return await storage.get(inv.pdfStorageKey);
    } catch {
      /* regenerate below */
    }
  }
  const pdf = await renderInvoicePdf(inv, pay);
  const key = `invoices/${inv.fy}/${inv.number.replace(/\//g, '-')}-${Date.now()}.pdf`;
  await storage.put(key, pdf, 'application/pdf');
  await db.update(invoices).set({ pdfStorageKey: key }).where(eq(invoices.id, inv.id));
  return pdf;
}

// ---------------------------------------------------------------- earnings & settlements
export interface EarningsLine {
  date: string;
  description: string;
  refType: 'appointment' | 'home_visit';
  refId: string;
  amount: number;
  platformFee: number;
  payable: number;
}

export function currentIstMonth(now = new Date()): { from: string; to: string } {
  const today = istDate(now);
  const from = `${today.slice(0, 7)}-01`;
  const [y, m] = from.split('-').map(Number);
  const next = new Date(Date.UTC(y, m, 1)).toISOString().slice(0, 10);
  return { from, to: addDays(next, -1) };
}

/**
 * Earnings per doctor/provider. Only completed AND paid services count. For each service:
 * net = amount - refunded; platformFee = round(net * PLATFORM_FEE_PCT / 100); payable = net - platformFee.
 * Totals: payable = grossAmount - refunds - platformFee.
 */
export async function computeEarnings(db: DbOrTx, feePct: number, from: string, to: string, providerIds?: string[]) {
  const start = istDayBounds(from).start;
  const end = istDayBounds(to).end;
  const appts = await db
    .select({ a: appointments, p: payments })
    .from(appointments)
    .innerJoin(payments, and(eq(payments.purpose, 'appointment'), eq(payments.refId, appointments.id)))
    .where(
      and(
        eq(appointments.status, 'completed'),
        gte(appointments.startAt, start),
        lt(appointments.startAt, end),
        inArray(payments.status, INVOICEABLE),
        ...(providerIds ? [inArray(appointments.doctorId, providerIds.length ? providerIds : ['00000000-0000-0000-0000-000000000000'])] : []),
      ),
    );
  const visits = await db
    .select({ v: homeVisits, p: payments, service: homeVisitServices.name })
    .from(homeVisits)
    .innerJoin(payments, and(eq(payments.purpose, 'home_visit'), eq(payments.refId, homeVisits.id)))
    .innerJoin(homeVisitServices, eq(homeVisitServices.code, homeVisits.serviceCode))
    .where(
      and(
        eq(homeVisits.status, 'completed'),
        gte(homeVisits.completedAt, start),
        lt(homeVisits.completedAt, end),
        inArray(payments.status, INVOICEABLE),
        ...(providerIds ? [inArray(homeVisits.providerId, providerIds.length ? providerIds : ['00000000-0000-0000-0000-000000000000'])] : []),
      ),
    );
  const byProvider = new Map<string, { lines: EarningsLine[]; refunds: number }>();
  const add = (providerId: string, line: EarningsLine, refunded: number) => {
    const e = byProvider.get(providerId) ?? { lines: [], refunds: 0 };
    e.lines.push(line);
    e.refunds += refunded;
    byProvider.set(providerId, e);
  };
  const lineFor = (amount: number, refunded: number) => {
    const net = Math.max(0, amount - refunded);
    const platformFee = Math.round((net * feePct) / 100);
    return { amount, platformFee, payable: net - platformFee };
  };
  for (const { a, p } of appts) {
    add(a.doctorId, { date: istDate(a.startAt), description: `${MODE_LABEL[a.mode] ?? 'Doctor'} consultation`, refType: 'appointment', refId: a.id, ...lineFor(p.amount, p.refundedAmount) }, p.refundedAmount);
  }
  for (const { v, p, service } of visits) {
    if (!v.providerId) continue;
    add(v.providerId, { date: istDate(v.completedAt ?? v.preferredStart), description: `Home visit: ${service}`, refType: 'home_visit', refId: v.id, ...lineFor(p.amount, p.refundedAmount) }, p.refundedAmount);
  }
  const ids = providerIds ?? [...byProvider.keys()];
  const provs = ids.length ? await db.select().from(providers).where(inArray(providers.id, ids)) : [];
  return provs
    .map((prov) => {
      const e = byProvider.get(prov.id) ?? { lines: [], refunds: 0 };
      const lines = e.lines.sort((x, y) => x.date.localeCompare(y.date) || x.refId.localeCompare(y.refId));
      const grossAmount = lines.reduce((s, l) => s + l.amount, 0);
      const platformFee = lines.reduce((s, l) => s + l.platformFee, 0);
      return {
        providerId: prov.id,
        providerName: prov.name,
        role: (prov.kind === 'doctor' ? 'doctor' : 'provider') as 'doctor' | 'provider',
        from,
        to,
        completedServices: lines.length,
        grossAmount,
        platformFee,
        refunds: e.refunds,
        payable: grossAmount - e.refunds - platformFee,
        lines,
      };
    })
    .sort((a, b) => a.providerName.localeCompare(b.providerName));
}

export type Earnings = Awaited<ReturnType<typeof computeEarnings>>[number];

const csvCell = (v: string | number) => {
  if (typeof v === 'number') return String(v);
  const s = v;
  const safe = /^[=+\-@\t\r]/.test(s) ? `'${s}` : s; // no formula injection in spreadsheets
  return /[",\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
};

export function settlementsCsv(rows: Earnings[]): string {
  const header = ['providerId', 'providerName', 'role', 'from', 'to', 'completedServices', 'grossAmount', 'platformFee', 'refunds', 'payable'];
  const body = rows.map((r) => [r.providerId, r.providerName, r.role, r.from, r.to, r.completedServices, r.grossAmount, r.platformFee, r.refunds, r.payable].map(csvCell).join(','));
  return [header.join(','), ...body].join('\n') + '\n';
}
