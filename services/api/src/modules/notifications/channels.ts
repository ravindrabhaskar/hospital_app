import { maskPhone } from '../../lib/crypto.js';
import type { SmsProvider } from '../auth/sms.js';

export type Channel = 'push' | 'sms' | 'email' | 'whatsapp';

export interface OutboundMessage {
  channel: Channel;
  /** device token / phone / email; may be null for push fan-out by userId. */
  recipient: string | null;
  userId: string | null;
  /** Generic, PHI-free lock-screen text only. */
  text: string;
  critical: boolean;
  /** Generic push title (never health details). */
  title?: string | null;
  /** In-app route, e.g. "/appointments/<id>" (ids only, no health details). */
  deepLink?: string | null;
  notificationId?: string | null;
}

export interface ChannelAdapter {
  readonly channel: Channel;
  send(msg: OutboundMessage): Promise<void>;
}

/** A delivery that must not be retried (e.g. unregistered device token). */
export class PermanentDeliveryError extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = 'PermanentDeliveryError';
  }
}

/** Dev implementation: prints a PHI-free line. */
export class ConsoleChannel implements ChannelAdapter {
  constructor(
    readonly channel: Channel,
    private readonly silent = false,
  ) {}
  async send(msg: OutboundMessage): Promise<void> {
    if (this.silent) return;
    const to = msg.recipient ? (msg.recipient.startsWith('+') ? maskPhone(msg.recipient) : `${msg.recipient.slice(0, 6)}…`) : `user:${msg.userId}`;
    console.log(`[notify:${msg.channel}${msg.critical ? ':critical' : ''}] -> ${to}: ${msg.text}`);
  }
}

/** Outbox SMS through the configured SMS provider (MSG91 needs a DLT notification template). */
export class SmsChannel implements ChannelAdapter {
  readonly channel = 'sms' as const;
  constructor(private readonly sms: SmsProvider) {}
  async send(msg: OutboundMessage): Promise<void> {
    if (!msg.recipient) throw new PermanentDeliveryError('no_phone');
    await this.sms.sendText(msg.recipient, msg.text);
  }
}

export function consoleChannels(silent: boolean): Record<Channel, ChannelAdapter> {
  return {
    push: new ConsoleChannel('push', silent),
    sms: new ConsoleChannel('sms', silent),
    email: new ConsoleChannel('email', silent),
    whatsapp: new ConsoleChannel('whatsapp', silent),
  };
}
