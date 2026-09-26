import { z } from "zod";

/**
 * Validation for the `NEXT_PUBLIC_*` variables. They are inlined into the client bundle at
 * **build time**, so `next.config.ts` calls `assertValidPublicEnv()` and a misconfigured build fails
 * early. At runtime the parsed values (with defaults) are exported as `publicEnv`.
 *
 * Every variable must be read with a literal `process.env.NEXT_PUBLIC_…` expression, otherwise
 * Next.js cannot inline it.
 */
export interface RawPublicEnv {
  NEXT_PUBLIC_API_BASE_URL?: string;
  NEXT_PUBLIC_LEGAL_DRAFT?: string;
  NEXT_PUBLIC_JITSI_DOMAIN?: string;
  NEXT_PUBLIC_SUPPORT_EMAIL?: string;
  NEXT_PUBLIC_SUPPORT_PHONE?: string;
  NEXT_PUBLIC_LEGAL_ENTITY_NAME?: string;
  NEXT_PUBLIC_GRIEVANCE_OFFICER_NAME?: string;
  NEXT_PUBLIC_GRIEVANCE_OFFICER_EMAIL?: string;
}

export interface PublicEnv {
  /** e.g. https://api.example.in/api/v1 (no trailing slash) */
  apiBaseUrl: string;
  /** Origin of the API, used by the Content-Security-Policy. */
  apiOrigin: string;
  /** Show the "Draft, pending legal review" banner on legal pages. Default true. */
  legalDraft: boolean;
  /** Host name of the Jitsi deployment allowed in the optional embedded video frame. */
  jitsiDomain: string;
  /** Fallbacks used until /config/public answers. */
  supportEmail: string | null;
  supportPhone: string | null;
  legalEntityName: string;
  grievanceOfficerName: string;
  grievanceOfficerEmail: string;
}

const DEFAULT_API = "http://localhost:4000/api/v1";
const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]", "0.0.0.0", "10.0.2.2"]);

const blankToUndefined = (v: unknown) => (typeof v === "string" && v.trim() === "" ? undefined : v);
const bool = (dflt: boolean) =>
  z.preprocess(
    blankToUndefined,
    z
      .enum(["true", "false", "1", "0", "yes", "no"], { message: "must be true or false" })
      .optional()
      .transform((v) => (v === undefined ? dflt : v === "true" || v === "1" || v === "yes")),
  );
const optStr = z.preprocess(blankToUndefined, z.string().trim().optional());

const schema = z.object({
  NEXT_PUBLIC_API_BASE_URL: z.preprocess(blankToUndefined, z.string().url("must be an absolute URL").default(DEFAULT_API)),
  NEXT_PUBLIC_LEGAL_DRAFT: bool(true),
  NEXT_PUBLIC_JITSI_DOMAIN: z.preprocess(
    blankToUndefined,
    z
      .string()
      .regex(/^[a-z0-9.-]+(:\d+)?$/i, "must be a bare host name such as meet.jit.si")
      .default("meet.jit.si"),
  ),
  NEXT_PUBLIC_SUPPORT_EMAIL: z.preprocess(blankToUndefined, z.string().email("must be an email address").optional()),
  NEXT_PUBLIC_SUPPORT_PHONE: optStr,
  NEXT_PUBLIC_LEGAL_ENTITY_NAME: optStr,
  NEXT_PUBLIC_GRIEVANCE_OFFICER_NAME: optStr,
  NEXT_PUBLIC_GRIEVANCE_OFFICER_EMAIL: z.preprocess(blankToUndefined, z.string().email("must be an email address").optional()),
});

export function parsePublicEnv(raw: RawPublicEnv, opts: { production: boolean }): { env: PublicEnv; errors: string[] } {
  const errors: string[] = [];
  const parsed = schema.safeParse(raw);
  const v = parsed.success ? parsed.data : schema.parse({});
  if (!parsed.success) {
    for (const issue of parsed.error.issues) errors.push(`${issue.path.join(".")}: ${issue.message}`);
  }
  const apiBaseUrl = v.NEXT_PUBLIC_API_BASE_URL.replace(/\/+$/, "");
  let apiOrigin = "http://localhost:4000";
  try {
    const u = new URL(apiBaseUrl);
    apiOrigin = u.origin;
    if (opts.production && u.protocol !== "https:" && !LOCAL_HOSTS.has(u.hostname)) {
      errors.push("NEXT_PUBLIC_API_BASE_URL: must use https in production");
    }
  } catch {
    /* already reported by the schema */
  }
  return {
    errors,
    env: {
      apiBaseUrl,
      apiOrigin,
      legalDraft: v.NEXT_PUBLIC_LEGAL_DRAFT,
      jitsiDomain: v.NEXT_PUBLIC_JITSI_DOMAIN.toLowerCase(),
      supportEmail: v.NEXT_PUBLIC_SUPPORT_EMAIL ?? null,
      supportPhone: v.NEXT_PUBLIC_SUPPORT_PHONE ?? null,
      legalEntityName: v.NEXT_PUBLIC_LEGAL_ENTITY_NAME ?? "[Operating entity name — to be provided]",
      grievanceOfficerName: v.NEXT_PUBLIC_GRIEVANCE_OFFICER_NAME ?? "[Grievance Officer name — to be appointed]",
      grievanceOfficerEmail: v.NEXT_PUBLIC_GRIEVANCE_OFFICER_EMAIL ?? "[grievance email — to be provided]",
    },
  };
}

/** Literal reads so Next.js can inline the values into the client bundle. */
export function readRawPublicEnv(): RawPublicEnv {
  return {
    NEXT_PUBLIC_API_BASE_URL: process.env.NEXT_PUBLIC_API_BASE_URL,
    NEXT_PUBLIC_LEGAL_DRAFT: process.env.NEXT_PUBLIC_LEGAL_DRAFT,
    NEXT_PUBLIC_JITSI_DOMAIN: process.env.NEXT_PUBLIC_JITSI_DOMAIN,
    NEXT_PUBLIC_SUPPORT_EMAIL: process.env.NEXT_PUBLIC_SUPPORT_EMAIL,
    NEXT_PUBLIC_SUPPORT_PHONE: process.env.NEXT_PUBLIC_SUPPORT_PHONE,
    NEXT_PUBLIC_LEGAL_ENTITY_NAME: process.env.NEXT_PUBLIC_LEGAL_ENTITY_NAME,
    NEXT_PUBLIC_GRIEVANCE_OFFICER_NAME: process.env.NEXT_PUBLIC_GRIEVANCE_OFFICER_NAME,
    NEXT_PUBLIC_GRIEVANCE_OFFICER_EMAIL: process.env.NEXT_PUBLIC_GRIEVANCE_OFFICER_EMAIL,
  };
}

/** Build-time guard (next.config.ts). Throws with every problem listed. */
export function assertValidPublicEnv(production: boolean): PublicEnv {
  const { env, errors } = parsePublicEnv(readRawPublicEnv(), { production });
  if (errors.length) {
    throw new Error(`Invalid public environment for apps/web:\n  - ${errors.join("\n  - ")}`);
  }
  return env;
}

export const publicEnv: PublicEnv = parsePublicEnv(readRawPublicEnv(), {
  production: process.env.NODE_ENV === "production",
}).env;
