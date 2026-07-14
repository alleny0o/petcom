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

-- ---- Institutes (all 27 real NIH institutes/centers) ----
-- ids 1-6 are the original seed set (referenced by lab_id below via
-- their institute_id, so their order/ids are left unchanged); ids 7-27
-- are the rest of the real NIH ICs, appended rather than interleaved.
INSERT INTO institutes (name, shorthand_name, active) VALUES
  ('Clinical Center', 'CC', 1),
  ('National Cancer Institute', 'NCI', 1),
  ('National Institute of Mental Health', 'NIMH', 1),
  ('National Heart, Lung, and Blood Institute', 'NHLBI', 1),
  ('National Institute on Aging', 'NIA', 1),
  ('National Institute of Neurological Disorders and Stroke', 'NINDS', 1),
  ('National Eye Institute', 'NEI', 1),
  ('National Human Genome Research Institute', 'NHGRI', 1),
  ('National Institute on Alcohol Abuse and Alcoholism', 'NIAAA', 1),
  ('National Institute of Allergy and Infectious Diseases', 'NIAID', 1),
  ('National Institute of Arthritis and Musculoskeletal and Skin Diseases', 'NIAMS', 1),
  ('National Institute of Biomedical Imaging and Bioengineering', 'NIBIB', 1),
  ('Eunice Kennedy Shriver National Institute of Child Health and Human Development', 'NICHD', 1),
  ('National Institute on Deafness and Other Communication Disorders', 'NIDCD', 1),
  ('National Institute of Dental and Craniofacial Research', 'NIDCR', 1),
  ('National Institute of Diabetes and Digestive and Kidney Diseases', 'NIDDK', 1),
  ('National Institute on Drug Abuse', 'NIDA', 1),
  ('National Institute of Environmental Health Sciences', 'NIEHS', 1),
  ('National Institute of General Medical Sciences', 'NIGMS', 1),
  ('National Institute on Minority Health and Health Disparities', 'NIMHD', 1),
  ('National Institute of Nursing Research', 'NINR', 1),
  ('National Library of Medicine', 'NLM', 1),
  ('National Center for Advancing Translational Sciences', 'NCATS', 1),
  ('National Center for Complementary and Integrative Health', 'NCCIH', 1),
  ('Center for Information Technology', 'CIT', 1),
  ('Center for Scientific Review', 'CSR', 1),
  ('Fogarty International Center', 'FIC', 1);

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

-- ---- Categories (3) ----
-- Administration exists solely so the seeded admin's staff_categories row
-- can carry a real (if cosmetic) category -- the app requires every staff
-- member to have at least one category and always assigns this one for
-- admins (nothing in the DB enforces either). The app bypasses category
-- restrictions for admins.
INSERT INTO categories (category_name) VALUES
  ('Radiopharmacy'),
  ('Cyclotron'),
  ('Administration');

-- ---- Users (7): 1 admin, 2 staff, 4 customers ----
-- Usernames are real NIH-email-style, matching Kris's requirement
-- that username = NIH email address.
-- first_name/last_name/phone live on users now (moved off staff/customers)
-- -- phone stays NULL/omitted for all 7 seeded people, matching how no
-- seeded customer set a phone value before this move either.
INSERT INTO users (username, password_hash, first_name, last_name, must_change_password, active) VALUES
  ('robert.nguyen@nih.gov',  'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 'Robert', 'Nguyen',   1, 1), -- 1: admin
  ('maria.santos@nih.gov',   'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 'Maria',  'Santos',   1, 1), -- 2: staff, Radiopharmacy
  ('james.oconnor@nih.gov',  'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 'James',  'O''Connor', 1, 1), -- 3: staff, Cyclotron
  ('alice.carter@nih.gov',   'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 'Alice',  'Carter',   1, 1), -- 4: customer
  ('brian.kim@nih.gov',      'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 'Brian',  'Kim',      1, 1), -- 5: customer
  ('deepa.patel@nih.gov',    'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 'Deepa',  'Patel',    1, 1), -- 6: customer
  ('evan.feng@nih.gov',      'PLACEHOLDER_HASH_SET_BY_TOOLS_SET_TEMP_PASSWORDS', 'Evan',   'Feng',     1, 1); -- 7: customer (lab-mate of Alice, for lab-wide visibility testing)

-- ---- Staff (3) ----
-- Must be inserted before admins: admins.user_id now FKs to staff.user_id
-- (every admin is also staff), so the admin's staff row has to exist first.
INSERT INTO staff (user_id) VALUES
  (1),
  (2),
  (3);

-- ---- staff_categories (one row per seeded staff member's category) ----
-- Must be inserted after staff (FKs into it above).
INSERT INTO staff_categories (user_id, category_id) VALUES
  (1, 3), -- robert.nguyen -> Administration (admin; category is cosmetic)
  (2, 1), -- maria.santos -> Radiopharmacy
  (3, 2); -- james.oconnor -> Cyclotron

-- ---- Admin (1) ----
-- References the staff row above.
INSERT INTO admins (user_id) VALUES (1);

-- ---- Customers (4, all approved) ----
INSERT INTO customers (user_id, lab_id, supervising_pi_id, registration_status) VALUES
  (4, 1, 1, 'approved'), -- Alice Carter, NCI / Molecular Imaging Lab / Dr. Carter
  (5, 2, 2, 'approved'), -- Brian Kim, NIMH / Neuroimaging Lab / Dr. Ellison
  (6, 3, 2, 'approved'), -- Deepa Patel, NINDS / Cerebrovascular Imaging Lab / Dr. Ellison
  (7, 1, 1, 'approved'); -- Evan Feng, NCI / Molecular Imaging Lab / Dr. Carter (lab-mate of Alice)

-- ---- Isotopes (5) ----
INSERT INTO isotopes (name, active) VALUES
  ('C-11', 1),
  ('F-18', 1),
  ('Ga-68', 1),
  ('Zr-89', 1),
  ('Y-86', 1);

-- ---- Compounds (9) ----
-- category_id: 2 = Cyclotron (target-delivery C-11 compounds, processed
-- by James/Cyclotron staff), 1 = Radiopharmacy (everything
-- pharmacy/pickup-delivered, processed by Maria/Radiopharmacy staff).
-- Real department list from a July 2026 meeting, explicitly flagged
-- there as incomplete -- category assignment above is this seed's own
-- judgment call, not something the meeting notes specified.
INSERT INTO compounds (name, category_id, active) VALUES
  ('[C11]CO2', 2, 1),          -- 1
  ('[C11]Methane', 2, 1),      -- 2
  ('[F18]FDG', 1, 1),          -- 3
  ('[F18]F-Dopa', 1, 1),       -- 4
  ('[F18]F-Dopamine', 1, 1),   -- 5
  ('[Ga68]Ga Dotatate', 1, 1), -- 6
  ('[Zr89]Zr Oxalate', 1, 1),  -- 7
  ('[Zr89]Zr Chloride', 1, 1), -- 8
  ('[Y86]Y Solution', 1, 1);   -- 9

-- ---- compound_isotopes (9, one per compound) ----
-- Every Option A compound name already bundles its isotope (e.g.
-- "[C11]CO2"), so each pairing here is a trivial 1:1 -- this seed data
-- doesn't exercise the many-to-many case the join table supports (see
-- the compounds table's own header comment for that scenario).
INSERT INTO compound_isotopes (compound_id, isotope_id) VALUES
  (1, 1), -- [C11]CO2 <- C-11
  (2, 1), -- [C11]Methane <- C-11
  (3, 2), -- [F18]FDG <- F-18
  (4, 2), -- [F18]F-Dopa <- F-18
  (5, 2), -- [F18]F-Dopamine <- F-18
  (6, 3), -- [Ga68]Ga Dotatate <- Ga-68
  (7, 4), -- [Zr89]Zr Oxalate <- Zr-89
  (8, 4), -- [Zr89]Zr Chloride <- Zr-89
  (9, 5); -- [Y86]Y Solution <- Y-86

-- ---- Products (9) ----
-- standard_cost values are placeholder prices for seed/testing purposes
-- only -- no real department pricing is available yet.
INSERT INTO products (compound_id, isotope_id, sku, description, standard_cost, active) VALUES
  (1, 1, 'C11-CO2',       NULL, 85.00,  1), -- 1: placeholder price
  (2, 1, 'C11-CH4',       NULL, 95.00,  1), -- 2: placeholder price
  (3, 2, 'F18-FDG',       NULL, 150.00, 1), -- 3: placeholder price
  (4, 2, 'F18-FDOPA',     NULL, 210.00, 1), -- 4: placeholder price
  (5, 2, 'F18-DOPAMINE',  NULL, 225.00, 1), -- 5: placeholder price
  (6, 3, 'GA68-DOTATATE', NULL, 310.00, 1), -- 6: placeholder price
  (7, 4, 'ZR89-OXALATE',  NULL, 180.00, 1), -- 7: placeholder price
  (8, 4, 'ZR89-CHLORIDE', NULL, 175.00, 1), -- 8: placeholder price
  (9, 5, 'Y86-SOLUTION',  NULL, 260.00, 1); -- 9: placeholder price

-- ---- Delivery options (3, matching Option A's three methods) ----
INSERT INTO delivery_options (name, active) VALUES
  ('Target Delivery', 1), -- 1
  ('Pharmacy', 1),        -- 2
  ('Pickup', 1);          -- 3

-- ---- compound_delivery_options (9, one per compound) ----
INSERT INTO compound_delivery_options (compound_id, delivery_option_id) VALUES
  (1, 1), -- [C11]CO2 -> Target Delivery
  (2, 1), -- [C11]Methane -> Target Delivery
  (3, 2), -- [F18]FDG -> Pharmacy
  (4, 2), -- [F18]F-Dopa -> Pharmacy
  (5, 2), -- [F18]F-Dopamine -> Pharmacy
  (6, 2), -- [Ga68]Ga Dotatate -> Pharmacy
  (7, 3), -- [Zr89]Zr Oxalate -> Pickup
  (8, 3), -- [Zr89]Zr Chloride -> Pickup
  (9, 3); -- [Y86]Y Solution -> Pickup

-- ---- lab_delivery_locations (4) ----
-- Lab 1 gets two locations to show a lab can have more than one.
INSERT INTO lab_delivery_locations (lab_id, name, room, active) VALUES
  (1, 'Molecular Imaging Lab - Injection Suite', 'B1D43-A', 1), -- 1
  (1, 'Molecular Imaging Lab - Loading Dock', 'B1D40', 1),      -- 2
  (2, 'Neuroimaging Lab - Delivery Bay', '2C401', 1),           -- 3
  (3, 'Cerebrovascular Imaging Lab - Front Desk', 'C107', 1);   -- 4

-- ---- lab_product_users (2) ----
-- Unregistered lab members who can be the actual dose recipient on an
-- order placed by someone else in their lab. Only Tom Reyes is
-- referenced by a seeded order; Priya Nair is here for future testing.
INSERT INTO lab_product_users (lab_id, name, active) VALUES
  (1, 'Tom Reyes', 1),  -- 1: Molecular Imaging Lab
  (2, 'Priya Nair', 1); -- 2: Neuroimaging Lab

-- ---- institute_catalog_access (10) ----
-- Demonstrates real restriction: no institute gets every compound, and
-- several compounds are intentionally withheld from a given institute
-- (see the plan's grants table for the full breakdown).
INSERT INTO institute_catalog_access (institute_id, compound_id) VALUES
  (2, 3), -- NCI <- [F18]FDG
  (2, 4), -- NCI <- [F18]F-Dopa
  (2, 6), -- NCI <- [Ga68]Ga Dotatate
  (2, 7), -- NCI <- [Zr89]Zr Oxalate
  (3, 3), -- NIMH <- [F18]FDG
  (3, 4), -- NIMH <- [F18]F-Dopa
  (3, 5), -- NIMH <- [F18]F-Dopamine
  (6, 1), -- NINDS <- [C11]CO2
  (6, 2), -- NINDS <- [C11]Methane
  (6, 3); -- NINDS <- [F18]FDG

-- ---- Orders (10, spanning pending/accepted/completed/cancelled + a return) ----
INSERT INTO orders (customer_id, product_id, delivery_option_id, location_id, product_user_id, activity_mci, requested_datetime, special_instructions, cost_snapshot, status, created_at, updated_at) VALUES
  (4, 3, 2, 1, NULL, 10.000, '2026-07-15 09:30:00', NULL, 150.00, 'pending', '2026-07-10 14:22:00', '2026-07-10 14:22:00'), -- 1: Alice / FDG / pending
  (7, 6, 2, 1, NULL, 5.500, '2026-07-16 08:00:00', NULL, 310.00, 'pending', '2026-07-11 09:15:00', '2026-07-11 09:15:00'), -- 2: Evan / Ga Dotatate / pending
  (5, 4, 2, 3, NULL, 8.750, '2026-07-14 13:00:00', NULL, 210.00, 'accepted', '2026-07-08 10:00:00', '2026-07-09 11:30:00'), -- 3: Brian / F-Dopa / accepted
  (6, 1, 1, 4, NULL, 15.000, '2026-07-12 07:45:00', 'Beam current 40 uA, bombardment time 20 min, EOB activity approx 18 Ci. Please deliver directly to the cyclotron target line at Bldg 10 C107 loading dock.', 85.00, 'accepted', '2026-07-07 08:00:00', '2026-07-07 16:00:00'), -- 4: Deepa / CO2 / accepted / cyclotron notes
  (4, 7, 3, 1, 1, 3.200, '2026-07-05 10:00:00', NULL, 180.00, 'completed', '2026-06-28 09:00:00', '2026-07-05 15:00:00'), -- 5: Alice / Zr Oxalate / completed / product_user Tom Reyes
  (7, 3, 2, 1, NULL, 12.000, '2026-07-02 09:00:00', NULL, 150.00, 'completed', '2026-06-25 08:30:00', '2026-07-02 14:00:00'), -- 6: Evan / FDG / completed
  (5, 5, 2, 3, NULL, 9.400, '2026-06-20 11:00:00', NULL, 225.00, 'cancelled', '2026-06-15 09:00:00', '2026-06-16 10:00:00'), -- 7: Brian / F-Dopamine / cancelled
  (6, 2, 1, 4, NULL, 6.800, '2026-07-18 08:00:00', 'Bombardment approx 25 min at 35 uA, EOB activity approx 12 Ci. Please have ready for direct pickup at the cyclotron target station.', 95.00, 'pending', '2026-07-13 10:00:00', '2026-07-13 10:00:00'), -- 8: Deepa / Methane / pending / cyclotron notes
  (4, 4, 2, 1, NULL, 7.500, '2026-06-10 09:00:00', NULL, 210.00, 'completed', '2026-06-05 08:00:00', '2026-06-10 13:00:00'), -- 9: Alice / F-Dopa / completed
  (4, 6, 2, 1, NULL, 4.900, '2026-06-01 09:00:00', NULL, 310.00, 'pending', '2026-05-25 08:00:00', '2026-06-02 10:00:00'); -- 10: Alice / Ga Dotatate / returned to pending

-- ---- order_public_comments (3, on orders 3 and 4) ----
INSERT INTO order_public_comments (order_id, author_user_id, body, created_at) VALUES
  (4, 6, 'Please note we need this ready by 8am sharp for the imaging session -- let me know if the timing works.', '2026-07-07 08:05:00'),
  (4, 3, 'Confirmed -- target run scheduled for 7:15am, will have it at the loading dock by 8am.', '2026-07-07 09:00:00'),
  (3, 5, 'Can we increase the activity slightly for this run? Let me know if that''s possible.', '2026-07-08 10:30:00');

-- ---- order_internal_notes (2, staff-only, on order 4) ----
INSERT INTO order_internal_notes (order_id, author_user_id, body, created_at) VALUES
  (4, 3, 'Customer''s lab has had delivery timing issues before -- double-check the route before EOB.', '2026-07-07 08:10:00'),
  (4, 2, 'Cross-checked with the cyclotron schedule, no conflicts this week.', '2026-07-07 12:00:00');

-- ---- order_audit_log (22 rows) ----
-- Every order has at least its creation row (status_from NULL). Orders
-- 3/4/7 get a second row for their one transition; 5/6/9 get a third for
-- completion; order 10 gets a fourth row demonstrating the return rule:
-- completed -> pending, with no separate 'returned' status value used.
INSERT INTO order_audit_log (order_id, status_from, status_to, changed_by_user_id, changed_at) VALUES
  (1, NULL, 'pending', 4, '2026-07-10 14:22:00'),
  (2, NULL, 'pending', 7, '2026-07-11 09:15:00'),
  (3, NULL, 'pending', 5, '2026-07-08 10:00:00'),
  (3, 'pending', 'accepted', 2, '2026-07-09 11:30:00'),
  (4, NULL, 'pending', 6, '2026-07-07 08:00:00'),
  (4, 'pending', 'accepted', 3, '2026-07-07 16:00:00'),
  (5, NULL, 'pending', 4, '2026-06-28 09:00:00'),
  (5, 'pending', 'accepted', 2, '2026-06-29 10:00:00'),
  (5, 'accepted', 'completed', 2, '2026-07-05 15:00:00'),
  (6, NULL, 'pending', 7, '2026-06-25 08:30:00'),
  (6, 'pending', 'accepted', 2, '2026-06-26 09:00:00'),
  (6, 'accepted', 'completed', 2, '2026-07-02 14:00:00'),
  (7, NULL, 'pending', 5, '2026-06-15 09:00:00'),
  (7, 'pending', 'cancelled', 5, '2026-06-16 10:00:00'),
  (8, NULL, 'pending', 6, '2026-07-13 10:00:00'),
  (9, NULL, 'pending', 4, '2026-06-05 08:00:00'),
  (9, 'pending', 'accepted', 2, '2026-06-06 09:00:00'),
  (9, 'accepted', 'completed', 2, '2026-06-10 13:00:00'),
  (10, NULL, 'pending', 4, '2026-05-25 08:00:00'),
  (10, 'pending', 'accepted', 2, '2026-05-26 09:00:00'),
  (10, 'accepted', 'completed', 2, '2026-05-30 15:00:00'),
  (10, 'completed', 'pending', 2, '2026-06-02 10:00:00');
