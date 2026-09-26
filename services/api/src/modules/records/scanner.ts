import net from 'node:net';
import { audit } from '../../lib/audit.js';
import type { Actor } from '../../lib/context.js';
import { AppError, errors } from '../../lib/errors.js';
import type { Services } from '../../services.js';
import type { MalwareScanner } from './storage.js';

/** Scan an upload; infected files are rejected with 422 FILE_REJECTED (contract section 27) and audited. */
export async function assertFileClean(svc: Services, actor: Actor, data: Buffer, fileName: string, action: string): Promise<void> {
  const res = await svc.scanner.scan(data, fileName);
  if (res.clean) return;
  svc.metrics.filesRejected.inc();
  await audit(svc.db, actor, {
    action,
    entityType: 'upload',
    outcome: 'denied',
    metadata: { reason: 'malware', engine: res.engine, signature: res.signature ?? null },
  });
  throw new AppError('FILE_REJECTED', 'This file was rejected by the security scan and was not saved.', { engine: res.engine });
}

const CHUNK = 64 * 1024;

/**
 * ClamAV `clamd` scanner using the INSTREAM protocol over TCP:
 *   "zINSTREAM\0" + [uint32 BE length + bytes]* + [0x00000000]  ->  "stream: OK\0" | "stream: <Signature> FOUND\0"
 * Fails CLOSED: any transport error or unexpected reply raises DEPENDENCY_UNAVAILABLE, so an unscanned
 * file is never stored.
 */
export class ClamdScanner implements MalwareScanner {
  readonly name = 'clamav';
  constructor(
    private readonly host: string,
    private readonly port = 3310,
    private readonly timeoutMs = 15_000,
  ) {}

  private exchange(write: (socket: net.Socket) => void): Promise<string> {
    return new Promise((resolve, reject) => {
      const socket = net.createConnection({ host: this.host, port: this.port });
      const chunks: Buffer[] = [];
      let settled = false;
      const done = (err: Error | null, value?: string) => {
        if (settled) return;
        settled = true;
        socket.destroy();
        if (err) reject(err);
        else resolve(value ?? '');
      };
      socket.setTimeout(this.timeoutMs, () => done(new Error('clamd timeout')));
      socket.on('error', (err) => done(err));
      socket.on('connect', () => write(socket));
      socket.on('data', (d: Buffer) => {
        chunks.push(d);
        const all = Buffer.concat(chunks);
        const nul = all.indexOf(0);
        if (nul >= 0) done(null, all.subarray(0, nul).toString('utf8').trim());
      });
      socket.on('end', () => done(null, Buffer.concat(chunks).toString('utf8').replace(/\0/g, '').trim()));
    });
  }

  async scan(data: Buffer): Promise<{ clean: boolean; engine: string; signature: string | null }> {
    let reply: string;
    try {
      reply = await this.exchange((socket) => {
        socket.write('zINSTREAM\0');
        for (let off = 0; off < data.length; off += CHUNK) {
          const part = data.subarray(off, Math.min(off + CHUNK, data.length));
          const len = Buffer.alloc(4);
          len.writeUInt32BE(part.length, 0);
          socket.write(len);
          socket.write(part);
        }
        socket.write(Buffer.alloc(4)); // zero-length chunk terminates the stream
      });
    } catch {
      throw errors.dependency('Malware scanning is temporarily unavailable. Please try again.');
    }
    if (/:\s*OK$/.test(reply)) return { clean: true, engine: 'clamav', signature: null };
    const found = /:\s*(.+)\s+FOUND$/.exec(reply);
    if (found) return { clean: false, engine: 'clamav', signature: found[1] };
    // "INSTREAM size limit exceeded. ERROR" and anything else: fail closed.
    throw errors.dependency('Malware scanning failed. Please try again.', { reply: reply.slice(0, 80) });
  }

  async ping(): Promise<void> {
    const reply = await this.exchange((socket) => socket.write('zPING\0'));
    if (reply !== 'PONG') throw new Error('clamd did not answer PONG');
  }
}
