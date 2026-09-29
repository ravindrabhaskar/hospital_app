-- v1.3 reference data (contract sections 51 and 53). Idempotent: safe on databases that already contain the rows.
INSERT INTO "home_visit_services" ("code", "name", "description", "price", "duration_mins", "icon") VALUES
  ('physiotherapy', 'Physiotherapy at home', 'A physiotherapist assesses mobility and teaches a home exercise program.', 699, 45, 'activity')
ON CONFLICT ("code") DO NOTHING;
--> statement-breakpoint
INSERT INTO "insurers" ("code", "name", "type") VALUES
  ('star_health', 'Star Health and Allied Insurance', 'private'),
  ('hdfc_ergo', 'HDFC ERGO General Insurance', 'private'),
  ('icici_lombard', 'ICICI Lombard General Insurance', 'private'),
  ('niva_bupa', 'Niva Bupa Health Insurance', 'private'),
  ('care_health', 'Care Health Insurance', 'private'),
  ('aditya_birla', 'Aditya Birla Health Insurance', 'private'),
  ('bajaj_allianz', 'Bajaj Allianz General Insurance', 'private'),
  ('new_india', 'The New India Assurance', 'public'),
  ('united_india', 'United India Insurance', 'public'),
  ('oriental', 'The Oriental Insurance Company', 'public'),
  ('national', 'National Insurance Company', 'public'),
  ('pmjay', 'Ayushman Bharat PM-JAY', 'government'),
  ('cghs', 'Central Government Health Scheme (CGHS)', 'government'),
  ('aarogyasri', 'Aarogyasri (Telangana)', 'government')
ON CONFLICT ("code") DO NOTHING;
