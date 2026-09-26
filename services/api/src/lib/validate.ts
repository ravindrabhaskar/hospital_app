import { z } from 'zod';
import { errors } from './errors.js';

export function parse<T extends z.ZodType>(schema: T, input: unknown): z.infer<T> {
  const r = schema.safeParse(input ?? {});
  if (!r.success) {
    throw errors.validation('Request validation failed', {
      issues: r.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
    });
  }
  return r.data;
}

export const zUuid = z.string().uuid();
export const zDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected YYYY-MM-DD');
export const zIso = z.string().datetime({ offset: true });
export const zPhone = z.string().regex(/^\+\d{10,15}$/, 'Expected E.164 phone like +919800000001');
export const VITAL_TYPES = [
  'bp_systolic',
  'bp_diastolic',
  'pulse',
  'spo2',
  'temperature',
  'blood_glucose',
  'weight',
  'respiratory_rate',
] as const;
export const zVitalType = z.enum(VITAL_TYPES);
export const zFamilyPermission = z.enum(['view_records', 'manage_care', 'book', 'receive_alerts']);
export const zAddress = z.object({
  line1: z.string().min(1).max(200),
  line2: z.string().max(200).optional(),
  landmark: z.string().max(200).optional(),
  city: z.string().min(1).max(100),
  pincode: z.string().regex(/^\d{6}$/, 'Expected 6-digit pincode'),
  lat: z.number().min(-90).max(90).optional(),
  lng: z.number().min(-180).max(180).optional(),
});
export const zBoolQuery = z
  .union([z.boolean(), z.enum(['true', 'false', '1', '0'])])
  .transform((v) => v === true || v === 'true' || v === '1');
