-- ============================================================
-- PETCOM — seed.sql
-- Minimal test data. Load after schema.sql, into an empty
-- `petcom` database (relies on AUTO_INCREMENT starting at 1).
--
-- password_hash values are placeholders — run
-- tools/set_temp_passwords.php once to replace with real hashes.
--
-- Institutes here ARE the NIH institutes/centers (NIH Clinical
-- Center PET Department system — all customers are NIH-internal).
--
-- customers does not store institute_id directly — always
-- derived via lab_id -> labs.institute_id.
--
-- customer name is first_name + last_name (no middle_initial —
-- removed as unnecessary complexity with no real requirement
-- behind it).
--
-- Usernames follow the real convention: NIH email address.
-- ============================================================

-- ---- Institutes (6 of the ~27 real NIH institutes/centers) ----
INSERT INTO institutes (name, shorthand_name, active) VALUES
  ('Clinical Center', 'CC', 1),
  ('National Cancer Institute', 'NCI', 1),
  ('National Institute of Mental Health', 'NIMH', 1),
  ('National Heart, Lung, and Blood Institute', 'NHLBI', 1),
  ('National Institute on Aging', 'NIA', 1),
  ('National Institute of Neurological Disorders and Stroke', 'NINDS', 1);

-- ---- Labs (3) ----
INSERT INTO labs (institute_id, lab_name, building, room, active) VALUES
  (2, 'Molecular Imaging Lab', 'Bldg 10', 'B1D43', 1),      -- NCI
  (3, 'Neuroimaging Lab', 'Bldg 10', '2C401', 1),           -- NIMH
  (6, 'Cerebrovascular Imaging Lab', 'Bldg 10', 'C107', 1); -- NINDS

-- ---- PIs (2) ----
INSERT INTO pis (pi_name, email, phone, active) VALUES
  ('Dr. Susan Carter', 'susan.carter@nih.gov', '301-555-0101', 1),
  ('Dr. Mark Ellison', 'mark.ellison@nih.gov', '301-555-0199', 1);

-- ---- lab_pis (a lab can have multiple PIs, a PI can oversee multiple labs) ----
INSERT INTO lab_pis (lab_id, pi_id) VALUES
  (1, 1), -- Molecular Imaging Lab <- Dr. Carter
  (2, 1), -- Neuroimaging Lab <- Dr. Carter
  (2, 2), -- Neuroimaging Lab <- Dr. Ellison (lab with two PIs)
  (3, 2); -- Cerebrovascular Imaging Lab <- Dr. Ellison

-- ---- Categories (2) ----
INSERT INTO categories (category_name) VALUES
  ('Radiopharmacy'),
  ('Cyclotron');

-- ---- Users (7): 1 admin, 2 staff, 4 customers ----
-- Usernames are real NIH-email-style, matching Kris's requirement
-- that username = NIH email address.
INSERT INTO users (username, password_hash, must_change_password, active) VALUES
  ('robert.nguyen@nih.gov',  'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 1, 1), -- 1: admin
  ('maria.santos@nih.gov',   'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 1, 1), -- 2: staff, Radiopharmacy
  ('james.oconnor@nih.gov',  'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 1, 1), -- 3: staff, Cyclotron
  ('alice.carter@nih.gov',   'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 1, 1), -- 4: customer
  ('brian.kim@nih.gov',      'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 1, 1), -- 5: customer
  ('deepa.patel@nih.gov',    'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 1, 1), -- 6: customer
  ('evan.feng@nih.gov',      'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 1, 1); -- 7: customer (lab-mate of Alice, for lab-wide visibility testing)

-- ---- Admin (1) ----
INSERT INTO admins (user_id) VALUES (1);

-- ---- Staff (2, one per category) ----
INSERT INTO staff (user_id, category_id) VALUES
  (2, 1), -- maria.santos -> Radiopharmacy
  (3, 2); -- james.oconnor -> Cyclotron

-- ---- Customers (4, all approved) ----
INSERT INTO customers (user_id, first_name, last_name, lab_id, supervising_pi_id, registration_status, approved_by, approved_at) VALUES
  (4, 'Alice', 'Carter', 1, 1, 'approved', 1, '2026-06-01 09:00:00'), -- NCI / Molecular Imaging Lab / Dr. Carter
  (5, 'Brian', 'Kim',    2, 2, 'approved', 1, '2026-06-02 09:00:00'), -- NIMH / Neuroimaging Lab / Dr. Ellison
  (6, 'Deepa', 'Patel',  3, 2, 'approved', 1, '2026-06-03 09:00:00'), -- NINDS / Cerebrovascular Imaging Lab / Dr. Ellison
  (7, 'Evan',  'Feng',   1, 1, 'approved', 1, '2026-06-04 09:00:00'); -- NCI / Molecular Imaging Lab / Dr. Carter (lab-mate of Alice)