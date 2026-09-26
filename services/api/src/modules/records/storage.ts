import { createReadStream } from 'node:fs';
import { mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { Readable } from 'node:stream';

export interface StorageAdapter {
  readonly name: string;
  /** Objects are write-once: putting an existing key fails (originals are immutable). */
  put(key: string, data: Buffer, contentType: string): Promise<void>;
  get(key: string): Promise<Buffer>;
  /** Stream an object (used by /records/:id/file so large files are not buffered). */
  getStream(key: string): Promise<Readable>;
  exists(key: string): Promise<boolean>;
  head(key: string): Promise<{ size: number; contentType: string | null } | null>;
  /** Only used for derived artefacts (e.g. expired data exports). Original records are never deleted. */
  delete(key: string): Promise<void>;
  /** Readiness probe. */
  ping(): Promise<void>;
}

export class LocalDiskStorage implements StorageAdapter {
  readonly name = 'local';
  constructor(private readonly baseDir: string) {}
  private resolve(key: string): string {
    const full = path.resolve(this.baseDir, key);
    if (!full.startsWith(path.resolve(this.baseDir))) throw new Error('invalid storage key');
    return full;
  }
  async put(key: string, data: Buffer): Promise<void> {
    const file = this.resolve(key);
    await mkdir(path.dirname(file), { recursive: true });
    await writeFile(file, data, { flag: 'wx' });
  }
  async get(key: string): Promise<Buffer> {
    return readFile(this.resolve(key));
  }
  async getStream(key: string): Promise<Readable> {
    const file = this.resolve(key);
    await stat(file); // throw ENOENT before streaming starts
    return createReadStream(file);
  }
  async exists(key: string): Promise<boolean> {
    return (await this.head(key)) !== null;
  }
  async head(key: string): Promise<{ size: number; contentType: string | null } | null> {
    try {
      const st = await stat(this.resolve(key));
      return { size: st.size, contentType: null };
    } catch {
      return null;
    }
  }
  async delete(key: string): Promise<void> {
    await rm(this.resolve(key), { force: true });
  }
  async ping(): Promise<void> {
    await mkdir(this.baseDir, { recursive: true });
    await stat(this.baseDir);
  }
}

export class MemoryStorage implements StorageAdapter {
  readonly name = 'memory';
  private readonly objects = new Map<string, { data: Buffer; contentType: string }>();
  async put(key: string, data: Buffer, contentType = 'application/octet-stream'): Promise<void> {
    if (this.objects.has(key)) throw new Error('object exists');
    this.objects.set(key, { data: Buffer.from(data), contentType });
  }
  async get(key: string): Promise<Buffer> {
    const b = this.objects.get(key);
    if (!b) throw new Error('not found');
    return Buffer.from(b.data);
  }
  async getStream(key: string): Promise<Readable> {
    return Readable.from([await this.get(key)]);
  }
  async exists(key: string): Promise<boolean> {
    return this.objects.has(key);
  }
  async head(key: string): Promise<{ size: number; contentType: string | null } | null> {
    const b = this.objects.get(key);
    return b ? { size: b.data.length, contentType: b.contentType } : null;
  }
  async delete(key: string): Promise<void> {
    this.objects.delete(key);
  }
  async ping(): Promise<void> {}
}

/** Malware scanning hook (ClamAV clamd in production, see scanner.ts). */
export interface MalwareScanner {
  readonly name: string;
  scan(data: Buffer, fileName: string): Promise<{ clean: boolean; engine: string; signature?: string | null }>;
  ping?(): Promise<void>;
}
export class NoopScanner implements MalwareScanner {
  readonly name = 'noop';
  async scan(): Promise<{ clean: boolean; engine: string }> {
    return { clean: true, engine: 'noop-dev' };
  }
}

export const ALLOWED_RECORD_MIME = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic'] as const;

/** Detect file type from magic bytes (never trust the client-declared type). */
export function sniffMime(buf: Buffer): string | null {
  if (buf.length < 12) return null;
  if (buf.subarray(0, 4).toString('latin1') === '%PDF') return 'application/pdf';
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (buf.subarray(0, 4).toString('latin1') === 'RIFF' && buf.subarray(8, 12).toString('latin1') === 'WEBP') return 'image/webp';
  if (buf.subarray(4, 8).toString('latin1') === 'ftyp') {
    const brand = buf.subarray(8, 12).toString('latin1');
    if (['heic', 'heix', 'hevc', 'mif1', 'msf1', 'heim', 'heis'].includes(brand)) return 'image/heic';
  }
  return null;
}

/** Best-effort pixel dimensions for PNG / JPEG / WebP(VP8X/VP8). */
export function imageDimensions(buf: Buffer, mime: string): { width: number; height: number } | null {
  try {
    if (mime === 'image/png') return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
    if (mime === 'image/jpeg') {
      let off = 2;
      while (off < buf.length) {
        if (buf[off] !== 0xff) return null;
        const marker = buf[off + 1];
        const len = buf.readUInt16BE(off + 2);
        if ((marker >= 0xc0 && marker <= 0xc3) || (marker >= 0xc5 && marker <= 0xc7) || (marker >= 0xc9 && marker <= 0xcb)) {
          return { height: buf.readUInt16BE(off + 5), width: buf.readUInt16BE(off + 7) };
        }
        off += 2 + len;
      }
      return null;
    }
    if (mime === 'image/webp') {
      const chunk = buf.subarray(12, 16).toString('latin1');
      if (chunk === 'VP8X') return { width: 1 + buf.readUIntLE(24, 3), height: 1 + buf.readUIntLE(27, 3) };
      if (chunk === 'VP8 ') return { width: buf.readUInt16LE(26) & 0x3fff, height: buf.readUInt16LE(28) & 0x3fff };
    }
  } catch {
    return null;
  }
  return null;
}
