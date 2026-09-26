CREATE TABLE "ai_feedback" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"ai_interaction_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"decision" text NOT NULL,
	"note" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ai_interactions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"use_case" text NOT NULL,
	"user_id" uuid,
	"patient_id" uuid,
	"conversation_id" uuid,
	"model" text NOT NULL,
	"prompt_version" text NOT NULL,
	"policy_version" text NOT NULL,
	"rule_pack_version" text NOT NULL,
	"safety_level" text NOT NULL,
	"latency_ms" integer NOT NULL,
	"input_tokens" integer DEFAULT 0 NOT NULL,
	"output_tokens" integer DEFAULT 0 NOT NULL,
	"fallback_used" boolean DEFAULT false NOT NULL,
	"error_code" text,
	"knowledge_source_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "allergies" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"substance" text NOT NULL,
	"reaction" text,
	"severity" text,
	"source" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "appointments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"doctor_id" uuid NOT NULL,
	"slot_id" uuid NOT NULL,
	"start_at" timestamp with time zone NOT NULL,
	"end_at" timestamp with time zone NOT NULL,
	"mode" text NOT NULL,
	"status" text DEFAULT 'pending_payment' NOT NULL,
	"reason" text NOT NULL,
	"fee" integer NOT NULL,
	"care_episode_id" uuid NOT NULL,
	"video_room_url" text,
	"clinician_notes" text,
	"outcome" text,
	"cancel_reason" text,
	"reminder_sent_at" timestamp with time zone,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "audit_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"actor_id" uuid,
	"actor_name" text,
	"actor_role" text,
	"action" text NOT NULL,
	"entity_type" text NOT NULL,
	"entity_id" text,
	"outcome" text NOT NULL,
	"ip" text,
	"correlation_id" text,
	"metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "care_episodes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"title" text NOT NULL,
	"concern" text NOT NULL,
	"status" text DEFAULT 'NEW' NOT NULL,
	"priority" text DEFAULT 'routine' NOT NULL,
	"owner_user_id" uuid,
	"next_action" text,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "care_plans" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"care_episode_id" uuid NOT NULL,
	"patient_id" uuid NOT NULL,
	"doctor_id" uuid NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"summary" text NOT NULL,
	"instructions" text NOT NULL,
	"follow_up" jsonb,
	"follow_up_due_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "care_tasks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"care_plan_id" uuid NOT NULL,
	"patient_id" uuid NOT NULL,
	"type" text NOT NULL,
	"title" text NOT NULL,
	"description" text,
	"due_at" timestamp with time zone,
	"owner" text NOT NULL,
	"status" text DEFAULT 'open' NOT NULL,
	"completed_at" timestamp with time zone,
	"completed_by_user_id" uuid,
	"completed_by_name" text,
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "conditions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"name" text NOT NULL,
	"since" text,
	"source" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "consents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"purpose" text NOT NULL,
	"version" text NOT NULL,
	"scope" text NOT NULL,
	"status" text DEFAULT 'granted' NOT NULL,
	"granted_at" timestamp with time zone DEFAULT now() NOT NULL,
	"revoked_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "conversations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"care_episode_id" uuid,
	"intake" jsonb NOT NULL,
	"state" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "devices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"push_token" text NOT NULL,
	"platform" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "devices_push_token_unique" UNIQUE("push_token")
);
--> statement-breakpoint
CREATE TABLE "doctor_reviews" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"provider_id" uuid NOT NULL,
	"rating" integer NOT NULL,
	"text" text NOT NULL,
	"author_label" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "dose_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"medication_id" uuid NOT NULL,
	"scheduled_at" timestamp with time zone NOT NULL,
	"status" text NOT NULL,
	"logged_at" timestamp with time zone DEFAULT now() NOT NULL,
	"logged_by_user_id" uuid
);
--> statement-breakpoint
CREATE TABLE "emergency_contacts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"name" text NOT NULL,
	"phone" text NOT NULL,
	"relation" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "episode_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"episode_id" uuid NOT NULL,
	"type" text NOT NULL,
	"description" text NOT NULL,
	"actor_user_id" uuid,
	"actor_name" text,
	"actor_role" text,
	"data" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "facilities" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"type" text NOT NULL,
	"address" text NOT NULL,
	"area" text NOT NULL,
	"city" text NOT NULL,
	"phone" text NOT NULL,
	"lat" double precision NOT NULL,
	"lng" double precision NOT NULL,
	"services" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"emergency_24x7" boolean DEFAULT false NOT NULL,
	"verified" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "fall_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"status" text DEFAULT 'awaiting_response' NOT NULL,
	"source" text NOT NULL,
	"lat" double precision,
	"lng" double precision,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"responded_at" timestamp with time zone,
	"escalated_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "family_access_grants" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"grantee_user_id" uuid NOT NULL,
	"relation" text NOT NULL,
	"permissions" jsonb NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"revoked_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "feature_flags" (
	"key" text PRIMARY KEY NOT NULL,
	"enabled" boolean NOT NULL,
	"description" text NOT NULL,
	"cohort" text,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "home_visit_services" (
	"code" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"price" integer NOT NULL,
	"duration_mins" integer NOT NULL,
	"icon" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE "home_visits" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"service_code" text NOT NULL,
	"status" text DEFAULT 'requested' NOT NULL,
	"price" integer NOT NULL,
	"reason" text NOT NULL,
	"address" jsonb NOT NULL,
	"preferred_start" timestamp with time zone NOT NULL,
	"preferred_end" timestamp with time zone NOT NULL,
	"care_episode_id" uuid NOT NULL,
	"visit_code" text NOT NULL,
	"provider_id" uuid,
	"rejected_provider_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"zone_id" uuid,
	"eta_minutes" integer,
	"timeline" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"observations" jsonb,
	"summary" text,
	"escalation" jsonb,
	"verify_attempts" integer DEFAULT 0 NOT NULL,
	"identity_verified_at" timestamp with time zone,
	"assigned_at" timestamp with time zone,
	"arrived_at" timestamp with time zone,
	"completed_at" timestamp with time zone,
	"sla_breached_at" timestamp with time zone,
	"cancel_reason" text,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "idempotency_keys" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"key" text NOT NULL,
	"route" text NOT NULL,
	"request_hash" text NOT NULL,
	"state" text DEFAULT 'in_progress' NOT NULL,
	"status_code" integer,
	"response" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "incidents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"type" text NOT NULL,
	"title" text NOT NULL,
	"description" text NOT NULL,
	"severity" text NOT NULL,
	"status" text DEFAULT 'open' NOT NULL,
	"patient_id" uuid,
	"ref_type" text,
	"ref_id" text,
	"reported_by_user_id" uuid,
	"reported_by_name" text NOT NULL,
	"notes" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "knowledge_chunks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"source_id" uuid NOT NULL,
	"ordinal" integer NOT NULL,
	"text" text NOT NULL,
	"terms" jsonb NOT NULL,
	"length" integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE "knowledge_sources" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"title" text NOT NULL,
	"owner" text NOT NULL,
	"version" text NOT NULL,
	"status" text DEFAULT 'draft' NOT NULL,
	"effective_date" date NOT NULL,
	"expires_at" date,
	"content" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "medical_records" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"type" text NOT NULL,
	"title" text NOT NULL,
	"record_date" date NOT NULL,
	"source" text NOT NULL,
	"uploaded_by_user_id" uuid,
	"uploaded_by_name" text,
	"file_name" text NOT NULL,
	"mime_type" text NOT NULL,
	"size_bytes" integer NOT NULL,
	"storage_key" text,
	"sha256" text,
	"ai_summary" jsonb,
	"home_visit_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "medications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"care_plan_id" uuid,
	"name" text NOT NULL,
	"dose" text NOT NULL,
	"frequency" text NOT NULL,
	"times" jsonb NOT NULL,
	"start_date" date NOT NULL,
	"end_date" date,
	"instructions" text,
	"source" text NOT NULL,
	"prescribed_by_name" text,
	"active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "messages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"conversation_id" uuid NOT NULL,
	"role" text NOT NULL,
	"kind" text NOT NULL,
	"text" text NOT NULL,
	"quick_replies" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"routing" jsonb,
	"safety" jsonb,
	"seq" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "mood_entries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"score" integer NOT NULL,
	"note" text,
	"share_with_clinician" boolean DEFAULT false NOT NULL,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notification_outbox" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"notification_id" uuid,
	"user_id" uuid,
	"channel" text NOT NULL,
	"recipient" text,
	"lock_screen_text" text NOT NULL,
	"critical" boolean DEFAULT false NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"next_attempt_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_error" text,
	"sent_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notification_preferences" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"push" boolean DEFAULT true NOT NULL,
	"sms" boolean DEFAULT true NOT NULL,
	"email" boolean DEFAULT false NOT NULL,
	"whatsapp" boolean DEFAULT false NOT NULL,
	"marketing" boolean DEFAULT false NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notifications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"title" text NOT NULL,
	"body" text NOT NULL,
	"category" text NOT NULL,
	"critical" boolean DEFAULT false NOT NULL,
	"read" boolean DEFAULT false NOT NULL,
	"deep_link" text,
	"template_key" text NOT NULL,
	"dedupe_key" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "otp_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"phone" text NOT NULL,
	"code_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"consumed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "patients" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text,
	"dob" date,
	"gender" text DEFAULT 'other' NOT NULL,
	"phone" text,
	"blood_group" text,
	"height_cm" double precision,
	"weight_kg" double precision,
	"user_id" uuid,
	"owner_user_id" uuid,
	"owner_relation" text DEFAULT 'self' NOT NULL,
	"avatar_url" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "payment_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"gateway_event_id" text NOT NULL,
	"payment_id" uuid,
	"type" text NOT NULL,
	"outcome" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "payment_events_gateway_event_id_unique" UNIQUE("gateway_event_id")
);
--> statement-breakpoint
CREATE TABLE "payments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"purpose" text NOT NULL,
	"ref_id" uuid NOT NULL,
	"patient_id" uuid NOT NULL,
	"amount" integer NOT NULL,
	"currency" text DEFAULT 'INR' NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"gateway" text NOT NULL,
	"gateway_order_id" text NOT NULL,
	"gateway_payment_id" text,
	"refunded_amount" integer DEFAULT 0 NOT NULL,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "pharmacy_orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"items" jsonb NOT NULL,
	"total" integer NOT NULL,
	"status" text DEFAULT 'pending_payment' NOT NULL,
	"partner_name" text NOT NULL,
	"prescription_record_id" uuid,
	"address" jsonb NOT NULL,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "products" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"pack_size" text NOT NULL,
	"mrp" integer NOT NULL,
	"price" integer NOT NULL,
	"category" text NOT NULL,
	"requires_prescription" boolean DEFAULT false NOT NULL,
	"image_url" text,
	"in_stock" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "provider_zones" (
	"provider_id" uuid NOT NULL,
	"zone_id" uuid NOT NULL,
	CONSTRAINT "provider_zones_provider_id_zone_id_pk" PRIMARY KEY("provider_id","zone_id")
);
--> statement-breakpoint
CREATE TABLE "providers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"type" text NOT NULL,
	"name" text NOT NULL,
	"qualification" text NOT NULL,
	"specialty" text,
	"registration_number" text NOT NULL,
	"verification_status" text DEFAULT 'pending' NOT NULL,
	"verification_note" text,
	"credential_expires_at" timestamp with time zone NOT NULL,
	"on_duty" boolean DEFAULT false NOT NULL,
	"capabilities" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"experience_years" integer DEFAULT 0 NOT NULL,
	"rating" double precision,
	"rating_count" integer DEFAULT 0 NOT NULL,
	"languages" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"fee_video" integer,
	"fee_audio" integer,
	"fee_chat" integer,
	"fee_in_clinic" integer,
	"bio" text DEFAULT '' NOT NULL,
	"facility_id" uuid,
	"photo_url" text,
	"last_lat" double precision,
	"last_lng" double precision,
	"last_location_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "providers_user_id_unique" UNIQUE("user_id")
);
--> statement-breakpoint
CREATE TABLE "record_shares" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"record_id" uuid NOT NULL,
	"doctor_id" uuid NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "refresh_tokens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"session_id" uuid NOT NULL,
	"token_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"used_at" timestamp with time zone,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "refresh_tokens_token_hash_unique" UNIQUE("token_hash")
);
--> statement-breakpoint
CREATE TABLE "refunds" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"payment_id" uuid NOT NULL,
	"amount" integer NOT NULL,
	"reason" text NOT NULL,
	"status" text DEFAULT 'processed' NOT NULL,
	"gateway_refund_id" text,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "safety_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"care_episode_id" uuid,
	"level" text NOT NULL,
	"source" text NOT NULL,
	"rules" jsonb NOT NULL,
	"status" text DEFAULT 'open' NOT NULL,
	"assigned_to_user_id" uuid,
	"assigned_to_name" text,
	"rule_pack_version" text,
	"acknowledged_at" timestamp with time zone,
	"resolved_at" timestamp with time zone,
	"note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "safety_rule_packs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"version" text NOT NULL,
	"status" text DEFAULT 'draft' NOT NULL,
	"active" boolean DEFAULT false NOT NULL,
	"approved_by" text,
	"approver_registration" text,
	"approved_at" timestamp with time zone,
	"rules" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "safety_rule_packs_version_unique" UNIQUE("version")
);
--> statement-breakpoint
CREATE TABLE "service_zones" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"city" text NOT NULL,
	"pincodes" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "service_zones_name_unique" UNIQUE("name")
);
--> statement-breakpoint
CREATE TABLE "sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"device_name" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"revoked_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "settlement_ledger" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"payment_id" uuid NOT NULL,
	"entry_type" text NOT NULL,
	"amount" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "slots" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"doctor_id" uuid NOT NULL,
	"start_at" timestamp with time zone NOT NULL,
	"end_at" timestamp with time zone NOT NULL,
	"status" text DEFAULT 'available' NOT NULL
);
--> statement-breakpoint
CREATE TABLE "sos_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"care_episode_id" uuid NOT NULL,
	"lat" double precision,
	"lng" double precision,
	"note" text,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "specialties" (
	"code" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"icon" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"phone" text NOT NULL,
	"name" text,
	"email" text,
	"roles" jsonb DEFAULT '["patient"]'::jsonb NOT NULL,
	"language" text DEFAULT 'en' NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"self_patient_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_login_at" timestamp with time zone,
	CONSTRAINT "users_phone_unique" UNIQUE("phone")
);
--> statement-breakpoint
CREATE TABLE "vitals" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"type" text NOT NULL,
	"value" double precision NOT NULL,
	"unit" text NOT NULL,
	"measured_at" timestamp with time zone NOT NULL,
	"source" text NOT NULL,
	"recorded_by_user_id" uuid,
	"recorded_by_name" text,
	"home_visit_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "wearable_connections" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"provider" text NOT NULL,
	"status" text DEFAULT 'connected' NOT NULL,
	"connected_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_sync_at" timestamp with time zone,
	"revoked_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "wound_cases" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"patient_id" uuid NOT NULL,
	"body_site" text NOT NULL,
	"note" text,
	"status" text NOT NULL,
	"quality" jsonb NOT NULL,
	"clinician_review" jsonb,
	"image_record_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "ai_feedback" ADD CONSTRAINT "ai_feedback_ai_interaction_id_ai_interactions_id_fk" FOREIGN KEY ("ai_interaction_id") REFERENCES "public"."ai_interactions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "allergies" ADD CONSTRAINT "allergies_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_slot_id_slots_id_fk" FOREIGN KEY ("slot_id") REFERENCES "public"."slots"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_created_by_user_id_users_id_fk" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_episodes" ADD CONSTRAINT "care_episodes_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_episodes" ADD CONSTRAINT "care_episodes_owner_user_id_users_id_fk" FOREIGN KEY ("owner_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_episodes" ADD CONSTRAINT "care_episodes_created_by_user_id_users_id_fk" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_plans" ADD CONSTRAINT "care_plans_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_plans" ADD CONSTRAINT "care_plans_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_plans" ADD CONSTRAINT "care_plans_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_tasks" ADD CONSTRAINT "care_tasks_care_plan_id_care_plans_id_fk" FOREIGN KEY ("care_plan_id") REFERENCES "public"."care_plans"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "care_tasks" ADD CONSTRAINT "care_tasks_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "conditions" ADD CONSTRAINT "conditions_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "consents" ADD CONSTRAINT "consents_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "devices" ADD CONSTRAINT "devices_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "doctor_reviews" ADD CONSTRAINT "doctor_reviews_provider_id_providers_id_fk" FOREIGN KEY ("provider_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "dose_logs" ADD CONSTRAINT "dose_logs_medication_id_medications_id_fk" FOREIGN KEY ("medication_id") REFERENCES "public"."medications"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "emergency_contacts" ADD CONSTRAINT "emergency_contacts_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "episode_events" ADD CONSTRAINT "episode_events_episode_id_care_episodes_id_fk" FOREIGN KEY ("episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fall_events" ADD CONSTRAINT "fall_events_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "family_access_grants" ADD CONSTRAINT "family_access_grants_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "family_access_grants" ADD CONSTRAINT "family_access_grants_grantee_user_id_users_id_fk" FOREIGN KEY ("grantee_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "family_access_grants" ADD CONSTRAINT "family_access_grants_created_by_user_id_users_id_fk" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "home_visits" ADD CONSTRAINT "home_visits_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "home_visits" ADD CONSTRAINT "home_visits_service_code_home_visit_services_code_fk" FOREIGN KEY ("service_code") REFERENCES "public"."home_visit_services"("code") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "home_visits" ADD CONSTRAINT "home_visits_care_episode_id_care_episodes_id_fk" FOREIGN KEY ("care_episode_id") REFERENCES "public"."care_episodes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "home_visits" ADD CONSTRAINT "home_visits_provider_id_providers_id_fk" FOREIGN KEY ("provider_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "home_visits" ADD CONSTRAINT "home_visits_zone_id_service_zones_id_fk" FOREIGN KEY ("zone_id") REFERENCES "public"."service_zones"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "home_visits" ADD CONSTRAINT "home_visits_created_by_user_id_users_id_fk" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "knowledge_chunks" ADD CONSTRAINT "knowledge_chunks_source_id_knowledge_sources_id_fk" FOREIGN KEY ("source_id") REFERENCES "public"."knowledge_sources"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "medical_records" ADD CONSTRAINT "medical_records_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "medications" ADD CONSTRAINT "medications_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "messages" ADD CONSTRAINT "messages_conversation_id_conversations_id_fk" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mood_entries" ADD CONSTRAINT "mood_entries_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_preferences" ADD CONSTRAINT "notification_preferences_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "patients" ADD CONSTRAINT "patients_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "patients" ADD CONSTRAINT "patients_owner_user_id_users_id_fk" FOREIGN KEY ("owner_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payment_events" ADD CONSTRAINT "payment_events_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_created_by_user_id_users_id_fk" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pharmacy_orders" ADD CONSTRAINT "pharmacy_orders_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "provider_zones" ADD CONSTRAINT "provider_zones_provider_id_providers_id_fk" FOREIGN KEY ("provider_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "provider_zones" ADD CONSTRAINT "provider_zones_zone_id_service_zones_id_fk" FOREIGN KEY ("zone_id") REFERENCES "public"."service_zones"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "providers" ADD CONSTRAINT "providers_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "providers" ADD CONSTRAINT "providers_facility_id_facilities_id_fk" FOREIGN KEY ("facility_id") REFERENCES "public"."facilities"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "record_shares" ADD CONSTRAINT "record_shares_record_id_medical_records_id_fk" FOREIGN KEY ("record_id") REFERENCES "public"."medical_records"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "record_shares" ADD CONSTRAINT "record_shares_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_session_id_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."sessions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "safety_events" ADD CONSTRAINT "safety_events_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "settlement_ledger" ADD CONSTRAINT "settlement_ledger_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "slots" ADD CONSTRAINT "slots_doctor_id_providers_id_fk" FOREIGN KEY ("doctor_id") REFERENCES "public"."providers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sos_events" ADD CONSTRAINT "sos_events_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "vitals" ADD CONSTRAINT "vitals_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "wearable_connections" ADD CONSTRAINT "wearable_connections_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "wound_cases" ADD CONSTRAINT "wound_cases_patient_id_patients_id_fk" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "wound_cases" ADD CONSTRAINT "wound_cases_image_record_id_medical_records_id_fk" FOREIGN KEY ("image_record_id") REFERENCES "public"."medical_records"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "appointments_live_slot_uq" ON "appointments" USING btree ("slot_id") WHERE status <> 'cancelled';--> statement-breakpoint
CREATE INDEX "appointments_patient_idx" ON "appointments" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "appointments_doctor_idx" ON "appointments" USING btree ("doctor_id","start_at");--> statement-breakpoint
CREATE INDEX "audit_actor_idx" ON "audit_logs" USING btree ("actor_id");--> statement-breakpoint
CREATE INDEX "audit_entity_idx" ON "audit_logs" USING btree ("entity_type","entity_id");--> statement-breakpoint
CREATE INDEX "audit_created_idx" ON "audit_logs" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "episodes_patient_idx" ON "care_episodes" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "episodes_status_idx" ON "care_episodes" USING btree ("status");--> statement-breakpoint
CREATE INDEX "tasks_patient_idx" ON "care_tasks" USING btree ("patient_id","status");--> statement-breakpoint
CREATE INDEX "consents_user_idx" ON "consents" USING btree ("user_id","purpose");--> statement-breakpoint
CREATE UNIQUE INDEX "dose_logs_med_sched_uq" ON "dose_logs" USING btree ("medication_id","scheduled_at");--> statement-breakpoint
CREATE INDEX "events_episode_idx" ON "episode_events" USING btree ("episode_id","created_at");--> statement-breakpoint
CREATE INDEX "fag_grantee_idx" ON "family_access_grants" USING btree ("grantee_user_id","status");--> statement-breakpoint
CREATE INDEX "fag_patient_idx" ON "family_access_grants" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "hv_patient_idx" ON "home_visits" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "hv_provider_idx" ON "home_visits" USING btree ("provider_id");--> statement-breakpoint
CREATE INDEX "hv_status_idx" ON "home_visits" USING btree ("status");--> statement-breakpoint
CREATE UNIQUE INDEX "idempotency_uq" ON "idempotency_keys" USING btree ("user_id","key","route");--> statement-breakpoint
CREATE INDEX "records_patient_idx" ON "medical_records" USING btree ("patient_id","created_at");--> statement-breakpoint
CREATE INDEX "messages_conv_idx" ON "messages" USING btree ("conversation_id","seq");--> statement-breakpoint
CREATE INDEX "outbox_status_idx" ON "notification_outbox" USING btree ("status","next_attempt_at");--> statement-breakpoint
CREATE INDEX "notifications_user_idx" ON "notifications" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "notifications_dedupe_uq" ON "notifications" USING btree ("user_id","dedupe_key");--> statement-breakpoint
CREATE INDEX "otp_phone_idx" ON "otp_requests" USING btree ("phone","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "payments_order_uq" ON "payments" USING btree ("gateway_order_id");--> statement-breakpoint
CREATE INDEX "payments_patient_idx" ON "payments" USING btree ("patient_id");--> statement-breakpoint
CREATE INDEX "safety_events_status_idx" ON "safety_events" USING btree ("status");--> statement-breakpoint
CREATE UNIQUE INDEX "slots_doctor_start_uq" ON "slots" USING btree ("doctor_id","start_at");--> statement-breakpoint
CREATE INDEX "vitals_patient_idx" ON "vitals" USING btree ("patient_id","type","measured_at");