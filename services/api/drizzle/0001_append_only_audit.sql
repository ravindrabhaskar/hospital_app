-- Append-only enforcement for the audit log and care-episode event history.
-- UPDATE / DELETE on these tables is rejected at the database level.
CREATE OR REPLACE FUNCTION cc_reject_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'table % is append-only', TG_TABLE_NAME USING ERRCODE = 'insufficient_privilege';
END;
$$ LANGUAGE plpgsql;
--> statement-breakpoint
CREATE TRIGGER audit_logs_append_only BEFORE UPDATE OR DELETE ON "audit_logs" FOR EACH ROW EXECUTE FUNCTION cc_reject_mutation();
--> statement-breakpoint
CREATE TRIGGER episode_events_append_only BEFORE UPDATE OR DELETE ON "episode_events" FOR EACH ROW EXECUTE FUNCTION cc_reject_mutation();
