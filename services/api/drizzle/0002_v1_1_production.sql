CREATE TABLE "account_deletion_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"status" text DEFAULT 'scheduled' NOT NULL,
	"reason" text,
	"requested_at" timestamp with time zone DEFAULT now() NOT NULL,
	"scheduled_for" timestamp with time zone NOT NULL,
	"cancelled_at" timestamp with time zone,
	"completed_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "data_exports" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"status" text DEFAULT 'ready' NOT NULL,
	"storage_key" text,
	"size_bytes" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"purged_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "mfa_attempts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"success" boolean NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "mfa_recovery_codes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"code_hash" text NOT NULL,
	"used_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "patients" ADD COLUMN "retention_hold" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "patients" ADD COLUMN "anonymised_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "payments" ADD COLUMN "checkout" jsonb;--> statement-breakpoint
ALTER TABLE "sessions" ADD COLUMN "mfa_verified_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "mfa_secret_enc" text;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "mfa_pending_secret_enc" text;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "mfa_enrolled_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "mfa_last_step" integer;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "deleted_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "account_deletion_requests" ADD CONSTRAINT "account_deletion_requests_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_exports" ADD CONSTRAINT "data_exports_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mfa_attempts" ADD CONSTRAINT "mfa_attempts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mfa_recovery_codes" ADD CONSTRAINT "mfa_recovery_codes_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "deletion_user_idx" ON "account_deletion_requests" USING btree ("user_id","requested_at");--> statement-breakpoint
CREATE INDEX "deletion_due_idx" ON "account_deletion_requests" USING btree ("status","scheduled_for");--> statement-breakpoint
CREATE UNIQUE INDEX "deletion_one_scheduled_uq" ON "account_deletion_requests" USING btree ("user_id") WHERE status = 'scheduled';--> statement-breakpoint
CREATE INDEX "data_exports_user_idx" ON "data_exports" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "mfa_attempts_user_idx" ON "mfa_attempts" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "mfa_recovery_user_idx" ON "mfa_recovery_codes" USING btree ("user_id");