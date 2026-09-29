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
  // v1.3 (contract sections 41-62); all on by default, toggleable by super_admin.
  { key: 'lab_tests', enabled: true, description: 'Lab tests at home (section 44)' },
  { key: 'care_programs', enabled: true, description: 'Chronic care programs / remote monitoring (section 42)' },
  { key: 'second_opinion', enabled: true, description: 'Specialist second opinion (section 49)' },
  { key: 'insurance', enabled: true, description: 'Insurance helper (section 51)' },
  { key: 'preventive_care', enabled: true, description: 'Vaccination & preventive screening (section 52)' },
  { key: 'exercise_plans', enabled: true, description: 'Physiotherapy & exercise programs (section 53)' },
  { key: 'diet_plans', enabled: true, description: 'Diet plans (section 54)' },
  { key: 'ambulance', enabled: true, description: 'Ambulance booking; never replaces 108 (section 55)' },
  { key: 'safe_zone', enabled: true, description: 'Dementia safe zone & SOS button (section 56)' },
  { key: 'wallet_invites', enabled: true, description: 'Offers, wallet & invites (section 60)' },
  { key: 'support_desk', enabled: true, description: 'Support desk (section 61)' },
  { key: 'whatsapp', enabled: true, description: 'WhatsApp assistant (section 43)' },
  { key: 'daily_checkin', enabled: true, description: 'Daily "I\'m OK" check-in (section 41)' },
  { key: 'abdm', enabled: true, description: 'ABDM ABHA creation, linking and consent (section 50)' },
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
