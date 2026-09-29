import PDFDocument from 'pdfkit';

/**
 * Small layout kit on top of pdfkit for server-generated documents (e-prescriptions, invoices, referral letters).
 * Standard PDF fonts (Helvetica) only: no font files to ship. Text outside Latin-1 is replaced so the
 * PDF never contains broken glyphs. Documents carry only the minimum necessary data.
 */
export const PLATFORM_NAME = 'CareCompanion';

const BRAND = '#0F766E';
const BRAND_LIGHT = '#E6F4F1';
const INK = '#1F2937';
const MUTED = '#6B7280';
const RULE = '#D1D5DB';

/** Keep only characters the standard fonts can render. */
export function pdfSafe(text: string | null | undefined): string {
  if (!text) return '';
  return text
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[–—]/g, '-')
    .replace(/₹/g, 'INR ')
    .replace(/\t/g, ' ')
    .replace(/\r\n?/g, '\n')
    .replace(/[^\n\x20-\x7E\xA0-\xFF]/g, '?');
}

export interface TableColumn {
  header: string;
  width: number;
  align?: 'left' | 'right' | 'center';
}

export class PdfBuilder {
  readonly doc: PDFKit.PDFDocument;
  private readonly chunks: Buffer[] = [];
  private readonly done: Promise<Buffer>;
  private readonly left = 50;
  private readonly right: number;

  constructor(
    private readonly title: string,
    private readonly subtitle: string | null = null,
    meta: { author?: string; subject?: string } = {},
  ) {
    this.doc = new PDFDocument({
      size: 'A4',
      margins: { top: 50, bottom: 70, left: 50, right: 50 },
      bufferPages: true,
      info: { Title: `${PLATFORM_NAME} - ${title}`, Author: meta.author ?? PLATFORM_NAME, Subject: meta.subject ?? title, Producer: PLATFORM_NAME },
    });
    this.right = this.doc.page.width - 50;
    this.done = new Promise((resolve, reject) => {
      this.doc.on('data', (c: Buffer) => this.chunks.push(c));
      this.doc.on('end', () => resolve(Buffer.concat(this.chunks)));
      this.doc.on('error', reject);
    });
    this.header();
  }

  get width(): number {
    return this.right - this.left;
  }

  private header(): void {
    const d = this.doc;
    d.save().rect(0, 0, d.page.width, 78).fill(BRAND).restore();
    d.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(20).text(PLATFORM_NAME, this.left, 22, { lineBreak: false });
    d.font('Helvetica').fontSize(8.5).fillColor('#D1FAE5').text('Connected care for families', this.left, 47, { lineBreak: false });
    d.font('Helvetica-Bold').fontSize(14).fillColor('#FFFFFF').text(pdfSafe(this.title), this.left, 24, { width: this.width, align: 'right' });
    if (this.subtitle) d.font('Helvetica').fontSize(8.5).fillColor('#D1FAE5').text(pdfSafe(this.subtitle), this.left, 45, { width: this.width, align: 'right' });
    d.fillColor(INK);
    d.y = 98;
    d.x = this.left;
  }

  private ensureSpace(h: number): void {
    const d = this.doc;
    if (d.y + h > d.page.height - d.page.margins.bottom) {
      d.addPage();
      d.y = d.page.margins.top;
    }
  }

  /** Section heading with a thin brand rule underneath. */
  heading(text: string): this {
    const d = this.doc;
    this.ensureSpace(40);
    d.moveDown(0.6);
    d.font('Helvetica-Bold').fontSize(11).fillColor(BRAND).text(pdfSafe(text).toUpperCase(), this.left, d.y, { characterSpacing: 0.6 });
    const y = d.y + 2;
    d.save().moveTo(this.left, y).lineTo(this.right, y).lineWidth(0.8).strokeColor(BRAND).stroke().restore();
    d.y = y + 6;
    d.fillColor(INK);
    return this;
  }

  paragraph(text: string, opts: { size?: number; color?: string; bold?: boolean } = {}): this {
    const d = this.doc;
    const s = pdfSafe(text);
    d.font(opts.bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(opts.size ?? 10);
    this.ensureSpace(Math.min(d.heightOfString(s, { width: this.width }) + 4, 200));
    d.fillColor(opts.color ?? INK).text(s, this.left, d.y, { width: this.width, lineGap: 2 });
    d.fillColor(INK);
    return this;
  }

  /** Side-by-side shaded info boxes, e.g. doctor + patient. Each row is [label, value]. */
  infoBoxes(boxes: Array<{ title: string; rows: Array<[string, string]> }>): this {
    const d = this.doc;
    const gap = 12;
    const w = (this.width - gap * (boxes.length - 1)) / boxes.length;
    const pad = 9;
    const labelW = 78;
    const heights = boxes.map((b) => {
      let h = pad * 2 + 16;
      d.font('Helvetica').fontSize(9);
      for (const [, v] of b.rows) h += Math.max(12, d.heightOfString(pdfSafe(v) || '-', { width: w - pad * 2 - labelW })) + 3;
      return h;
    });
    const h = Math.max(...heights);
    this.ensureSpace(h + 10);
    const top = d.y + 4;
    boxes.forEach((b, i) => {
      const x = this.left + i * (w + gap);
      d.save().roundedRect(x, top, w, h, 4).fill(BRAND_LIGHT).restore();
      d.save().rect(x, top, 3, h).fill(BRAND).restore();
      d.font('Helvetica-Bold').fontSize(9.5).fillColor(BRAND).text(pdfSafe(b.title).toUpperCase(), x + pad + 2, top + pad, { width: w - pad * 2, characterSpacing: 0.4 });
      let y = top + pad + 16;
      for (const [k, v] of b.rows) {
        d.font('Helvetica').fontSize(8.5).fillColor(MUTED).text(pdfSafe(k), x + pad + 2, y, { width: labelW - 4 });
        d.font('Helvetica').fontSize(9).fillColor(INK);
        const val = pdfSafe(v) || '-';
        d.text(val, x + pad + labelW, y, { width: w - pad * 2 - labelW });
        y += Math.max(12, d.heightOfString(val, { width: w - pad * 2 - labelW })) + 3;
      }
    });
    d.y = top + h + 6;
    d.x = this.left;
    d.fillColor(INK);
    return this;
  }

  /** Bordered table with a shaded header row and zebra rows; wraps cell text and repeats the header on new pages. */
  table(columns: TableColumn[], rows: string[][], opts: { fontSize?: number } = {}): this {
    const d = this.doc;
    const size = opts.fontSize ?? 9;
    const total = columns.reduce((s, c) => s + c.width, 0);
    const scale = this.width / total;
    const cols = columns.map((c) => ({ ...c, width: c.width * scale }));
    const pad = 5;
    const drawHeader = () => {
      const top = d.y;
      d.font('Helvetica-Bold').fontSize(size);
      const h = Math.max(...cols.map((c) => d.heightOfString(pdfSafe(c.header), { width: c.width - pad * 2 }))) + pad * 2;
      d.save().rect(this.left, top, this.width, h).fill(BRAND).restore();
      let x = this.left;
      for (const c of cols) {
        d.fillColor('#FFFFFF').text(pdfSafe(c.header), x + pad, top + pad, { width: c.width - pad * 2, align: c.align ?? 'left' });
        x += c.width;
      }
      d.y = top + h;
      d.fillColor(INK);
    };
    this.ensureSpace(40);
    drawHeader();
    rows.forEach((row, ri) => {
      d.font('Helvetica').fontSize(size);
      const h = Math.max(...cols.map((c, i) => d.heightOfString(pdfSafe(row[i] ?? '') || ' ', { width: c.width - pad * 2 }))) + pad * 2;
      if (d.y + h > d.page.height - d.page.margins.bottom) {
        d.addPage();
        d.y = d.page.margins.top;
        drawHeader();
        d.font('Helvetica').fontSize(size);
      }
      const top = d.y;
      if (ri % 2 === 1) d.save().rect(this.left, top, this.width, h).fill('#F9FAFB').restore();
      let x = this.left;
      cols.forEach((c, i) => {
        d.fillColor(INK).text(pdfSafe(row[i] ?? ''), x + pad, top + pad, { width: c.width - pad * 2, align: c.align ?? 'left' });
        x += c.width;
      });
      d.save().moveTo(this.left, top + h).lineTo(this.right, top + h).lineWidth(0.5).strokeColor(RULE).stroke().restore();
      d.y = top + h;
    });
    d.save().rect(this.left, d.y, 0, 0).restore();
    d.x = this.left;
    d.moveDown(0.4);
    return this;
  }

  /** Right-aligned totals block (label/value pairs); the last row is emphasised. */
  totals(rows: Array<[string, string]>): this {
    const d = this.doc;
    const w = 220;
    const x = this.right - w;
    this.ensureSpace(rows.length * 18 + 10);
    rows.forEach(([k, v], i) => {
      const last = i === rows.length - 1;
      const y = d.y;
      if (last) d.save().rect(x, y - 2, w, 18).fill(BRAND_LIGHT).restore();
      d.font(last ? 'Helvetica-Bold' : 'Helvetica').fontSize(last ? 10.5 : 9.5).fillColor(INK);
      d.text(pdfSafe(k), x + 6, y + 2, { width: w / 2, lineBreak: false });
      d.text(pdfSafe(v), x + w / 2, y + 2, { width: w / 2 - 6, align: 'right', lineBreak: false });
      d.y = y + 18;
    });
    d.x = this.left;
    return this;
  }

  /** Signature line block at the right-hand side. */
  signature(lines: string[]): this {
    const d = this.doc;
    this.ensureSpace(80);
    d.moveDown(2);
    const w = 200;
    const x = this.right - w;
    const y = d.y + 24;
    d.save().moveTo(x, y).lineTo(this.right, y).lineWidth(0.8).strokeColor(INK).stroke().restore();
    d.y = y + 4;
    lines.forEach((l, i) => {
      d.font(i === 0 ? 'Helvetica-Bold' : 'Helvetica').fontSize(i === 0 ? 9.5 : 8.5).fillColor(i === 0 ? INK : MUTED).text(pdfSafe(l), x, d.y, { width: w, align: 'center' });
    });
    d.fillColor(INK);
    d.x = this.left;
    return this;
  }

  spacer(lines = 0.6): this {
    this.doc.moveDown(lines);
    return this;
  }

  private watermarkText: string | null = null;

  /** Stamp a large diagonal watermark on every page (e.g. "SAMPLE REPORT — NOT A REAL RESULT"). */
  watermark(text: string): this {
    this.watermarkText = text;
    return this;
  }

  /** Stamp the footer on every page and return the PDF bytes. */
  async finish(footerLines: string[]): Promise<Buffer> {
    const d = this.doc;
    const range = d.bufferedPageRange();
    for (let i = range.start; i < range.start + range.count; i++) {
      d.switchToPage(i);
      if (this.watermarkText) {
        const cx = d.page.width / 2;
        const cy = d.page.height / 2;
        d.save();
        d.rotate(-35, { origin: [cx, cy] });
        d.font('Helvetica-Bold').fontSize(30).fillColor('#DC2626').fillOpacity(0.22);
        d.text(pdfSafe(this.watermarkText), cx - 330, cy - 18, { width: 660, align: 'center', lineBreak: false });
        d.restore();
        d.fillOpacity(1);
        // Also state it in plain text at the top so it survives copy/paste and screen readers.
        d.font('Helvetica-Bold').fontSize(8).fillColor('#DC2626').text(pdfSafe(this.watermarkText), this.left, 82, { width: this.width, align: 'center', lineBreak: false });
      }
      // Writing inside the bottom margin would otherwise make pdfkit start a new page.
      d.page.margins.bottom = 0;
      const bottom = d.page.height - 50;
      d.save().moveTo(this.left, bottom - 8).lineTo(this.right, bottom - 8).lineWidth(0.5).strokeColor(RULE).stroke().restore();
      d.font('Helvetica').fontSize(7.5).fillColor(MUTED);
      let y = bottom - 2;
      for (const l of footerLines) {
        d.text(pdfSafe(l), this.left, y, { width: this.width - 60, lineBreak: false, height: 10 });
        y += 10;
      }
      d.text(`Page ${i - range.start + 1} of ${range.count}`, this.right - 60, bottom - 2, { width: 60, align: 'right', lineBreak: false, height: 10 });
    }
    d.end();
    return this.done;
  }
}

/** "26 Sep 2026" style date in IST. */
export function pdfDate(d: Date): string {
  return d.toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata', day: '2-digit', month: 'short', year: 'numeric' });
}
