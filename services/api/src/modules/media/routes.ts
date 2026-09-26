import { randomUUID } from 'node:crypto';
import { and, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import type { Config } from '../../config.js';
import { media, patients, providers } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { sha256 } from '../../lib/crypto.js';
import { errors } from '../../lib/errors.js';
import { assertMaxSize, extForMime, readMultipart } from '../../lib/multipart.js';
import { assertFileClean } from '../records/scanner.js';
import { sniffMime } from '../records/storage.js';

/**
 * Profile photos live under their own storage prefix. GET /media/:id serves ONLY rows flagged as public profile
 * photos whose key is under this prefix; medical records have no media row and a different prefix (`records/`).
 */
export const PROFILE_PHOTO_PREFIX = 'media/profile-photos/';
const PHOTO_MIME = ['image/jpeg', 'image/png', 'image/webp'];
const PHOTO_MAX_MB = 5;

export const mediaUrl = (config: Config, id: string): string => `${config.PUBLIC_API_BASE_URL.replace(/\/$/, '')}/media/${id}`;

/** POST /me/photo (authenticated). */
export async function mePhotoRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.post('/me/photo', async (req) => {
    const { file } = await readMultipart(req, 'image');
    if (!file) throw errors.validation('image is required');
    assertMaxSize(file, PHOTO_MAX_MB);
    const mime = sniffMime(file.data);
    if (!mime || !PHOTO_MIME.includes(mime)) throw errors.validation('Unsupported image type. Allowed: jpg, png, webp');
    await assertFileClean(svc, req.ctx.actor, file.data, file.fileName, 'media.upload');
    const id = randomUUID();
    const storageKey = `${PROFILE_PHOTO_PREFIX}${req.ctx.user.id}/${id}${extForMime(mime)}`;
    await svc.storage.put(storageKey, file.data, mime);
    const photoUrl = mediaUrl(svc.config, id);
    await db.transaction(async (tx) => {
      await tx.insert(media).values({
        id,
        ownerUserId: req.ctx.user.id,
        kind: 'profile_photo',
        publicProfilePhoto: true,
        storageKey,
        mimeType: mime,
        sizeBytes: file.data.length,
        sha256: sha256(file.data),
      });
      await tx.update(providers).set({ photoUrl }).where(eq(providers.userId, req.ctx.user.id));
      await tx.update(patients).set({ avatarUrl: photoUrl, updatedAt: new Date() }).where(eq(patients.userId, req.ctx.user.id));
      await audit(tx, req.ctx.actor, { action: 'media.profile_photo', entityType: 'media', entityId: id, metadata: { mime, size: file.data.length } });
    });
    return { photoUrl };
  });
}

/** GET /media/:id (public, no auth): profile photos only. */
export async function publicMediaRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  app.get('/media/:id', async (req, reply) => {
    const { id } = req.params as { id: string };
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) throw errors.notFound('Media');
    const [m] = await svc.db
      .select()
      .from(media)
      .where(and(eq(media.id, id), eq(media.kind, 'profile_photo'), eq(media.publicProfilePhoto, true)));
    if (!m || !m.storageKey.startsWith(PROFILE_PHOTO_PREFIX) || !PHOTO_MIME.includes(m.mimeType)) throw errors.notFound('Media');
    const data = await svc.storage.get(m.storageKey);
    return reply
      .header('content-type', m.mimeType)
      .header('cache-control', 'public, max-age=86400')
      .header('x-content-type-options', 'nosniff')
      .send(data);
  });
}
