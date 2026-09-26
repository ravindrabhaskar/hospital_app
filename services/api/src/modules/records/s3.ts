import { Readable } from 'node:stream';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
  type S3ClientConfig,
} from '@aws-sdk/client-s3';
import type { Config } from '../../config.js';
import { errors } from '../../lib/errors.js';
import type { StorageAdapter } from './storage.js';

const isNotFound = (err: unknown): boolean => {
  const e = err as { name?: string; $metadata?: { httpStatusCode?: number } };
  return e?.name === 'NotFound' || e?.name === 'NoSuchKey' || e?.$metadata?.httpStatusCode === 404;
};

/**
 * S3-compatible storage (AWS S3 ap-south-1 or MinIO via S3_ENDPOINT).
 * - Writes are write-once (`If-None-Match: *`), so an original can never be overwritten.
 * - SSE-KMS with S3_KMS_KEY_ID when set (otherwise the bucket default encryption applies).
 * - Credentials come from S3_ACCESS_KEY_ID/S3_SECRET_ACCESS_KEY or the default AWS provider chain
 *   (instance/task role in production).
 */
export class S3Storage implements StorageAdapter {
  readonly name = 's3';
  constructor(
    readonly bucket: string,
    private readonly client: S3Client,
    private readonly kmsKeyId?: string,
    private readonly prefix = '',
  ) {}

  static fromConfig(config: Config): S3Storage {
    if (!config.S3_BUCKET) throw new Error('STORAGE_DRIVER=s3 requires S3_BUCKET');
    const clientConfig: S3ClientConfig = {
      region: config.S3_REGION,
      ...(config.S3_ENDPOINT ? { endpoint: config.S3_ENDPOINT } : {}),
      // MinIO and most S3-compatible endpoints need path-style addressing.
      forcePathStyle: !!config.S3_ENDPOINT || config.S3_FORCE_PATH_STYLE,
      ...(config.S3_ACCESS_KEY_ID && config.S3_SECRET_ACCESS_KEY
        ? { credentials: { accessKeyId: config.S3_ACCESS_KEY_ID, secretAccessKey: config.S3_SECRET_ACCESS_KEY } }
        : {}),
    };
    return new S3Storage(config.S3_BUCKET, new S3Client(clientConfig), config.S3_KMS_KEY_ID);
  }

  private k(key: string): string {
    if (key.includes('..') || key.startsWith('/')) throw new Error('invalid storage key');
    return this.prefix + key;
  }

  async put(key: string, data: Buffer, contentType: string): Promise<void> {
    const Key = this.k(key);
    try {
      await this.client.send(
        new PutObjectCommand({
          Bucket: this.bucket,
          Key,
          Body: data,
          ContentType: contentType,
          ContentLength: data.length,
          IfNoneMatch: '*',
          ...(this.kmsKeyId ? { ServerSideEncryption: 'aws:kms', SSEKMSKeyId: this.kmsKeyId } : {}),
        }),
      );
    } catch (err) {
      const e = err as { name?: string; $metadata?: { httpStatusCode?: number } };
      if (e?.$metadata?.httpStatusCode === 412 || e?.name === 'PreconditionFailed') throw new Error('object exists', { cause: err });
      throw errors.dependency('File storage is temporarily unavailable');
    }
  }

  async getStream(key: string): Promise<Readable> {
    let res;
    try {
      res = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: this.k(key) }));
    } catch (err) {
      if (isNotFound(err)) throw errors.notFound('File');
      throw errors.dependency('File storage is temporarily unavailable');
    }
    const body = res.Body;
    if (!body) throw errors.notFound('File');
    if (body instanceof Readable) return body;
    // Browser-like runtimes / mocks: SdkStreamMixin with transformToByteArray.
    const withBytes = body as { transformToByteArray?: () => Promise<Uint8Array> };
    if (typeof withBytes.transformToByteArray === 'function') return Readable.from([Buffer.from(await withBytes.transformToByteArray())]);
    return Readable.from(body as AsyncIterable<Uint8Array>);
  }

  async get(key: string): Promise<Buffer> {
    const stream = await this.getStream(key);
    const chunks: Buffer[] = [];
    for await (const c of stream) chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(c));
    return Buffer.concat(chunks);
  }

  async head(key: string): Promise<{ size: number; contentType: string | null } | null> {
    try {
      const r = await this.client.send(new HeadObjectCommand({ Bucket: this.bucket, Key: this.k(key) }));
      return { size: Number(r.ContentLength ?? 0), contentType: r.ContentType ?? null };
    } catch (err) {
      if (isNotFound(err)) return null;
      throw errors.dependency('File storage is temporarily unavailable');
    }
  }

  async exists(key: string): Promise<boolean> {
    return (await this.head(key)) !== null;
  }

  async delete(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: this.k(key) }));
  }

  async ping(): Promise<void> {
    await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
  }
}
