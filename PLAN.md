# PETStack: Project Plan

A web-based radiotracer ordering system for the NIH Clinical Center PET
Department. Replaces the legacy HSS PET Ordering System. 6-week build,
three people.

This plan answers four things: who does what, what order we build in,
what's already decided, and what's done so far.

---

## Who does what

In vanilla PHP, a page's HTML and its logic live in the same file, so
"frontend person" and "backend person" can't cleanly split one page. So we
split a different way:

- **Xiaofan owns the data layer.** Schema, SQL, queries. This is genuinely
  separate work (different language, different files) and rarely collides
  with the rest.
- **Allen and Anthony own the web app**, splitting it **by page, not by
  layer.** Each of us takes whole pages start to finish: the HTML, the form,
  the styling, and the PHP logic for that page. We're good enough to each
  handle both halves of our own pages, and it keeps us out of the same files.

| Person   | Owns                                                          |
|----------|--------------------------------------------------------------|
| Xiaofan  | Database: schema, SQL, queries, the data layer               |
| Allen    | Whole pages: login, customer ordering, order views            |
| Anthony  | Whole pages: admin management, staff processing queue         |

Shared foundation files (`db.php`, `auth.php`, base CSS, header/footer) are
built once by whoever picks them up, then everyone uses them. Decide those
per-file as we go, don't both grab the same one.

Allen is strongest at web dev (HTML/CSS); Anthony wants to learn, so owning
whole pages including the PHP is good growth for him. When a page is tricky,
pair on it: one person types, both think.

Rule of thumb: **one person owns a page at a time.** Before touching a page
or shared file someone else might be in, say so first. A 10-second "I'm in
`login.php`, you good?" prevents almost every merge conflict.

---

## How we work (so we don't clobber each other)

- **Never push straight to `main`.** Make a branch, open a pull request, merge it.
- One branch per piece of work, named for what it does (`login-page`, `schema`, `auth`).
- Keep pull requests small. Easier to review, less to break.
- `main` should always be in a working state.

---

## Build order

We build bottom-up: the shared foundation first, then features on top. Much
of this runs in parallel: Xiaofan on data, Allen and Anthony on pages.

**Phase 1: Foundation (in progress)**
- [x] Planning docs (README, STRUCTURE, SCHEMA, this file)
- [x] `.gitignore`, repo setup
- [x] `config.sample.php` + local `config.php`
- [ ] `sql/schema.sql`: all tables  *(Xiaofan)*
- [ ] `src/db.php`: the database connection  *(whoever picks it up first)*
- [ ] Base CSS + header/footer partials  *(Allen)*

**Phase 2: Login and accounts**
- [ ] `src/auth.php`: login, `require_role()`, session guard  *(shared foundation)*
- [ ] Login / logout pages  *(Allen)*
- [ ] Forced password change, strong-password rule (see Business Rules below)
- [ ] Self-registration form + admin approval queue  *(Anthony)*

**Phase 3: The menu (admin setup)**  *(Anthony's pages)*
- [ ] Manage compounds, isotopes, categories, delivery options
- [ ] Manage institutes, labs, PIs
- [ ] Manage customers and users

**Phase 4: Ordering**  *(Allen's pages)*
- [ ] New order form, Type A (dose) and Type B (cyclotron)
- [ ] Isotope-first selection, lead-time validation
- [ ] Customer order list + order detail view

**Phase 5: Processing**
- [ ] Staff processing queue (filtered by category)
- [ ] Accept / modify / complete / cancel / return actions (see status rules below)
- [ ] Public comments + internal notes

**Phase 6: Reports**
- [ ] The six report types, filterable
- [ ] CSV / PDF export (cost reports admin-only)

**Phase 7: Polish + handoff**
- [ ] Responsive / mobile pass
- [ ] `.htaccess`, HTTPS, error pages (404/403/500)
- [ ] Deployment notes for NIH IT

---

## What's already decided

So nobody reopens these:

- **Stack:** vanilla PHP + PDO + MySQL. No framework, no Composer.
- **Database engine:** MySQL (team's choice; needs the MySQL repo on RHEL, not the default MariaDB).
- **`public/` is flat** (no role subfolders). Access is gated in code on each page.
- **`src/` lives outside the web root** so the DB password can't be reached by URL.
- **Soft-delete only**: nothing is ever truly deleted, just flagged inactive. Keeps history for reports.
- **Cost is snapshotted** onto each order when placed, so old reports stay correct if a price changes.
- **Order IDs** always increment, never reused.
- **No email integration**: admins notify customers manually via NIH email outside the app.
- **No phone-in orders.** Every order is created one way: the customer logs in and
  places it themselves. (Originally scoped, cut for complexity — Kris's call.)
- **Auth is centralized in `auth.php`.** Local username/password is what we're
  building now, but NIH SSO is a possible future swap (Kris left it open during
  the original interview, didn't commit either way). Pages only ever check
  `$_SESSION['role']` / `$_SESSION['user_id']` — never touch passwords or auth
  mechanics directly. If SSO happens later, only `auth.php` (and maybe
  `login.php` / `register.php`) should need to change; the rest of the app
  doesn't know or care how someone got authenticated.

Full details in `docs/STRUCTURE.md` and `docs/SCHEMA.md`.

---

## Business rules checklist (don't lose these)

Specific rules from the original requirements interview that need to land
in code somewhere, not just "be implied." Whoever builds the relevant page
should check this list before calling it done.

**Auth / accounts** *(mostly `auth.php`)*
- [ ] Session idle timeout: **15 minutes**, then forced re-login.
- [ ] Failed login lockout: **5 attempts**, then **15-minute** lockout.
- [ ] Strong password policy is defined explicitly somewhere (length + character
      mix) — don't leave this as "industry standard" with no actual rule written.
- [ ] Temp passwords (initial registration *and* admin-triggered resets) are
      **one-time use**: forces a password change on first login, then the temp
      password is invalidated.
- [ ] Admin can **trigger** a password reset but can never **view or set** the
      actual password at any point.

**Registration**
- [ ] Self-registration form collects: Institute (dropdown, admin-expandable),
      Investigator (name, email, phone, lab building + room), PI (name, email,
      phone), and NRC license contact (name, phone, email — for shipping orders).
- [ ] Institute/lab/PI are locked after account creation — only an admin can
      change them later, never the customer.
- [ ] Username = NIH email address. No duplicate-detection needed (email is
      already unique).
- [ ] Registration sits as **pending** until an admin approves or rejects
      (rejection requires a reason).
- [ ] Admin notifies the customer of approval/rejection **manually, outside
      the app**, via NIH email. The app itself never sends email.
- [ ] `reg_status` page: applicant checks status by entering their
      registration email — no password needed for this lookup.

**Ordering**
- [ ] Order flow is **isotope-first**: customer picks an isotope, then only
      sees compounds compatible with that isotope.
- [ ] Type A (dose) and Type B (cyclotron) are independent order types, not
      parent/child.
- [ ] Type B has two mutually exclusive input modes (beam current x time,
      or EOB activity + datetime) — only show/validate the active mode's fields.
- [ ] Lead time is **per-compound**, not global — validate the requested
      date/time against that specific compound's minimum lead time.
- [ ] Delivery options are **per-compound** (not a global list) — only show
      the options that compound allows.
- [ ] Cost is hidden from customers entirely; visible only to admins (reports).
- [ ] No quantity limits on orders.

**Order status / lifecycle**
- [ ] Customer can edit/cancel their **own** order only while it's still
      `pending` — once a user accepts it, the customer loses that right.
- [ ] Customer can **view** (not edit) all orders belonging to their lab,
      not just their own.
- [ ] A user can only process orders in **categories they're assigned to**
      (e.g., a pharmacist can't complete a cyclotron-only order).
- [ ] When a user **returns** an order to the customer, it goes back to
      `pending` status (not a separate "returned" status) — the audit log
      still shows the transition happened.
- [ ] **Completed orders are terminal** — no cancellation once completed.
      Enforce this in the status-transition logic, not just by hiding the
      button in the UI.
- [ ] Status changes are logged (who, what status, when) — status-level
      logging is sufficient, no field-by-field diffing required.
- [ ] Public comments and internal notes are **separate, append-only
      threads**, not single overwritable fields.
- [ ] Customer sees a "modified" indicator on orders changed since they
      last viewed them.

---

## Current status

Foundation is underway. Planning docs, repo, and config are done. Next up:
Xiaofan on the schema, Allen on base CSS + the login page, Anthony on the
admin pages. Shared files like `db.php` and `auth.php` get picked up by
whoever gets there first. We aim to have login working end-to-end before
moving to the ordering features.