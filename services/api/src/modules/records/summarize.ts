import { VISION_MEDIA_TYPES, type ModelRequest, type VisionMediaType } from '../ai/models.js';
import type { RecordRow } from './service.js';

/** Max characters of extracted text sent to the model. */
export const MAX_SUMMARY_INPUT_CHARS = 12_000;
/** Claude image input limit is 5 MB per image (base64 source); larger images get a metadata-only summary. */
export const MAX_VISION_BYTES = 5 * 1024 * 1024;

/** Text layer of a PDF (no OCR). Returns '' when the PDF has no extractable text or cannot be parsed. */
export async function extractPdfText(data: Buffer): Promise<string> {
  try {
    const { extractText, getDocumentProxy } = await import('unpdf');
    // Copy: pdf.js may transfer/detach the buffer it is given; the stored original stays untouched.
    const pdf = await getDocumentProxy(new Uint8Array(data));
    const { text } = await extractText(pdf, { mergePages: true });
    return text.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
  } catch {
    return '';
  }
}

export type SummaryInput = { kind: 'text'; text: string } | { kind: 'image'; mediaType: VisionMediaType; base64: string } | { kind: 'metadata' };

/** Decide what the model may read for a record. The original bytes are only read, never modified. */
export async function summaryInput(r: RecordRow, data: Buffer | null, visionAvailable: boolean): Promise<SummaryInput> {
  if (!data) return { kind: 'metadata' };
  if (r.mimeType === 'text/plain') return { kind: 'text', text: data.toString('utf8').slice(0, MAX_SUMMARY_INPUT_CHARS) };
  if (r.mimeType === 'application/pdf') {
    const text = await extractPdfText(data);
    return text ? { kind: 'text', text: text.slice(0, MAX_SUMMARY_INPUT_CHARS) } : { kind: 'metadata' };
  }
  if (visionAvailable && VISION_MEDIA_TYPES.includes(r.mimeType) && data.length <= MAX_VISION_BYTES) {
    return { kind: 'image', mediaType: r.mimeType as VisionMediaType, base64: data.toString('base64') };
  }
  return { kind: 'metadata' };
}

export const SUMMARY_SYSTEM_PROMPT =
  'You summarise a patient health document in plain, simple language for the patient. Never state or suggest a diagnosis, ' +
  'never recommend or change medication, never contradict the document. Mention only facts present in the input. ' +
  'If the document is unreadable, say so. Keep it under 120 words.';

export function buildSummaryRequest(r: RecordRow, input: SummaryInput, fallbackText: string): ModelRequest {
  const typeLabel = r.type.replace('_', ' ');
  const header = `Document type: ${typeLabel}\nTitle: ${r.title}\nDate: ${r.recordDate}\n`;
  let body: string;
  if (input.kind === 'text') body = `Contents (extracted text):\n${input.text}`;
  else if (input.kind === 'image') body = 'Contents: the attached image of the document.';
  else body = 'Contents: not available (binary file).';
  return {
    system: SUMMARY_SYSTEM_PROMPT,
    messages: [{ role: 'user', content: header + body }],
    maxTokens: 1024,
    fallbackText,
    ...(input.kind === 'image' ? { images: [{ mediaType: input.mediaType, data: input.base64 }] } : {}),
  };
}
