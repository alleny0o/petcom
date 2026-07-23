# PETOrders — Local Development Setup

**Audience:** a developer picking up PETOrders for maintenance or new
work. This gets you from a clean machine to a running app with a fully
seeded test database.

The reference dev environment is **MAMP on macOS** (that's what the app
was built against), but any Apache + PHP 7.4 + MySQL/MariaDB stack works —
the app has no other dependencies. No Composer, no npm, no build step:
clone it, configure it, load the database, done.

---

## 1. Prerequisites

- Apache + PHP 7.4 + MySQL (MAMP ships all three)
- Git

## 2. Clone and create the database

```bash
git clone <your-git-remote>/petorders.git
cd petorders
```

Create a database named `petorders` (phpMyAdmin or the CLI), then load the
schema **and** the seed data, in that order:

```bash
# MAMP's MySQL listens on port 8889 (default user/pass: root/root)
/Applications/MAMP/Library/bin/mysql -u root -proot --port=8889 -e "CREATE DATABASE petorders CHARACTER SET utf8mb4"
/Applications/MAMP/Library/bin/mysql -u root -proot --port=8889 petorders < sql/schema.sql
/Applications/MAMP/Library/bin/mysql -u root -proot --port=8889 petorders < sql/seed.sql
```

`sql/seed.sql` is broad dev/test data so every screen has something on it:

- 27 institutes, 3 labs, 2 PIs (with lab↔PI pairings)
- 7 accounts — 1 admin, 2 staff, 4 customers
- 5 nuclides, 10 products (including one product seeded under two
  fulfillment methods, to exercise the dual-row convention)
- 4 delivery locations, 2 product users
- 10 orders spanning every status, with open orders dated relative to
  today so the dashboards always populate

## 3. Configure the app

```bash
cp src/config.sample.php src/config.php
```

Edit `src/config.php` with MAMP values:

| Constant | MAMP value |
|---|---|
| `DB_HOST` | `127.0.0.1` |
| `DB_PORT` | `8889` |
| `DB_NAME` | `petorders` |
| `DB_USER` | `root` |
| `DB_PASS` | `root` |
| `REQUIRE_SECURE_COOKIES` | `false` — local dev runs plain HTTP; setting this `true` without HTTPS makes login silently fail (the session cookie is never sent) |

`src/config.php` is gitignored — your local credentials never leave your
machine.

## 4. Set passwords for the seeded accounts

The seed file ships placeholder password hashes on purpose — no seeded
account can log in until you run:

```bash
php tools/set_temp_passwords.php
```

This sets **every** account's password to `TempPass123!` and forces a
password change on first login. It prints what it did:

```
Temp password for all accounts: TempPass123!
Rows updated: 7
```

Safe to re-run any time you want to reset all dev accounts (e.g. after
testing password changes or lockouts).

## 5. Point Apache at public/ and log in

Set the document root to the `public/` folder — **not** the project root.
In MAMP: Preferences → Server → Document Root → choose
`petorders/public`. (Only `public/` is designed to be web-reachable;
`src/`, `sql/`, `tools/`, and `config/` must stay outside the document
root. Production has the same rule — see
[DEPLOYMENT.md](DEPLOYMENT.md#5-configure-apache--document-root-must-be-public).)

Open `http://localhost:8888/login.php` and sign in as any seeded account
(password `TempPass123!`, and you'll be prompted to set a real one —
minimum 12 characters with a letter and a number):

| Username | Role |
|---|---|
| `robert.nguyen@nih.gov` | admin |
| `maria.santos@nih.gov` | staff |
| `james.oconnor@nih.gov` | staff |
| `alice.carter@nih.gov` | customer (Molecular Imaging Lab) |
| `brian.kim@nih.gov` | customer |
| `deepa.patel@nih.gov` | customer |
| `evan.feng@nih.gov` | customer |

## 6. seed.sql vs. bootstrap_admin.php — don't mix them up

Two very different setup paths share the `tools/` folder:

| | Dev sandbox (this guide) | Production launch |
|---|---|---|
| Database contents | `schema.sql` + `seed.sql` | `schema.sql` only |
| Accounts | 7 seeded accounts | exactly 1 real admin |
| Tool | `tools/set_temp_passwords.php` — bulk-resets *all* accounts to `TempPass123!` | `tools/bootstrap_admin.php <email> <first> <last>` — creates the single admin, prints a random one-time password |
| Guard | none (re-runnable) | refuses to run if `users` has any rows |

`bootstrap_admin.php` is documented in full in
[DEPLOYMENT.md](DEPLOYMENT.md#7-create-the-first-admin-account). You will
normally never run it locally, and you must never run
`set_temp_passwords.php` in production.

## 7. Development notes

- **Workflow:** branch → PR → merge. `main` is branch-protected — never
  push to it directly.
- **Verification policy:** verification is `php -l`, static code review,
  and grep. All live testing is done manually in the browser against your
  MAMP instance — the project deliberately has no test harness, scratch
  databases, or HTTP-level test tooling.
- **Gitignored files to know about:** `src/config.php` (your local
  credentials) never leaves your machine — the committed template is
  `src/config.sample.php`.
- **Architecture and conventions:** read
  [ARCHITECTURE.md](ARCHITECTURE.md) before making changes — it covers
  the role model, the order state machine, and a couple of real gotchas
  (layout variable scoping in particular) that will bite you otherwise.
