import type { FastifyRequest } from 'fastify';
import { errors } from './errors.js';

export interface UploadedFile {
  data: Buffer;
  fileName: string;
}

/**
 * Read a multipart/form-data request with exactly one file field (`fileField`) plus text fields.
 * Extra files are drained and ignored. The global multipart limits (MAX_UPLOAD_MB) still apply.
 */
export async function readMultipart(req: FastifyRequest, fileField: string): Promise<{ fields: Record<string, string>; file: UploadedFile | null }> {
  if (!req.isMultipart()) throw errors.validation('multipart/form-data is required');
  const fields: Record<string, string> = {};
  let file: UploadedFile | null = null;
  for await (const part of req.parts()) {
    if (part.type === 'file') {
      if (part.fieldname !== fileField || file) {
        await part.toBuffer();
        continue;
      }
      file = { data: await part.toBuffer(), fileName: part.filename || 'upload' };
    } else if (typeof part.value === 'string') {
      fields[part.fieldname] = part.value;
    }
  }
  return { fields, file };
}

export function assertMaxSize(file: UploadedFile, maxMb: number): void {
  if (file.data.length > maxMb * 1024 * 1024) throw errors.validation(`File too large (max ${maxMb}MB)`);
}

export const extForMime = (mime: string): string =>
  ({ 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp', 'application/pdf': '.pdf', 'image/heic': '.heic' })[mime] ?? '';
