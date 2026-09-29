CREATE TABLE "abdm_consent_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"hi_types" jsonb NOT NULL,
	"from_date" date NOT NULL,
	"to_date" date NOT NULL,
	"purpose" text NOT NULL,
	"status" text DEFAULT 'requested' NOT NULL,
	"records_imported" integer DEFAULT 0 NOT NULL,
	"gateway_request_id" text,
	"granted_at" timestamp with time zone,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "abdm_transactions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"abha_number" text,
	"gateway_txn_id" text,
	"status" text DEFAULT 'otp_sent' NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ambulance_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"type" text NOT NULL,
	"status" text DEFAULT 'searching' NOT NULL,
	"pickup" jsonb NOT NULL,
	"destination_facility_id" uuid,
	"reason" text NOT NULL,
	"sos_id" uuid,
	"partner_name" text NOT NULL,
	"partner_request_id" text,
	"vehicle" jsonb,
	"eta_minutes" integer,
	"location" jsonb,
	"vehicle_start" jsonb,
	"timeline" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"safety_event_id" uuid,
	"care_episode_id" uuid,
	"assigned_at" timestamp with time zone,
	"cancel_reason" text,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "checkin_settings" (
	"patient_id" uuid PRIMARY KEY NOT NULL,
	"enabled" boolean DEFAULT false NOT NULL,
	"window_start" text DEFAULT '08:00' NOT NULL,
	"window_end" text DEFAULT '10:00' NOT NULL,
	"escalate_after_mins" integer DEFAULT 60 NOT NULL,
	"notify_family" boolean DEFAULT true NOT NULL,
	"notify_coordinator" boolean DEFAULT true NOT NULL,
	"active_until" date,
	"updated_by_user_id" uuid,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "checkins" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"date" date NOT NULL,
	"status" text NOT NULL,
	"checked_in_at" timestamp with time zone,
	"mood" integer,
	"note" text,
	"source" text,
	"missed_alerted_at" timestamp with time zone,
	"escalated_at" timestamp with time zone,
	"safety_event_id" uuid,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "clinical_content_packs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"kind" text NOT NULL,
	"version" text NOT NULL,
	"status" text DEFAULT 'fixture_unapproved' NOT NULL,
	"active" boolean DEFAULT false NOT NULL,
	"content" jsonb NOT NULL,
	"approved_by" text,
	"approved_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "coupon_redemptions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"coupon_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"payment_id" uuid NOT NULL,
	"discount" integer NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "coupons" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL,
	"description" text NOT NULL,
	"type" text NOT NULL,
	"value" integer NOT NULL,
	"max_discount" integer,
	"min_amount" integer,
	"applies_to" jsonb NOT NULL,
	"valid_from" timestamp with time zone NOT NULL,
	"valid_to" timestamp with time zone NOT NULL,
	"usage_limit" integer,
	"per_user_limit" integer DEFAULT 1 NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "coupons_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "diet_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"plan_id" uuid NOT NULL,
	"date" date NOT NULL,
	"slot" text NOT NULL,
	"followed" boolean NOT NULL,
	"note" text,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "diet_plans" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"template_code" text,
	"author_user_id" uuid NOT NULL,
	"author_name" text NOT NULL,
	"author_role" text NOT NULL,
	"conditions" jsonb NOT NULL,
	"calorie_target" integer,
	"meals" jsonb NOT NULL,
	"avoid" jsonb NOT NULL,
	"notes" text,
	"valid_until" date NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "diet_templates" (
	"code" text PRIMARY KEY NOT NULL,
	"version" text NOT NULL,
	"name" text NOT NULL,
	"conditions" jsonb NOT NULL,
	"calorie_target" integer,
	"meals" jsonb NOT NULL,
	"avoid" jsonb NOT NULL,
	"notes" text,
	"status" text DEFAULT 'fixture_unapproved' NOT NULL,
	"approved_by" text,
	"approved_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "discharges" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"facility_id" uuid NOT NULL,
	"patient_id" uuid NOT NULL,
	"discharge_date" date NOT NULL,
	"diagnosis_summary" text NOT NULL,
	"treating_doctor_name" text NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"care_episode_id" uuid NOT NULL,
	"care_plan_id" uuid NOT NULL,
	"enrollment_id" uuid,
	"record_id" uuid,
	"follow_up" jsonb NOT NULL,
	"invited_phones" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"completed_at" timestamp with time zone,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "exercise_plans" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"care_episode_id" uuid,
	"author_user_id" uuid NOT NULL,
	"author_name" text NOT NULL,
	"author_role" text NOT NULL,
	"items" jsonb NOT NULL,
	"start_date" date NOT NULL,
	"end_date" date NOT NULL,
	"weeks" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "exercise_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"plan_id" uuid NOT NULL,
	"at" timestamp with time zone DEFAULT now() NOT NULL,
	"completed_exercise_ids" jsonb NOT NULL,
	"pain_score" integer NOT NULL,
	"note" text,
	"created_by_user_id" uuid
);
--> statement-breakpoint
CREATE TABLE "exercises" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL,
	"title" text NOT NULL,
	"body_area" text NOT NULL,
	"level" text NOT NULL,
	"duration_secs" integer NOT NULL,
	"video_url" text,
	"image_url" text,
	"instructions" jsonb NOT NULL,
	"precautions" jsonb NOT NULL,
	"content_version" text NOT NULL,
	"status" text DEFAULT 'fixture_unapproved' NOT NULL,
	CONSTRAINT "exercises_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "insurance_policies" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"insurer_code" text NOT NULL,
	"policy_number_enc" text NOT NULL,
	"policy_number_last4" text NOT NULL,
	"plan_name" text,
	"type" text NOT NULL,
	"sum_insured" integer,
	"valid_from" date NOT NULL,
	"valid_to" date NOT NULL,
	"tpa_name" text,
	"card_record_id" uuid,
	"members_covered" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"deleted_at" timestamp with time zone,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "insurers" (
	"code" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"type" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE "invite_redemptions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"inviter_user_id" uuid NOT NULL,
	"invitee_user_id" uuid NOT NULL,
	"code" text NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"rewarded_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "invite_redemptions_invitee_user_id_unique" UNIQUE("invitee_user_id")
);
--> statement-breakpoint
CREATE TABLE "ivr_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"provider" text NOT NULL,
	"call_id" text,
	"from_phone" text NOT NULL,
	"user_id" uuid,
	"lang" text,
	"state" text DEFAULT 'start' NOT NULL,
	"ended_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "lab_orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"tests" jsonb NOT NULL,
	"package_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"total" integer NOT NULL,
	"discount" integer DEFAULT 0 NOT NULL,
	"status" text DEFAULT 'pending_payment' NOT NULL,
	"collection_visit_id" uuid,
	"address" jsonb NOT NULL,
	"preferred_start" timestamp with time zone NOT NULL,
	"preferred_end" timestamp with time zone NOT NULL,
	"report_record_id" uuid,
	"partner_name" text NOT NULL,
	"partner_order_id" text,
	"timeline" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"care_episode_id" uuid NOT NULL,
	"prescription_id" uuid,
	"processing_at" timestamp with time zone,
	"cancel_reason" text,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "lab_packages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL,
	"name" text NOT NULL,
	"test_ids" jsonb NOT NULL,
	"price" integer NOT NULL,
	"mrp" integer NOT NULL,
	"description" text NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	CONSTRAINT "lab_packages_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "lab_tests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"category" text NOT NULL,
	"sample_type" text NOT NULL,
	"fasting_required" boolean DEFAULT false NOT NULL,
	"fasting_hours" integer,
	"turnaround_hours" integer NOT NULL,
	"price" integer NOT NULL,
	"mrp" integer NOT NULL,
	"partner_name" text NOT NULL,
	"sample_range" jsonb,
	"active" boolean DEFAULT true NOT NULL,
	CONSTRAINT "lab_tests_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "organization_codes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"organization_id" uuid NOT NULL,
	"code" text NOT NULL,
	"redeemed_by_user_id" uuid,
	"redeemed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "organization_codes_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "organizations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"contact_name" text NOT NULL,
	"contact_email" text NOT NULL,
	"plan_code" text NOT NULL,
	"seats" integer NOT NULL,
	"valid_from" date NOT NULL,
	"valid_to" date NOT NULL,
	"billing_note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "patient_locations" (
	"patient_id" uuid PRIMARY KEY NOT NULL,
	"lat" double precision NOT NULL,
	"lng" double precision NOT NULL,
	"accuracy_m" double precision,
	"source" text NOT NULL,
	"inside" boolean,
	"at" timestamp with time zone NOT NULL,
	"geofence_event_id" uuid
);
--> statement-breakpoint
CREATE TABLE "preventive_records" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"code" text NOT NULL,
	"done_at" date NOT NULL,
	"notes" text,
	"record_id" uuid,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "program_breaches" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"enrollment_id" uuid NOT NULL,
	"vital_id" uuid NOT NULL,
	"at" timestamp with time zone NOT NULL,
	"type" text NOT NULL,
	"value" double precision NOT NULL,
	"threshold" jsonb NOT NULL,
	"safety_event_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "program_enrollments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"template_code" text NOT NULL,
	"template_version" text NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"thresholds" jsonb NOT NULL,
	"thresholds_approved_by_user_id" uuid,
	"thresholds_approved_by_name" text,
	"start_date" date NOT NULL,
	"end_date" date,
	"care_episode_id" uuid,
	"last_weekly_report_week" text,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "program_templates" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL,
	"version" text NOT NULL,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"metrics" jsonb NOT NULL,
	"default_thresholds" jsonb NOT NULL,
	"status" text DEFAULT 'fixture_unapproved' NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	"approved_by" text,
	"approved_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "provider_attendance" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"provider_id" uuid NOT NULL,
	"action" text NOT NULL,
	"at" timestamp with time zone DEFAULT now() NOT NULL,
	"lat" double precision,
	"lng" double precision
);
--> statement-breakpoint
CREATE TABLE "provider_supplies" (
	"provider_id" uuid NOT NULL,
	"code" text NOT NULL,
	"on_hand" integer DEFAULT 0 NOT NULL,
	"reorder_level" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "provider_supplies_provider_id_code_pk" PRIMARY KEY("provider_id","code")
);
--> statement-breakpoint
CREATE TABLE "safe_zones" (
	"patient_id" uuid PRIMARY KEY NOT NULL,
	"enabled" boolean NOT NULL,
	"center_lat" double precision NOT NULL,
	"center_lng" double precision NOT NULL,
	"radius_meters" integer NOT NULL,
	"label" text,
	"active_from" text,
	"active_to" text,
	"updated_by_user_id" uuid,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "scribe_drafts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"appointment_id" uuid NOT NULL,
	"doctor_user_id" uuid NOT NULL,
	"transcript" text NOT NULL,
	"draft" jsonb NOT NULL,
	"model" text NOT NULL,
	"generated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "second_opinion_pricing" (
	"specialty" text PRIMARY KEY NOT NULL,
	"price" integer NOT NULL,
	"turnaround_hours" integer NOT NULL,
	"active" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "second_opinions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"specialty" text NOT NULL,
	"question" text NOT NULL,
	"record_ids" jsonb NOT NULL,
	"status" text DEFAULT 'pending_payment' NOT NULL,
	"price" integer NOT NULL,
	"turnaround_hours" integer NOT NULL,
	"doctor_id" uuid,
	"opinion" text,
	"recommendations" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"suggest_teleconsult" boolean,
	"opinion_record_id" uuid,
	"due_at" timestamp with time zone,
	"claimed_at" timestamp with time zone,
	"answered_at" timestamp with time zone,
	"overdue_alerted_at" timestamp with time zone,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "sos_devices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"device_id" text NOT NULL,
	"model" text NOT NULL,
	"paired_at" timestamp with time zone DEFAULT now() NOT NULL,
	"unpaired_at" timestamp with time zone,
	"created_by_user_id" uuid
);
--> statement-breakpoint
CREATE TABLE "supply_usage" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"provider_id" uuid NOT NULL,
	"visit_id" uuid NOT NULL,
	"items" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "support_tickets" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"seq" serial NOT NULL,
	"user_id" uuid NOT NULL,
	"subject" text NOT NULL,
	"category" text NOT NULL,
	"status" text DEFAULT 'open' NOT NULL,
	"priority" text DEFAULT 'normal' NOT NULL,
	"assigned_to_user_id" uuid,
	"ref_type" text,
	"ref_id" text,
	"attachment_record_id" uuid,
	"patient_id" uuid,
	"rating_score" integer,
	"rating_comment" text,
	"sla_due_at" timestamp with time zone NOT NULL,
	"first_response_at" timestamp with time zone,
	"resolved_at" timestamp with time zone,
	"sla_breached_at" timestamp with time zone,
	"safety_event_id" uuid,
	"source" text DEFAULT 'app' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "tenants" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" text NOT NULL,
	"display_name" text NOT NULL,
	"primary_color" text NOT NULL,
	"logo_media_id" uuid,
	"facility_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"support_phone" text,
	"support_email" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "tenants_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "ticket_messages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"ticket_id" uuid NOT NULL,
	"author_user_id" uuid,
	"author_name" text NOT NULL,
	"author_role" text NOT NULL,
	"text" text NOT NULL,
	"internal" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "wallet_transactions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"type" text NOT NULL,
	"amount" integer NOT NULL,
	"remaining" integer DEFAULT 0 NOT NULL,
	"reason" text NOT NULL,
	"ref_type" text,
	"ref_id" text,
	"expires_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "webhook_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"source" text NOT NULL,
	"event_id" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "whatsapp_optins" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"opted_in" boolean DEFAULT false NOT NULL,
	"opted_in_at" timestamp with time zone,
	"opted_out_at" timestamp with time zone,
	"conversation_id" uuid,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "care_plans" ALTER COLUMN "doctor_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "care_episodes" ADD COLUMN "tenant_code" text;--> statement-breakpoint
ALTER TABLE "care_plans" ADD COLUMN "issued_by" text;--> statement-breakpoint
ALTER TABLE "facilities" ADD COLUMN "cashless_insurers" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "medical_records" ADD COLUMN "imported_via" text;--> statement-breakpoint
ALTER TABLE "patients" ADD COLUMN "tenant_code" text;--> statement-breakpoint
ALTER TABLE "payments" ADD COLUMN "discount" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "payments" ADD COLUMN "wallet_used" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "payments" ADD COLUMN "coupon_code" text;--> statement-breakpoint
ALTER TABLE "payments" ADD COLUMN "wallet_refunded" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "prescriptions" ADD COLUMN "warnings" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "prescriptions" ADD COLUMN "override_reason" text;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD COLUMN "sponsor_org_id" uuid;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD COLUMN "sponsor_name" text;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "facility_id" uuid;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "invite_code" text;--> statement-breakpoint
ALTER TABLE "abdm_consent_requests" ADD CONSTRAINT "abdm_consent_requests_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "abdm_transactions" ADD CONSTRAINT "abdm_transactions_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ambulance_requests" ADD CONSTRAINT "ambulance_requests_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkin_settings" ADD CONSTRAINT "checkin_settings_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "coupon_redemptions" ADD CONSTRAINT "coupon_redemptions_coupon_id_coupons_id_fk" FOREIGN KEY ("coupon_id") REFERENCES "public"."coupons"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "coupon_redemptions" ADD CONSTRAINT "coupon_redemptions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_logs" ADD CONSTRAINT "diet_logs_plan_id_diet_plans_id_fk" FOREIGN KEY ("plan_id") REFERENCES "public"."diet_plans"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_plans" ADD CONSTRAINT "diet_plans_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "discharges" ADD CONSTRAINT "discharges_facility_id_facilities_id_fk" FOREIGN KEY ("facility_id") REFERENCES "public"."facilities"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "discharges" ADD CONSTRAINT "discharges_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "discharges" ADD CONSTRAINT "discharges_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "discharges" ADD CONSTRAINT "discharges_care_plan_id_care_plans_id_fk" FOREIGN KEY ("care_plan_id") REFERENCES "public"."care_plans"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise_plans" ADD CONSTRAINT "exercise_plans_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise_sessions" ADD CONSTRAINT "exercise_sessions_plan_id_exercise_plans_id_fk" FOREIGN KEY ("plan_id") REFERENCES "public"."exercise_plans"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "insurance_policies" ADD CONSTRAINT "insurance_policies_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invite_redemptions" ADD CONSTRAINT "invite_redemptions_inviter_user_id_users_id_fk" FOREIGN KEY ("inviter_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invite_redemptions" ADD CONSTRAINT "invite_redemptions_invitee_user_id_users_id_fk" FOREIGN KEY ("invitee_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lab_orders" ADD CONSTRAINT "lab_orders_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lab_orders" ADD CONSTRAINT "lab_orders_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organization_codes" ADD CONSTRAINT "organization_codes_organization_id_organizations_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_plan_code_subscription_plans_code_fk" FOREIGN KEY ("plan_code") REFERENCES "public"."subscription_plans"("code") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "patient_locations" ADD CONSTRAINT "patient_locations_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "preventive_records" ADD CONSTRAINT "preventive_records_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "program_breaches" ADD CONSTRAINT "program_breaches_enrollment_id_program_enrollments_id_fk" FOREIGN KEY ("enrollment_id") REFERENCES "public"."program_enrollments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "program_enrollments" ADD CONSTRAINT "program_enrollments_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "provider_attendance" ADD CONSTRAINT "provider_attendance_provider_id_providers_id_fk" FOREIGN KEY ("provider_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "provider_supplies" ADD CONSTRAINT "provider_supplies_provider_id_providers_id_fk" FOREIGN KEY ("provider_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "safe_zones" ADD CONSTRAINT "safe_zones_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "scribe_drafts" ADD CONSTRAINT "scribe_drafts_appointment_id_appointments_id_fk" FOREIGN KEY ("appointment_id") REFERENCES "public"."appointments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "second_opinions" ADD CONSTRAINT "second_opinions_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "second_opinions" ADD CONSTRAINT "second_opinions_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sos_devices" ADD CONSTRAINT "sos_devices_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "supply_usage" ADD CONSTRAINT "supply_usage_provider_id_providers_id_fk" FOREIGN KEY ("provider_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ticket_messages" ADD CONSTRAINT "ticket_messages_ticket_id_support_tickets_id_fk" FOREIGN KEY ("ticket_id") REFERENCES "public"."support_tickets"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "wallet_transactions" ADD CONSTRAINT "wallet_transactions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "whatsapp_optins" ADD CONSTRAINT "whatsapp_optins_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "abdm_consent_patient_idx" ON "abdm_consent_requests" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "ambulance_requests_status_idx" ON "ambulance_requests" USING btree ("status");--> statement-breakpoint
CREATE UNIQUE INDEX "checkins_patient_date_uq" ON "checkins" USING btree ("patient_id","date");--> statement-breakpoint
CREATE UNIQUE INDEX "clinical_packs_kind_version_uq" ON "clinical_content_packs" USING btree ("kind","version");--> statement-breakpoint
CREATE INDEX "coupon_redemptions_coupon_idx" ON "coupon_redemptions" USING btree ("coupon_id","user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "diet_logs_plan_date_slot_uq" ON "diet_logs" USING btree ("plan_id","date","slot");--> statement-breakpoint
CREATE INDEX "diet_plans_patient_idx" ON "diet_plans" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "discharges_facility_idx" ON "discharges" USING btree ("facility_id","status");--> statement-breakpoint
CREATE INDEX "exercise_plans_patient_idx" ON "exercise_plans" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "exercise_sessions_plan_idx" ON "exercise_sessions" USING btree ("plan_id","at");--> statement-breakpoint
CREATE INDEX "insurance_policies_patient_idx" ON "insurance_policies" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "lab_orders_patient_idx" ON "lab_orders" USING btree ("patient_id","created_at");--> statement-breakpoint
CREATE INDEX "lab_orders_status_idx" ON "lab_orders" USING btree ("status");--> statement-breakpoint
CREATE INDEX "organization_codes_org_idx" ON "organization_codes" USING btree ("organization_id");--> statement-breakpoint
CREATE INDEX "preventive_records_patient_idx" ON "preventive_records" USING btree ("patient_id","code");--> statement-breakpoint
CREATE UNIQUE INDEX "program_breaches_vital_uq" ON "program_breaches" USING btree ("enrollment_id","vital_id");--> statement-breakpoint
CREATE INDEX "program_enrollments_patient_idx" ON "program_enrollments" USING btree ("patient_id","status");--> statement-breakpoint
CREATE UNIQUE INDEX "program_templates_code_version_uq" ON "program_templates" USING btree ("code","version");--> statement-breakpoint
CREATE INDEX "provider_attendance_idx" ON "provider_attendance" USING btree ("provider_id","at");--> statement-breakpoint
CREATE INDEX "second_opinions_patient_idx" ON "second_opinions" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "second_opinions_status_idx" ON "second_opinions" USING btree ("status","specialty");--> statement-breakpoint
CREATE UNIQUE INDEX "sos_devices_active_uq" ON "sos_devices" USING btree ("device_id") WHERE unpaired_at is null;--> statement-breakpoint
CREATE INDEX "support_tickets_user_idx" ON "support_tickets" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "support_tickets_status_idx" ON "support_tickets" USING btree ("status","sla_due_at");--> statement-breakpoint
CREATE INDEX "ticket_messages_ticket_idx" ON "ticket_messages" USING btree ("ticket_id","created_at");--> statement-breakpoint
CREATE INDEX "wallet_tx_user_idx" ON "wallet_transactions" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "webhook_events_uq" ON "webhook_events" USING btree ("source","event_id");--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_invite_code_unique" UNIQUE("invite_code");