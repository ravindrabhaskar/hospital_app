import { eq } from 'drizzle-orm';
import type { Db } from '../../db/client.js';
import { featureFlags } from '../../db/schema.js';
import { errors } from '../../lib/errors.js';

export const DEFAULT_FLAGS: Array<{ key: string; enabled: boolean; description: string }> = [
  { key: 'ai_assistant', enabled: true, description: 'AI Care Assistant (intake + routing)' },
  { key: 'wound_ai_analysis', enabled: false, description: 'Clinical wound image analysis (disabled until a validated model is approved)' },
  { key: 'fall_detection', enabled: true, description: 'Fall detection events and auto-escalation' },
  { key: 'wearables', enabled: true, description: 'Wearable connections and sync' },
  { key: 'pharmacy_orders', enabled: true, description: 'Pharmacy partner ordering' },
  { key: 'mental_wellness', enabled: true, description: 'Mood tracking and wellness activities' },
  { key: 'govt_schemes', enabled: true, description: 'Government health scheme information (information only; never decides eligibility)' },
  { key: 'voice_input', enabled: true, description: 'Voice input for the AI assistant' },
  { key: 'kill_switch_ai', enabled: false, description: 'Emergency kill switch: when on, all AI calls return the safe fallback immediately' },
];

export class FlagService {
  constructor(private readonly db: Db) {}

  async isEnabled(key: string): Promise<boolean> {
    const [row] = await this.db.select().from(featureFlags).where(eq(featureFlags.key, key)).limit(1);
    if (row) return row.enabled;
    return DEFAULT_FLAGS.find((f) => f.key === key)?.enabled ?? false;
  }

  async require(key: string): Promise<void> {
    if (!(await this.isEnabled(key))) throw errors.featureDisabled(key);
  }

  async ensureDefaults(): Promise<void> {
    for (const f of DEFAULT_FLAGS) {
      await this.db.insert(featureFlags).values(f).onConflictDoNothing();
    }
  }
}
