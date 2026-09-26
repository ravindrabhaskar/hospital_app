import { SignJWT } from 'jose';
import type { Config } from '../../config.js';
import { hmacHex } from '../../lib/crypto.js';

export interface VideoParticipant {
  userId: string;
  name: string | null;
  moderator: boolean;
}

export interface VideoSession {
  provider: 'jitsi' | 'placeholder';
  joinUrl: string;
  roomName: string;
  token: string | null;
}

/** Video consultation adapter (contract section 26). */
export interface VideoProvider {
  readonly name: 'jitsi' | 'placeholder';
  /** Stable, unguessable room name for an appointment. */
  roomName(appointmentId: string): string;
  /** Room URL without credentials (stored on Appointment.videoRoomUrl). */
  roomUrl(appointmentId: string, mode: string): string;
  /** Per-participant join details (JWT when configured). */
  session(p: { appointmentId: string; mode: string; participant: VideoParticipant; expiresAt: Date; notBefore: Date }): Promise<VideoSession>;
}

/** Audio mode uses the same room with the camera off. */
const audioFragment = (mode: string) => (mode === 'audio' ? '#config.startWithVideoMuted=true&config.startAudioOnly=true' : '');

/**
 * Jitsi Meet. Room names are HMAC-SHA256(appointment id) with VIDEO_ROOM_SECRET, so they cannot be
 * guessed or enumerated. With JITSI_APP_ID / JITSI_APP_SECRET (self-hosted Prosody token auth) an
 * HS256 JWT scoped to the room and the consultation window is issued; `meet.jit.si` needs no JWT.
 */
export class JitsiVideoProvider implements VideoProvider {
  readonly name = 'jitsi' as const;
  constructor(
    private readonly opts: { domain: string; roomSecret: string; appId?: string; appSecret?: string },
  ) {}

  roomName(appointmentId: string): string {
    return `CareCompanion-${hmacHex(this.opts.roomSecret, `room:${appointmentId}`).slice(0, 32)}`;
  }

  roomUrl(appointmentId: string, mode: string): string {
    return `https://${this.opts.domain}/${this.roomName(appointmentId)}${audioFragment(mode)}`;
  }

  async session(p: { appointmentId: string; mode: string; participant: VideoParticipant; expiresAt: Date; notBefore: Date }): Promise<VideoSession> {
    const roomName = this.roomName(p.appointmentId);
    let token: string | null = null;
    if (this.opts.appId && this.opts.appSecret) {
      token = await new SignJWT({
        room: roomName,
        context: { user: { id: p.participant.userId, name: p.participant.name ?? 'Participant', moderator: p.participant.moderator } },
        moderator: p.participant.moderator,
      })
        .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
        .setIssuer(this.opts.appId)
        .setAudience('jitsi')
        .setSubject(this.opts.domain)
        .setNotBefore(Math.floor(p.notBefore.getTime() / 1000))
        .setExpirationTime(Math.floor(p.expiresAt.getTime() / 1000))
        .setIssuedAt()
        .sign(new TextEncoder().encode(this.opts.appSecret));
    }
    const base = `https://${this.opts.domain}/${roomName}`;
    return {
      provider: 'jitsi',
      roomName,
      token,
      joinUrl: `${base}${token ? `?jwt=${token}` : ''}${audioFragment(p.mode)}`,
    };
  }
}

/** Dev placeholder: VIDEO_BASE_URL/<room>. */
export class PlaceholderVideoProvider implements VideoProvider {
  readonly name = 'placeholder' as const;
  constructor(
    private readonly baseUrl: string,
    private readonly roomSecret: string,
  ) {}
  roomName(appointmentId: string): string {
    return `cc-${hmacHex(this.roomSecret, `room:${appointmentId}`).slice(0, 32)}`;
  }
  roomUrl(appointmentId: string, mode: string): string {
    return `${this.baseUrl.replace(/\/$/, '')}/${this.roomName(appointmentId)}${audioFragment(mode)}`;
  }
  async session(p: { appointmentId: string; mode: string }): Promise<VideoSession> {
    return { provider: 'placeholder', roomName: this.roomName(p.appointmentId), token: null, joinUrl: this.roomUrl(p.appointmentId, p.mode) };
  }
}

export function createVideoProvider(config: Config): VideoProvider {
  // Dev fallback: derive the room secret from JWT_SECRET (production requires VIDEO_ROOM_SECRET).
  const roomSecret = config.VIDEO_ROOM_SECRET ?? `room:${config.JWT_SECRET}`;
  if (config.VIDEO_PROVIDER === 'placeholder') return new PlaceholderVideoProvider(config.VIDEO_BASE_URL, roomSecret);
  return new JitsiVideoProvider({ domain: config.JITSI_DOMAIN, roomSecret, appId: config.JITSI_APP_ID, appSecret: config.JITSI_APP_SECRET });
}

/** Contract section 26 time window: 10 min before start until 60 min after end. */
export const VIDEO_OPENS_BEFORE_MS = 10 * 60_000;
export const VIDEO_CLOSES_AFTER_MS = 60 * 60_000;
