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
| Allen    | Whole pages: login, customer ordering, order views           |
| Anthony  | Whole pages: admin management, staff processing queue        |

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

New to branches? See `learngitbranching.js.org` (20 min, interactive) and
GitHub's "Hello World" tutorial.

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
- [ ] Forced password change, strong-password rule
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
- [ ] Accept / modify / complete / cancel / return actions
- [ ] Public comments + internal notes
- [ ] Phone-in orders, "modified" indicator

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

Full details in `docs/STRUCTURE.md` and `docs/SCHEMA.md`.

---

## Current status

Foundation is underway. Planning docs, repo, and config are done. Next up:
Xiaofan on the schema, Allen on base CSS + the login page, Anthony on the
admin pages. Shared files like `db.php` and `auth.php` get picked up by
whoever gets there first. We aim to have login working end-to-end before
moving to the ordering features.