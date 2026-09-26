import path from 'node:path';
import type { Config } from '../../config.js';
import { S3Storage } from './s3.js';
import { LocalDiskStorage, MemoryStorage, type StorageAdapter } from './storage.js';

/** The configured storage driver (used by the API, the seed and CLI scripts). */
export function createStorage(config: Config): StorageAdapter {
  if (config.STORAGE_DRIVER === 'memory') return new MemoryStorage();
  if (config.STORAGE_DRIVER === 's3') return S3Storage.fromConfig(config);
  return new LocalDiskStorage(path.resolve(config.STORAGE_DIR));
}
