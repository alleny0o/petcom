# CLAUDE.md

Guidance for Claude Code when working on PETCOM.

## Stack

- **PHP 7.4** (RHEL 8 compatible)
- **MySQL 8.0 / MariaDB 10.11** (wire-compatible via PDO)
- **PDO** with prepared statements (no ORM, no framework)
- **Vanilla CSS** (system fonts only, no external dependencies)
- **Vanilla JavaScript** (no framework, minimal)
- **No Composer, no npm, no external packages**

## Local Dev Setup

1. Create `petcom` database and load `sql/schema.sql`, then `sql/seed.sql`
2. Copy `src/config.sample.php` → `src/config.php` and fill in your DB credentials
3. Run `tools/set_temp_passwords.php` once to set temp passwords for seeded accounts
4. Point Apache document root at `public/`
5. Log in at `/login.php`

**MAMP on Mac:** DB port is `8889`. Set `REQUIRE_SECURE_COOKIES = false` locally, `true` on RHEL (HTTPS only).

## Directory Layout

```
petcom/
  public/              # Only web-reachable folder (Apache doc root)
    index.php
    login.php
    register.php
    logout.php
    change_password.php
    customer/
    staff/
    admin/
      dashboard.php
      registrations.php
      customers.php
      customer_detail.php
      accounts.php         (D.2: unified staff+admin list)
      account_detail.php   (D.2: view/edit category/deactivate/reset password)
      account_create.php   (D.2: create a staff or admin account)
      catalog.php           (catalog config: isotopes/compounds/SKUs, filter bar, add product)
    assets/
      css/
        style.css        (tokens + base/reset + typography + accessibility)
        layout/
          shell.css       (app-shell grid, header/main/footer bindings)
          sidebar.css     (sidebar: collapse, submenu, flyout, mobile off-canvas)
        components/
          auth.css
          page-structure.css   (page header, cards, detail-list)
          forms.css
          buttons.css
          tables.css
          alerts.css            (incl. temp-password banner)
          badges.css
          utilities.css
          toasts.css
          modals.css
          feedback.css          (spinners, empty states)
          dashboard.css         (stat tiles, panel grid, masonry)
          radio-cards.css
          order-page.css        (baseline for Phase E)
      js/
        script.js        (single file, no bundler — sidebar collapse +
                          mobile off-canvas toggle, toasts, confirm modals,
                          form-submit loading, copy-to-clipboard; one
                          DOMContentLoaded init block)

  src/                 # Above web root — never servable by URL
    config.php          (DB credentials, gitignored)
    config.sample.php   (template)
    db.php              (PDO connection)
    auth.php            (login, require_role(), session guard)
    helpers.php          (session bootstrap, CSRF, escaping, redirects,
                          toast_flash, field_error/field_class)
    partials/
      head.php
      layout_customer.php
      layout_staff.php
      layout_admin.php

  sql/
    schema.sql          (see Database section below)
    seed.sql            (test data)

  tools/
    set_temp_passwords.php (one-time setup for seeded accounts)
```

No `docs/` folder yet — `DEPLOY.md` is expected to show up as part of the deployment-polish phase; nothing currently reads a `SCHEMA.md`, and it isn't committed anywhere yet either.

## Database

See `sql/schema.sql` for exact columns/constraints — this is just a map of what
exists and where things stand, not a full spec.

**Identity — built:** `institutes`, `labs`, `pis`, `lab_pis`, `users`,
`password_history`, `lockout_events`, `customers`, `customer_registration_requests`,
`staff`, `admins`. `staff` does not hold a category directly — category
assignment is many-to-many via `staff_categories`, not a single `category_id`
(corrected from an earlier one-category-per-staff design before it shipped).

**Catalog — built on `main`, running on Xiaofan's schema (`origin/catalog`):**
`categories`, `staff_categories` (join), `isotopes`, `compounds`, and
products/SKUs (compound × isotope variant, independently statused). Not yet
built: `delivery_options`, `compound_delivery_options`. Exact column/table
names haven't been re-verified against this file — confirm against
`sql/schema.sql` before writing migrations. Still open: sync with Xiaofan/Kris
to confirm the seeded isotope/compound list is the long-term list.

**Orders — designed and validated in a prior build, not yet on `main`, to be
rebuilt against the current catalog schema:** `orders`, `order_public_comments`
(append-only), `order_internal_notes` (append-only, staff-only),
`order_audit_log` (status-only, not field-level diffing). One unified order
form for every order type — no Type A/B split, no separate detail tables.
Cyclotron-run specifics (beam current, bombardment time, EOB activity,
destination) go in the free-text special instructions field like any other
order note. Also to be rebuilt: an institute-scoped catalog access join table
(enforced at DB level, not just UI), and lab-scoped (not per-customer)
delivery locations/product users with soft-delete via an `active` flag.

## Business Rules (Non-Negotiable)

These came from the requirements interview. Don't simplify them.

- **No phone-in orders.** Customers place their own orders only. No `is_phone_in` field, no attestation.
- **Self-registration lands in `customer_registration_requests`, not `customers`.** A public registration submission (Phase C.1) creates a row in that separate table (`status`: pending/approved/rejected) — no `users` or `customers` row exists until an admin approves the request (Phase C.2), at which point the account and temp password get created. `customers.registration_status`/`approved_by`/`approved_at` predate this design and are unused by the current registration flow.
- **There is one order form for all order types.** Cyclotron target requests use the same form as any other order; their run-specific details (beam current, bombardment time, EOB activity, destination) go in the special instructions text field rather than dedicated structured columns or a separate detail table. Do not build or maintain a second order-detail table.
- **Completed orders are terminal.** No edits, no cancels after `status = completed`. This is enforced as a hard guard in the status-transition function itself, not just hidden in the UI.
- **Returned orders go back to `pending`.** No separate "returned" status — the audit log preserves that a return happened. A return can re-open a completed or cancelled order.
- **Cost is snapshotted.** `orders.cost_snapshot` is set at creation time. If a compound's standard cost changes later, historical orders/reports are unaffected.
- **Isotope first, then compound.** Customer picks isotope, then sees only compatible compounds — not the reverse.
- **Delivery options are per-compound.** Each compound lists its own allowed delivery methods, not a global list.
- **Audit log is status-only.** Not field-level diffing — just status_from, status_to, timestamp, who. Every transition, including order creation, writes an audit log entry automatically and atomically alongside the status change.
- **Comments are append-only threads.** Public (customer + staff) and internal (staff-only) are separate tables, never a single overwritable field.
- **Staff process orders by category, many-to-many.** A staff member can be assigned to more than one processing category via the `staff_categories` join table — not a single `category_id` on `staff`.
- **No per-order/per-period quantity limits.** Staff can adjust freely during processing.
- **No email from the app, ever.** Admins relay approvals/resets via NIH's internal email manually. No SMTP, no mail-sending code.
- **Session timeout: 15 minutes idle.** Lockout: 5 failed login attempts → 15-minute lockout.
- **Order IDs are sequential, never reused**, even for canceled orders.
- **Deactivating a customer never hides historical orders.** Pending orders at deactivation are left alone for staff to handle manually — never auto-canceled.
- **Admin can trigger password resets but never views or sets the actual password.** Reset generates a one-time temp password that forces a change + strength check on next login.
- **Order search must cover** ID, compound, isotope, date, and customer/lab/PI/institute.

## Roles

| Role | Access |
|------|--------|
| `customer` | Place orders, view own lab's orders, add public comments, cancel own pending orders |
| `staff` | Process orders in any of their assigned categories (many-to-many), accept/modify/complete/cancel/return, add public comments + internal notes |
| `admin` | Everything staff can do, plus manage compounds/categories/isotopes/delivery options/customers/staff/institutes, run reports, approve registrations |

Role is determined by which table a `user_id` appears in (`customers`, `staff`, `admins`) — `users` itself has no role column.

## CSS Architecture

- **style.css:** System fonts (`-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`), reset, design tokens (colors + status text/tint pairs, spacing, radii `--radius-sm/md/lg/full`, shadows `--shadow-xs…lg`), typography, accessibility (`:focus-visible`, `prefers-reduced-motion`, `.sr-only`)
- **layout/shell.css:** App-shell grid, header/main/footer chrome bindings
- **layout/sidebar.css:** Sidebar (sticky, collapse on desktop, off-canvas on mobile), topbar, dark mode hooks
- **components/:** One file per concern — auth, page-structure (page header + cards + detail list), forms, buttons, tables, alerts (incl. temp-password banner), badges, utilities, toasts, modals, feedback (spinners + empty states), dashboard (stat tiles + masonry), radio-cards, order-page

**No role-specific CSS files.** All three roles share the same component library.

**UI feedback conventions (post-D.2 overhaul):**
- Transient success → toast via `toast_flash($type, $message)` (helpers.php); pages re-render on POST (no PRG), so the helper emits a DOMContentLoaded `showToast()` call
- Errors/warnings → inline `.alert--error/--warning` banners; per-field validation → `field_class()` on the `.field` wrapper + `field_error()` below the input
- Destructive/irreversible actions → `data-confirm` / `data-confirm-title` / `data-confirm-verb` / `data-confirm-danger` attributes on the form; script.js intercepts submit and shows a custom modal (never `window.confirm`)
- Temp-password reveals → `.temp-password-banner` with a `data-copy-target` Copy button; never a toast
- Status language: pill badges with a leading dot (`.badge--active/pending/approved/rejected/…`); role chips are square (`.badge--role-admin/staff`)
- Submit buttons get a spinner + double-submit guard automatically from script.js — no per-form wiring needed
- Military time (24-hour HH:MM) for any order date/time field is enforced as a pattern-validated text input, never a native time picker — this guarantees no AM/PM UI ever appears, including on mobile. This is a real department requirement, not a style choice.

**Dark mode:** Not implemented right now. Tokens may exist in CSS for future use but no toggle is wired up.

**Sidebar collapse (desktop only):** Pre-paint script reads `localStorage['petcom:sidebar']` and sets `data-sidebar="collapsed"` on `<html>`. CSS changes `--sidebar-width`. Mobile sidebar (off-canvas) uses `data-sidebar-mobile="open"` on `<html>` instead — a separate, independent state.

## Git Workflow

Branch → PR → merge. Never push directly to `main`.

## Deployment Target

- **RHEL 8** (PHP 7.4, MariaDB 10.11)
- **No root access.** Hand off as a package: schema file + app files + config template + deployment doc.
- **HTTPS with self-signed cert locally; real cert on RHEL (handed off by IT).**
- **No external CDN.** All assets (CSS, JS, icons) inlined or local.

## Build Phases

PETCOM is built in lettered phases (A–F); the detailed phase/sub-phase plan is
tracked outside this file, not here — this section is intentionally just a
high-level status marker so it doesn't need editing every time a sub-phase
ships.

Current status: **A, B, and C are complete. D.1 (customer management) and D.2
(staff/admin account management) are done; D.3 (institute/lab/PI CRUD) has not
started.** Catalog management (admin-facing, `/admin/catalog.php`) is live on
`main`, running on the current catalog schema. The order-lifecycle system
(unified order form, staff order processing, audit logging — corresponding to
what this file calls Phase E/F work) was designed and built once already
against a prior catalog schema and is being rebuilt against the current one;
it is not yet present on `main`. Next up, in order: (1) confirm catalog
schema/seed data with Xiaofan/Kris and finish any remaining schema/seed
changes, (2) customer dashboard incl. the unified order form, (3) staff
dashboard incl. order processing queue and audit logging.

## Verification Policy

Claude Code must NOT start background servers, spin up scratch/temp MySQL 
instances, or run live HTTP verification (curl, PHP built-in server, etc.) 
as part of any task, even for 'verification' purposes. This includes 
resetting temp passwords or modifying any database, scratch or otherwise, 
without explicit instruction.

Verification must be limited to: php -l (syntax check), static code 
review/diffs, and grep-based checks (e.g. confirming no leftover references 
after a rename). The user will handle all live browser-based testing 
themselves, manually, in their own MAMP environment. This is a firm rule, 
not a suggestion — do not deviate from it even if it seems more thorough 
to test live.

---

**Before building anything:** This file is the source of truth. If something in code contradicts it, fix the file first, then the code.