CREATE TABLE "care_message_reads" (
	"care_episode_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"last_read_seq" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "care_message_reads_care_episode_id_user_id_pk" PRIMARY KEY("care_episode_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "care_messages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"seq" serial NOT NULL,
	"care_episode_id" uuid NOT NULL,
	"sender_user_id" uuid,
	"sender_name" text NOT NULL,
	"sender_role" text NOT NULL,
	"kind" text DEFAULT 'text' NOT NULL,
	"text" text NOT NULL,
	"attachment_record_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "contact_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"care_episode_id" uuid,
	"coordinator_user_id" uuid NOT NULL,
	"coordinator_name" text NOT NULL,
	"channel" text NOT NULL,
	"outcome" text NOT NULL,
	"note" text NOT NULL,
	"follow_up_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "doctor_leaves" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"doctor_id" uuid NOT NULL,
	"date" date NOT NULL,
	"reason" text,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "doctor_schedules" (
	"doctor_id" uuid PRIMARY KEY NOT NULL,
	"weekly" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"updated_by_user_id" uuid,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "invoice_counters" (
	"fy" text PRIMARY KEY NOT NULL,
	"last_seq" integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE "invoices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"payment_id" uuid NOT NULL,
	"number" text NOT NULL,
	"fy" text NOT NULL,
	"seq" integer NOT NULL,
	"issued_at" timestamp with time zone DEFAULT now() NOT NULL,
	"billed_to" jsonb NOT NULL,
	"seller" jsonb NOT NULL,
	"lines" jsonb NOT NULL,
	"subtotal" integer NOT NULL,
	"tax" integer NOT NULL,
	"total" integer NOT NULL,
	"pdf_storage_key" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "invoices_payment_id_unique" UNIQUE("payment_id"),
	CONSTRAINT "invoices_number_unique" UNIQUE("number")
);
--> statement-breakpoint
CREATE TABLE "media" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"owner_user_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"public_profile_photo" boolean DEFAULT false NOT NULL,
	"storage_key" text NOT NULL,
	"mime_type" text NOT NULL,
	"size_bytes" integer NOT NULL,
	"sha256" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "prescriptions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"doctor_id" uuid NOT NULL,
	"appointment_id" uuid NOT NULL,
	"care_episode_id" uuid NOT NULL,
	"patient_name" text NOT NULL,
	"patient_age" integer,
	"patient_gender" text NOT NULL,
	"doctor_name" text NOT NULL,
	"doctor_qualifications" text NOT NULL,
	"doctor_registration" text NOT NULL,
	"clinical_note" text,
	"items" jsonb NOT NULL,
	"advice" text,
	"follow_up_in_days" integer,
	"record_id" uuid NOT NULL,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "provider_application_documents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"application_id" uuid NOT NULL,
	"doc_type" text NOT NULL,
	"file_name" text NOT NULL,
	"mime_type" text NOT NULL,
	"size_bytes" integer NOT NULL,
	"storage_key" text NOT NULL,
	"sha256" text,
	"uploaded_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "provider_applications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"type" text NOT NULL,
	"full_name" text NOT NULL,
	"qualification" text NOT NULL,
	"registration_number" text NOT NULL,
	"registration_council" text,
	"specialty" text,
	"experience_years" integer DEFAULT 0 NOT NULL,
	"languages" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"preferred_zone_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"status" text DEFAULT 'submitted' NOT NULL,
	"decision_note" text,
	"decided_by_user_id" uuid,
	"decided_by_name" text,
	"decided_at" timestamp with time zone,
	"provider_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "referrals" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"care_episode_id" uuid NOT NULL,
	"facility_id" uuid NOT NULL,
	"specialty" text,
	"urgency" text NOT NULL,
	"reason" text NOT NULL,
	"clinical_summary" text,
	"status" text DEFAULT 'created' NOT NULL,
	"letter_record_id" uuid NOT NULL,
	"created_by_user_id" uuid NOT NULL,
	"created_by_name" text NOT NULL,
	"doctor_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "reviews" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"target_type" text NOT NULL,
	"target_id" uuid NOT NULL,
	"doctor_id" uuid,
	"provider_id" uuid,
	"subject_name" text NOT NULL,
	"patient_id" uuid,
	"author_user_id" uuid,
	"rating" integer NOT NULL,
	"text" text,
	"status" text DEFAULT 'pending' NOT NULL,
	"author_label" text DEFAULT 'Verified patient' NOT NULL,
	"moderation_note" text,
	"moderated_by_user_id" uuid,
	"moderated_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "schemes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"authority" text NOT NULL,
	"level" text NOT NULL,
	"state" text,
	"summary" text NOT NULL,
	"benefits" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"eligibility_hints" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"documents_typically_needed" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"official_url" text NOT NULL,
	"helpline" text,
	"status" text DEFAULT 'draft' NOT NULL,
	"last_reviewed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"disclaimer" text NOT NULL,
	"internal_note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "subscription_plans" (
	"code" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"price_monthly" integer NOT NULL,
	"price_yearly" integer NOT NULL,
	"benefits" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"max_members" integer NOT NULL,
	"coordinator_included" boolean DEFAULT false NOT NULL,
	"home_visit_discount_pct" integer DEFAULT 0 NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "subscriptions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"plan_code" text NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"billing" text NOT NULL,
	"current_period_start" timestamp with time zone,
	"current_period_end" timestamp with time zone,
	"cancel_at_period_end" boolean DEFAULT false NOT NULL,
	"renewal_reminder_sent_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "appointments" ADD COLUMN "completed_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "care_episodes" ADD COLUMN "coordinator_user_id" uuid;--> statement-breakpoint
ALTER TABLE "home_visits" ADD COLUMN "discount_applied" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "medications" ADD COLUMN "prescription_id" uuid;--> statement-breakpoint
ALTER TABLE "patients" ADD COLUMN "abha_number" text;--> statement-breakpoint
ALTER TABLE "patients" ADD COLUMN "abha_address" text;--> statement-breakpoint
ALTER TABLE "patients" ADD COLUMN "abha_status" text DEFAULT 'unverified' NOT NULL;--> statement-breakpoint
ALTER TABLE "providers" ADD COLUMN "accepting_bookings" boolean DEFAULT true NOT NULL;--> statement-breakpoint
ALTER TABLE "providers" ADD COLUMN "rating_baseline_sum" double precision DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "providers" ADD COLUMN "rating_baseline_count" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "slots" ADD COLUMN "modes" jsonb DEFAULT '["video","audio","chat","in_clinic"]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "care_message_reads" ADD CONSTRAINT "care_message_reads_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_message_reads" ADD CONSTRAINT "care_message_reads_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_messages" ADD CONSTRAINT "care_messages_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_messages" ADD CONSTRAINT "care_messages_attachment_record_id_medical_records_id_fk" FOREIGN KEY ("attachment_record_id") REFERENCES "public"."medical_records"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "contact_logs" ADD CONSTRAINT "contact_logs_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "contact_logs" ADD CONSTRAINT "contact_logs_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "contact_logs" ADD CONSTRAINT "contact_logs_coordinator_user_id_users_id_fk" FOREIGN KEY ("coordinator_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "doctor_leaves" ADD CONSTRAINT "doctor_leaves_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "doctor_schedules" ADD CONSTRAINT "doctor_schedules_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "media" ADD CONSTRAINT "media_owner_user_id_users_id_fk" FOREIGN KEY ("owner_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_appointment_id_appointments_id_fk" FOREIGN KEY ("appointment_id") REFERENCES "public"."appointments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescriptions" ADD CONSTRAINT "prescriptions_record_id_medical_records_id_fk" FOREIGN KEY ("record_id") REFERENCES "public"."medical_records"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "provider_application_documents" ADD CONSTRAINT "provider_application_documents_application_id_provider_applications_id_fk" FOREIGN KEY ("application_id") REFERENCES "public"."provider_applications"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "provider_applications" ADD CONSTRAINT "provider_applications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_facility_id_facilities_id_fk" FOREIGN KEY ("facility_id") REFERENCES "public"."facilities"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_letter_record_id_medical_records_id_fk" FOREIGN KEY ("letter_record_id") REFERENCES "public"."medical_records"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_created_by_user_id_users_id_fk" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_provider_id_providers_id_fk" FOREIGN KEY ("provider_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_plan_code_subscription_plans_code_fk" FOREIGN KEY ("plan_code") REFERENCES "public"."subscription_plans"("code") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "care_messages_episode_idx" ON "care_messages" USING btree ("care_episode_id","seq");--> statement-breakpoint
CREATE INDEX "contact_logs_patient_idx" ON "contact_logs" USING btree ("patient_id","created_at");--> statement-breakpoint
CREATE INDEX "contact_logs_coordinator_idx" ON "contact_logs" USING btree ("coordinator_user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "doctor_leaves_doctor_date_uq" ON "doctor_leaves" USING btree ("doctor_id","date");--> statement-breakpoint
CREATE UNIQUE INDEX "invoices_fy_seq_uq" ON "invoices" USING btree ("fy","seq");--> statement-breakpoint
CREATE INDEX "prescriptions_patient_idx" ON "prescriptions" USING btree ("patient_id","created_at");--> statement-breakpoint
CREATE INDEX "provider_application_docs_app_idx" ON "provider_application_documents" USING btree ("application_id");--> statement-breakpoint
CREATE INDEX "provider_applications_status_idx" ON "provider_applications" USING btree ("status","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "provider_applications_one_open_uq" ON "provider_applications" USING btree ("user_id") WHERE status <> 'rejected';--> statement-breakpoint
CREATE INDEX "referrals_patient_idx" ON "referrals" USING btree ("patient_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "reviews_target_uq" ON "reviews" USING btree ("target_type","target_id");--> statement-breakpoint
CREATE INDEX "reviews_doctor_idx" ON "reviews" USING btree ("doctor_id","status");--> statement-breakpoint
CREATE INDEX "reviews_provider_idx" ON "reviews" USING btree ("provider_id","status");--> statement-breakpoint
CREATE INDEX "reviews_status_idx" ON "reviews" USING btree ("status","created_at");--> statement-breakpoint
CREATE INDEX "subscriptions_user_idx" ON "subscriptions" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "subscriptions_one_active_uq" ON "subscriptions" USING btree ("user_id") WHERE status = 'active';--> statement-breakpoint
ALTER TABLE "care_episodes" ADD CONSTRAINT "care_episodes_coordinator_user_id_users_id_fk" FOREIGN KEY ("coordinator_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "episodes_coordinator_idx" ON "care_episodes" USING btree ("coordinator_user_id");
--> statement-breakpoint
-- v1.2 data migration (hand-written, part of this new migration only).
-- Existing doctors keep their previous availability as a weekly template (Mon-Sat 09:00-13:00, 14:00-18:00, 30 min, all modes).
INSERT INTO "doctor_schedules" ("doctor_id", "weekly") SELECT "id", '[{"weekday":1,"start":"09:00","end":"13:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":1,"start":"14:00","end":"18:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":2,"start":"09:00","end":"13:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":2,"start":"14:00","end":"18:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":3,"start":"09:00","end":"13:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":3,"start":"14:00","end":"18:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":4,"start":"09:00","end":"13:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":4,"start":"14:00","end":"18:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":5,"start":"09:00","end":"13:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":5,"start":"14:00","end":"18:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":6,"start":"09:00","end":"13:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]},{"weekday":6,"start":"14:00","end":"18:00","slotMins":30,"modes":["video","audio","chat","in_clinic"]}]'::jsonb FROM "providers" WHERE "kind" = 'doctor' ON CONFLICT DO NOTHING;
--> statement-breakpoint
UPDATE "appointments" SET "completed_at" = "updated_at" WHERE "status" = 'completed' AND "completed_at" IS NULL;
--> statement-breakpoint
-- Ratings shown so far become the imported baseline; legacy doctor_reviews become published Review rows.
UPDATE "providers" SET "rating_baseline_count" = "rating_count", "rating_baseline_sum" = COALESCE("rating", 0) * "rating_count";
--> statement-breakpoint
INSERT INTO "reviews" ("target_type", "target_id", "doctor_id", "subject_name", "rating", "text", "status", "author_label", "created_at")
SELECT 'appointment', gen_random_uuid(), dr."provider_id", p."name", dr."rating", dr."text", 'published', 'Verified patient', dr."created_at"
FROM "doctor_reviews" dr JOIN "providers" p ON p."id" = dr."provider_id";
--> statement-breakpoint
UPDATE "providers" p SET "rating_baseline_count" = GREATEST(0, p."rating_baseline_count" - x.n), "rating_baseline_sum" = GREATEST(0, p."rating_baseline_sum" - x.s)
FROM (SELECT "provider_id", COUNT(*)::int AS n, SUM("rating")::float8 AS s FROM "doctor_reviews" GROUP BY "provider_id") x WHERE x."provider_id" = p."id";
--> statement-breakpoint
UPDATE "feature_flags" SET "enabled" = true, "updated_at" = now() WHERE "key" = 'govt_schemes';
