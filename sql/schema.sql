-- ============================================================
-- PETCOM — schema.sql
-- Identity/role layer (Phase 1) plus the Phase C.1 self-registration
-- request table, plus the catalog layer (isotopes/compounds/products/
-- delivery options), plus the order-lifecycle layer (orders, comments,
-- notes, audit log, and their lab/institute-scoped supporting tables).
-- 26 tables. InnoDB, utf8mb4. Load into an empty `petcom` database, then
-- load seed.sql.
--
-- Build order is FK-safe, not the narrative order in CLAUDE.md:
--   institutes -> labs -> pis -> lab_pis -> categories -> users
--   -> password_history -> lockout_events -> staff -> staff_categories
--   -> admins -> customers -> customer_registration_requests -> isotopes
--   -> compounds -> compound_isotopes -> products -> delivery_options
--   -> compound_delivery_options -> lab_delivery_locations
--   -> lab_product_users -> institute_catalog_access -> orders
--   -> order_public_comments -> order_internal_notes -> order_audit_log
-- (categories has to exist before staff references it, which is
-- earlier than CLAUDE.md's identity-then-menu grouping. staff has
-- to exist before admins, since every admin is also staff.
-- staff_categories sits right after staff because it FKs into both
-- staff and categories, both already built by that point.
-- customer_registration_requests comes last among the identity tables
-- since it FKs into labs, pis, and users but nothing FKs into it. The
-- six catalog tables are created next, since compounds FKs into
-- categories — which also means the DROP block above runs them in the
-- opposite spot: catalog tables are dropped before categories, since
-- compounds/products/etc. hold live FKs into categories and dropping
-- categories first would violate that constraint. The final seven
-- order-lifecycle tables are created last of all: orders depends on
-- lab_delivery_locations and lab_product_users (both new here) plus
-- customers/products/delivery_options (already built), and
-- order_public_comments/order_internal_notes/order_audit_log each
-- depend on orders itself. That dependency also means this whole batch
-- is dropped FIRST, ahead of even the catalog block, since
-- institute_catalog_access and orders hold live FKs into compounds/
-- products/delivery_options and dropping those before this batch would
-- violate that constraint.)
-- ============================================================

SET NAMES utf8mb4;

DROP TABLE IF EXISTS order_audit_log;
DROP TABLE IF EXISTS order_internal_notes;
DROP TABLE IF EXISTS order_public_comments;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS institute_catalog_access;
DROP TABLE IF EXISTS lab_product_users;
DROP TABLE IF EXISTS lab_delivery_locations;
DROP TABLE IF EXISTS compound_delivery_options;
DROP TABLE IF EXISTS delivery_options;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS compound_isotopes;
DROP TABLE IF EXISTS compounds;
DROP TABLE IF EXISTS isotopes;
DROP TABLE IF EXISTS customer_registration_requests;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS admins;
DROP TABLE IF EXISTS staff_categories;
DROP TABLE IF EXISTS staff;
DROP TABLE IF EXISTS lockout_events;
DROP TABLE IF EXISTS password_history;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS lab_pis;
DROP TABLE IF EXISTS pis;
DROP TABLE IF EXISTS labs;
DROP TABLE IF EXISTS institutes;


-- ============================================================
-- Identity
-- ============================================================

-- The five tables below (institutes, labs, pis, lab_pis,
-- categories) are provisional reference/lookup tables. Their
-- internal shape may be revised once the final order form design
-- is settled by the other team members working on that piece. The
-- identity layer (users, admins, staff, customers) is final and
-- shouldn't need to change as a result, as long as the FK
-- contract (lab_id -> labs.lab_id, category_id ->
-- categories.category_id, etc.) stays intact.

CREATE TABLE institutes (
  institute_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(255) NOT NULL,
  shorthand_name VARCHAR(10),
  active         TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_institutes_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE labs (
  lab_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  institute_id  INT UNSIGNED NOT NULL,
  lab_name      VARCHAR(100) NOT NULL,
  building      VARCHAR(50),
  room          VARCHAR(20),
  active        TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_labs_institute FOREIGN KEY (institute_id) REFERENCES institutes (institute_id),
  KEY idx_labs_institute_id (institute_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pis (
  pi_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pi_name  VARCHAR(100) NOT NULL,
  email    VARCHAR(254),
  phone    VARCHAR(20),
  active   TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Join table: a lab can have multiple PIs, a PI can oversee multiple labs.
CREATE TABLE lab_pis (
  lab_id  INT UNSIGNED NOT NULL,
  pi_id   INT UNSIGNED NOT NULL,
  PRIMARY KEY (lab_id, pi_id),
  CONSTRAINT fk_lab_pis_lab FOREIGN KEY (lab_id) REFERENCES labs (lab_id) ON DELETE CASCADE,
  CONSTRAINT fk_lab_pis_pi  FOREIGN KEY (pi_id)  REFERENCES pis (pi_id)   ON DELETE CASCADE,
  KEY idx_lab_pis_pi_id (pi_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Categories built here (not with the rest of the menu tables below)
-- because staff_categories.category_id needs it to already exist.
CREATE TABLE categories (
  category_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  category_name VARCHAR(50) NOT NULL,
  UNIQUE KEY uq_categories_name (category_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Shared login table for all three roles. Role is determined by which
-- of admins/staff/customers a user_id appears in — no role column here.
-- first_name/last_name/phone live here, not duplicated per-role table --
-- every role needs a name, and a phone number is just as plausible for
-- staff/admins as for customers. username is already the NIH email
-- address (see seed.sql's own convention note) — no separate email
-- column is added here; it would just duplicate username.
CREATE TABLE users (
  user_id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username              VARCHAR(50) NOT NULL,
  password_hash         VARCHAR(255) NOT NULL,
  first_name            VARCHAR(100) NOT NULL,
  last_name             VARCHAR(100) NOT NULL,
  phone                 VARCHAR(20) NULL,
  must_change_password  TINYINT(1) NOT NULL DEFAULT 1,
  failed_login_count    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until          DATETIME NULL,
  active                TINYINT(1) NOT NULL DEFAULT 1,
  created_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Stores the outgoing password hash each time a user changes their
-- password, so change_password.php can block reuse of the last 5
-- passwords (current users.password_hash + the 4 rows kept here).
-- Pruned to the 4 most recent rows per user on every insert — no
-- reason to retain old hashes past what the policy needs.
CREATE TABLE password_history (
  history_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id       INT UNSIGNED NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  changed_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_password_history_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  KEY idx_password_history_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Records a lockout event each time a login attempt pushes
-- failed_login_count past FAILED_LOGIN_LOCKOUT_THRESHOLD and
-- locked_until gets set. Narrower than the Phase F audit log system —
-- just who/when/how many attempts. No admin UI to view these yet.
CREATE TABLE lockout_events (
  lockout_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id          INT UNSIGNED NOT NULL,
  failed_attempts  TINYINT UNSIGNED NOT NULL,
  locked_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_lockout_events_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  KEY idx_lockout_events_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Category assignment lives in staff_categories below, not a column
-- here — a staff member can be assigned to more than one processing
-- category. (Corrected from an earlier one-category-per-staff design;
-- confirmed many-to-many by Kris directly before this ever shipped.)
-- first_name/last_name/phone live on users now, not duplicated here --
-- every staff row is also a users row (fk_staff_user below), so name/
-- phone are always reachable through that FK.
CREATE TABLE staff (
  user_id     INT UNSIGNED PRIMARY KEY,
  CONSTRAINT fk_staff_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Many-to-many by design: a staff member can be assigned to more than
-- one processing category. Corrected from an earlier
-- single-category_id-per-staff design before it shipped — confirmed
-- many-to-many by Kris directly.
CREATE TABLE staff_categories (
  user_id     INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, category_id),
  CONSTRAINT fk_staff_categories_staff    FOREIGN KEY (user_id)     REFERENCES staff (user_id)         ON DELETE CASCADE,
  CONSTRAINT fk_staff_categories_category FOREIGN KEY (category_id) REFERENCES categories (category_id) ON DELETE CASCADE,
  KEY idx_staff_categories_category_id (category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Every admin is also staff (admin subset-of staff) — enforced here via FK
-- to staff, not straight to users, so an admin row can't exist without a
-- matching staff row. The app layer bypasses category restrictions for
-- admins (category membership itself now lives in staff_categories, not
-- on staff directly). Name/phone reach here the same two-hop way as
-- everything else about a person: admins.user_id -> staff.user_id ->
-- users.user_id.
CREATE TABLE admins (
  user_id INT UNSIGNED PRIMARY KEY,
  CONSTRAINT fk_admins_user FOREIGN KEY (user_id) REFERENCES staff (user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Institute is NOT stored here — always derived via
-- lab_id -> labs.institute_id, since a lab belongs to exactly one
-- institute and storing it twice risks the two facts disagreeing.
-- Lab/supervising PI are locked at approval time.
-- registration_status lives directly here — no separate requests table.
-- first_name/last_name/phone live on users now, not duplicated here --
-- every customer row is also a users row (fk_customers_user below), so
-- name/phone are always reachable through that FK. nrc_contact_* stay
-- here: they describe a different person (the NRC contact), not the
-- customer.
CREATE TABLE customers (
  user_id              INT UNSIGNED PRIMARY KEY,
  lab_id               INT UNSIGNED NULL,
  supervising_pi_id    INT UNSIGNED NULL,
  registration_status  ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
  nrc_contact_name     VARCHAR(255) NULL,
  nrc_contact_phone    VARCHAR(20) NULL,
  nrc_contact_email    VARCHAR(255) NULL,
  CONSTRAINT fk_customers_user         FOREIGN KEY (user_id)           REFERENCES users (user_id)         ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_customers_lab          FOREIGN KEY (lab_id)            REFERENCES labs (lab_id)             ON DELETE SET NULL,
  CONSTRAINT fk_customers_pi           FOREIGN KEY (supervising_pi_id) REFERENCES pis (pi_id)               ON DELETE SET NULL,
  KEY idx_customers_registration_status (registration_status),
  KEY idx_customers_lab_id (lab_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Holds a self-registration submission (Phase C.1) until an admin
-- approves or rejects it (Phase C.2). No users/customers row exists for
-- a request until it's approved — this table is fully separate from the
-- identity tables, not a staging area with FKs into them. lab_id/pi_id
-- reference the dropdowns the registrant picked from; email becomes the
-- eventual username. No DB-level uniqueness on email: MySQL/MariaDB
-- can't express "unique while status='pending'" as a plain index, and a
-- rejected request is allowed to be resubmitted — so duplicate
-- prevention is enforced at the app layer (see register.php).
CREATE TABLE customer_registration_requests (
  request_id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lab_id                 INT UNSIGNED NOT NULL,
  pi_id                  INT UNSIGNED NOT NULL,
  first_name             VARCHAR(100) NOT NULL,
  last_name              VARCHAR(100) NOT NULL,
  email                   VARCHAR(254) NOT NULL,
  phone                   VARCHAR(20) NOT NULL,
  nrc_contact_name        VARCHAR(255) NULL,
  nrc_contact_phone       VARCHAR(20) NULL,
  nrc_contact_email       VARCHAR(255) NULL,
  status                  ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
  rejection_reason        VARCHAR(500) NULL,
  reviewed_by_admin_id    INT UNSIGNED NULL,
  reviewed_at             DATETIME NULL,
  submitted_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_reg_requests_lab      FOREIGN KEY (lab_id)               REFERENCES labs (lab_id),
  CONSTRAINT fk_reg_requests_pi       FOREIGN KEY (pi_id)                REFERENCES pis (pi_id),
  CONSTRAINT fk_reg_requests_reviewer FOREIGN KEY (reviewed_by_admin_id) REFERENCES users (user_id) ON DELETE SET NULL,
  KEY idx_reg_requests_status (status),
  KEY idx_reg_requests_email (email),
  KEY idx_reg_requests_lab_id (lab_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- Catalog
-- ============================================================

CREATE TABLE isotopes (
  isotope_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(50) NOT NULL,
  active      TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_isotopes_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE compounds (
  compound_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(150) NOT NULL,
  category_id  INT UNSIGNED NOT NULL,
  active       TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_compounds_category FOREIGN KEY (category_id) REFERENCES categories (category_id),
  KEY idx_compounds_category_id (category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Join table: a compound usually pairs with one isotope but occasionally
-- allows more than one, so this is a real many-to-many join rather than
-- an isotope_id column on compounds.
CREATE TABLE compound_isotopes (
  compound_id  INT UNSIGNED NOT NULL,
  isotope_id   INT UNSIGNED NOT NULL,
  PRIMARY KEY (compound_id, isotope_id),
  CONSTRAINT fk_compound_isotopes_compound FOREIGN KEY (compound_id) REFERENCES compounds (compound_id) ON DELETE CASCADE,
  CONSTRAINT fk_compound_isotopes_isotope  FOREIGN KEY (isotope_id)  REFERENCES isotopes (isotope_id)   ON DELETE CASCADE,
  KEY idx_compound_isotopes_isotope_id (isotope_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- The orderable SKU: one compound+isotope combination, independently
-- statused per product — e.g. Radiolabeled Water can exist as both a
-- P-32 product and an H-3 product, each with its own active/inactive
-- state, rather than one active flag shared across all isotope variants
-- of a compound. (compound_id, isotope_id) is expected to match a row in
-- compound_isotopes, but that isn't enforced as a composite FK here —
-- kept as an app-layer responsibility instead, the same way
-- customer_registration_requests enforces its own pending-email
-- uniqueness at the app layer rather than in the schema. standard_cost
-- lives here rather than on compounds for the same reason active does —
-- different isotope-labeled variants of the same compound are
-- independently statused and could reasonably have different costs.
-- standard_cost is the live/current price only, free to change at any
-- time; orders.cost_snapshot is a separate, frozen-at-creation copy of
-- this value taken the moment each order is placed, so a later price
-- change here never alters historical orders or reports.
CREATE TABLE products (
  product_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  compound_id    INT UNSIGNED NOT NULL,
  isotope_id     INT UNSIGNED NOT NULL,
  sku            VARCHAR(50) NOT NULL,
  description    TEXT NULL,
  standard_cost  DECIMAL(10,2) NOT NULL,
  active         TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_products_compound FOREIGN KEY (compound_id) REFERENCES compounds (compound_id),
  CONSTRAINT fk_products_isotope  FOREIGN KEY (isotope_id)  REFERENCES isotopes (isotope_id),
  UNIQUE KEY uq_products_sku (sku),
  KEY idx_products_compound_id (compound_id),
  KEY idx_products_isotope_id (isotope_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE delivery_options (
  delivery_option_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name                VARCHAR(50) NOT NULL,
  active              TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_delivery_options_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Join table: delivery methods are per-compound, never a global list —
-- each compound lists only the delivery options it allows.
CREATE TABLE compound_delivery_options (
  compound_id         INT UNSIGNED NOT NULL,
  delivery_option_id  INT UNSIGNED NOT NULL,
  PRIMARY KEY (compound_id, delivery_option_id),
  CONSTRAINT fk_compound_delivery_options_compound FOREIGN KEY (compound_id)        REFERENCES compounds (compound_id)               ON DELETE CASCADE,
  CONSTRAINT fk_compound_delivery_options_option    FOREIGN KEY (delivery_option_id) REFERENCES delivery_options (delivery_option_id) ON DELETE CASCADE,
  KEY idx_compound_delivery_options_option_id (delivery_option_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- Orders
-- ============================================================

-- Lab-scoped, not per-customer -- multiple customers in the same lab
-- share the same delivery locations. Soft-delete via active so a
-- historical order's location_id reference survives even after the
-- location is later deactivated.
CREATE TABLE lab_delivery_locations (
  location_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lab_id       INT UNSIGNED NOT NULL,
  name         VARCHAR(100) NOT NULL,
  room         VARCHAR(20),
  active       TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_lab_delivery_locations_lab FOREIGN KEY (lab_id) REFERENCES labs (lab_id),
  KEY idx_lab_delivery_locations_lab_id (lab_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Represents the actual person who will receive/use the dose, who may
-- not be the ordering customer (e.g. Jane Doe orders on behalf of John
-- Doe, a lab member who isn't a registered system user and has no row in
-- customers). Lab-scoped for the same reason as lab_delivery_locations
-- above. Soft-delete via active so a historical order's product_user_id
-- reference survives deactivation.
CREATE TABLE lab_product_users (
  product_user_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lab_id           INT UNSIGNED NOT NULL,
  name             VARCHAR(150) NOT NULL,
  active           TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_lab_product_users_lab FOREIGN KEY (lab_id) REFERENCES labs (lab_id),
  KEY idx_lab_product_users_lab_id (lab_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Structurally limits which compounds a customer can order: a customer's
-- available compound list is always this table's rows for their own
-- institute (via customer_id -> customers.lab_id -> labs.institute_id),
-- enforced here at the DB level rather than only filtered in the UI. No
-- row for an institute+compound pair means no customer at that institute
-- can order that compound at all.
CREATE TABLE institute_catalog_access (
  institute_id  INT UNSIGNED NOT NULL,
  compound_id   INT UNSIGNED NOT NULL,
  PRIMARY KEY (institute_id, compound_id),
  CONSTRAINT fk_institute_catalog_access_institute FOREIGN KEY (institute_id) REFERENCES institutes (institute_id) ON DELETE CASCADE,
  CONSTRAINT fk_institute_catalog_access_compound  FOREIGN KEY (compound_id)  REFERENCES compounds (compound_id)  ON DELETE CASCADE,
  KEY idx_institute_catalog_access_compound_id (compound_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- One unified form for every order type -- no Type A/B split, no
-- separate per-type detail tables. Cyclotron-run specifics (beam
-- current, bombardment time, EOB activity, destination) are typed into
-- special_instructions like any other order's notes, never given
-- dedicated columns. status has no 'returned' value: a return is a
-- transition back to 'pending', recorded as a normal row in
-- order_audit_log, not a status of its own. cost_snapshot is set once at
-- creation and never recalculated if the compound's standard cost
-- changes later. order_id is a plain AUTO_INCREMENT: MySQL/MariaDB never
-- reuses an AUTO_INCREMENT value even after the owning row's status
-- becomes 'cancelled' (and this app never DELETEs orders), satisfying
-- "sequential, never reused" with no extra bookkeeping. product_user_id
-- is nullable -- NULL means the ordering customer is the recipient; a
-- row is only required when someone else is.
CREATE TABLE orders (
  order_id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id          INT UNSIGNED NOT NULL,
  product_id           INT UNSIGNED NOT NULL,
  delivery_option_id   INT UNSIGNED NOT NULL,
  location_id          INT UNSIGNED NOT NULL,
  product_user_id      INT UNSIGNED NULL,
  activity_mci         DECIMAL(8,3) NOT NULL,
  requested_datetime   DATETIME NOT NULL,
  special_instructions TEXT NULL,
  cost_snapshot        DECIMAL(10,2) NOT NULL,
  status               ENUM('pending', 'accepted', 'completed', 'cancelled') NOT NULL DEFAULT 'pending',
  created_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_customer        FOREIGN KEY (customer_id)        REFERENCES customers (user_id),
  CONSTRAINT fk_orders_product         FOREIGN KEY (product_id)         REFERENCES products (product_id),
  CONSTRAINT fk_orders_delivery_option FOREIGN KEY (delivery_option_id) REFERENCES delivery_options (delivery_option_id),
  CONSTRAINT fk_orders_location        FOREIGN KEY (location_id)        REFERENCES lab_delivery_locations (location_id),
  CONSTRAINT fk_orders_product_user    FOREIGN KEY (product_user_id)    REFERENCES lab_product_users (product_user_id),
  KEY idx_orders_customer_id (customer_id),
  KEY idx_orders_product_id (product_id),
  KEY idx_orders_delivery_option_id (delivery_option_id),
  KEY idx_orders_location_id (location_id),
  KEY idx_orders_product_user_id (product_user_id),
  KEY idx_orders_status (status),
  KEY idx_orders_requested_datetime (requested_datetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Append-only: no updated_at, no edit path implied by the schema --
-- comments are only ever appended, never modified. Visible to both
-- customers and staff (enforced at the app layer, not here).
CREATE TABLE order_public_comments (
  comment_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id        INT UNSIGNED NOT NULL,
  author_user_id  INT UNSIGNED NOT NULL,
  body            TEXT NOT NULL,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_order_public_comments_order  FOREIGN KEY (order_id)       REFERENCES orders (order_id) ON DELETE CASCADE,
  CONSTRAINT fk_order_public_comments_author FOREIGN KEY (author_user_id) REFERENCES users (user_id),
  KEY idx_order_public_comments_order_id (order_id),
  KEY idx_order_public_comments_author_user_id (author_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Same shape as order_public_comments: append-only, no updated_at.
-- Staff-only visibility is enforced at the app layer (same pattern as
-- other role-gating in this app), not by a schema-level distinction --
-- the two tables are kept structurally identical and separate so a
-- staff-only note can never end up in the customer-visible thread (or
-- vice versa) via a single shared, overwritable column.
CREATE TABLE order_internal_notes (
  note_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id        INT UNSIGNED NOT NULL,
  author_user_id  INT UNSIGNED NOT NULL,
  body            TEXT NOT NULL,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_order_internal_notes_order  FOREIGN KEY (order_id)       REFERENCES orders (order_id) ON DELETE CASCADE,
  CONSTRAINT fk_order_internal_notes_author FOREIGN KEY (author_user_id) REFERENCES users (user_id),
  KEY idx_order_internal_notes_order_id (order_id),
  KEY idx_order_internal_notes_author_user_id (author_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Status-only, not field-level diffing -- just status_from, status_to,
-- who, and when. Every order creation and every status transition writes
-- a row here, including the creation event itself (status_from NULL,
-- status_to 'pending'), atomically alongside the status change (an
-- app-layer responsibility). status_from is nullable specifically for
-- that creation-event row -- every other row has both endpoints
-- populated.
CREATE TABLE order_audit_log (
  audit_id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id           INT UNSIGNED NOT NULL,
  status_from        ENUM('pending', 'accepted', 'completed', 'cancelled') NULL,
  status_to          ENUM('pending', 'accepted', 'completed', 'cancelled') NOT NULL,
  changed_by_user_id INT UNSIGNED NOT NULL,
  changed_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_order_audit_log_order      FOREIGN KEY (order_id)           REFERENCES orders (order_id) ON DELETE CASCADE,
  CONSTRAINT fk_order_audit_log_changed_by FOREIGN KEY (changed_by_user_id) REFERENCES users (user_id),
  KEY idx_order_audit_log_order_id (order_id),
  KEY idx_order_audit_log_changed_by_user_id (changed_by_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
