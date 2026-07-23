# PETOrders — Architecture & Conventions

**Audience:** the developer inheriting this codebase. This is the "what
you need to know before you change anything" document — the shape of the
app, the rules that are deliberate, and the gotchas that already bit
someone once. It is intentionally scannable, not exhaustive: the code
itself and `sql/schema.sql` are the reference for details.

---

## Stack — and the zero-dependency rule

- PHP 7.4, plain — no framework, no ORM. Database access is PDO with
  prepared statements throughout.
- MySQL 8.0 / MariaDB 10.11 (InnoDB, utf8mb4).
- Vanilla CSS (system fonts) and vanilla JavaScript (one `script.js`, no
  bundler).
- **No Composer, no npm, no CDN, no external anything.** Every asset is
  local; the app makes no outbound requests and never sends email. This
  is a deliberate constraint for the deployment environment — don't add
  dependencies.

## Directory layout

```
public/            # ONLY web-reachable folder (Apache doc root)
  login.php, register.php, registration_status.php, change_password.php,
  index.php (redirects to /login.php), account_profile.php, 404.php
  customer/        # customer pages (dashboard, orders, order_detail,
                   #   new_order.php = POST-only JSON endpoint,
                   #   lab_delivery_locations, lab_product_users)
  staff/           # dashboard, orders.php (Order Queue), order_detail.php
  admin/           # dashboard, registrations, customers, accounts,
                   #   nuclides, products, institutes, labs, pis,
                   #   reports, export_csv
  assets/          # css/ (component library shared by all roles), js/script.js
src/               # application code — OUTSIDE the doc root, never URL-reachable
  config.php       # DB credentials (gitignored; template: config.sample.php)
  db.php           # get_db(): one memoized PDO per request
  auth.php         # login, lockout, sessions, require_role(), password policy
  helpers.php      # everything shared (see helper inventory below)
  partials/        # layouts, head, new-order form/modal, pagination
config/
  app_settings.php # static app-wide settings (display name); read via app_setting()
sql/               # schema.sql (source of truth), seed.sql (dev data)
tools/             # bootstrap_admin.php (production), set_temp_passwords.php (dev)
```

The doc-root split is a security boundary: `src/` holds DB credentials and
is structurally unreachable by URL. Never move application code into
`public/`.

## Role model

`users` has **no role column**. Role is membership in a marker table:

- `customers` — customer accounts (carries `lab_id` and
  `supervising_pi_id`; a customer's whole world is scoped to their lab).
- `staff` — staff accounts.
- `admins` — FKs to `staff.user_id`, so **every admin is also staff**.

`determine_role()` (src/auth.php) checks admins → staff → customers, in
that order. Admin satisfies staff-only checks (`role_satisfies()`), never
the reverse, and neither satisfies customer.

Self-registration never writes to `users` — it creates a row in
`customer_registration_requests`, and the account is only created when an
admin approves it.

## Catalog model

- Terminology: isotope → **nuclide**, compound → **product**. UI-only
  rename: the `delivery_method` column is displayed as **"Fulfillment"**
  (code and schema names unchanged).
- `nuclides` → flat `products`. A product's `delivery_method`
  (`radiopharmacy` / `pick_up` / `direct_delivery`) is a **fixed property
  of the product row**, never chosen per-order. Offering one compound two
  ways = two product rows (unique key on name + nuclide + method).
- Availability is **computed, never cascaded**:
  `products.active = 1 AND nuclides.active = 1`. Deactivating a nuclide
  makes its products unavailable without touching their rows. Both gates
  live in `get_new_order_form_data()` and `validate_order_input()`.
- Once any order references a product, its nuclide and fulfillment are
  locked (UI-disabled and server-enforced) — the workflow is "create a
  new product row, deactivate the old one." Renaming is always allowed.
- There is **no pricing/cost anywhere**, and no per-lab catalog scoping —
  every available product is visible to every lab. Both deliberate.
- Naming collision to leave alone: "product" (catalog item) vs. "product
  user" (a dose recipient in `lab_product_users`). Don't rename either.

## Order lifecycle — the state machine

4 states: `pending`, `accepted`, `completed`, `cancelled`.
5 transitions:

| Transition | Who | Path |
|---|---|---|
| accept | staff | pending → accepted |
| return | staff | accepted → pending |
| complete | staff | accepted → completed (**terminal**) |
| cancel | customer (own pending order) or staff (pending/accepted) | → cancelled |
| reopen | staff | cancelled → pending |

Hard rules:

- **Every** transition goes through `transition_order_status()` in
  `src/helpers.php` — the single validated path. It row-locks the order
  (`FOR UPDATE`), validates the transition against the actor's role,
  writes the order update and the `order_audit_log` row in one
  transaction. No call site bypasses it; never invent a new transition.
- Cancelling **requires a reason** (`cancellation_reason`, ≤500 chars) —
  enforced inside `transition_order_status()`. Reopen clears it.
- `order_audit_log` is **status-only** — order creation plus each
  transition. No field-level diffing; don't add any.
- `orders.chargeable` is independent of lifecycle: staff-toggleable in any
  status, defaults true, deliberately **not** audit-logged. "Not
  chargeable" is the flagged exception in the UI; "Chargeable" is the
  quiet default.
- `orders.notes` is the **only** communication channel: one shared field,
  editable by staff always and by the customer on their own pending
  order, last-write-wins, no history, no staff-only channel.
- Staff act on orders only from `staff/order_detail.php`; the Order Queue
  (`staff/orders.php`) is a pure triage list with no actions.

## Directory model (institutes / labs / PIs)

- Institute → lab availability mirrors nuclide → product: computed
  (`labs.active AND institutes.active`), no cascade writes.
- Lab↔PI pairing lives in `lab_pis` and is managed from **one place
  only**: the Lab modal's PI roster in `admin/labs.php`. `pis.php` has no
  pairing UI on purpose.
- `active` flags on labs/PIs gate **only** new-registration selection and
  changed-to assignments. They never affect existing customers or orders.
  Deactivating anything is always non-destructive.
- Admin customer edit rule: keeping the current lab + PI always saves
  (stale/inactive assignments never block an unrelated edit); *changing*
  either requires the new lab and PI to be active and paired.
- Only `institutes.name` has a DB unique key; lab and PI names are
  intentionally not unique.

## Gotcha: layout partials share the page's variable scope

The layouts (`src/partials/layout_customer.php` / `layout_staff.php` /
`layout_admin.php`) are plain `include`s executed mid-page, so any
variable they set lands in the **including page's scope**. This caused a
real bug: a layout's bare `$products`/`$locations` variables were silently
overwritten by a page that declared its own.

The fix, and the standing convention: everything a layout produces is
namespaced under a single `$petcomLayout` array (account identity,
current-page marker, sidebar state, and — for the customer layout — the
New Order modal's backing data). Before naming variables on any page that
includes a layout, check the layout for its reserved names. Two extras:
`head.php` expects `$pageTitle` from the caller, and the customer layout
reads a page-owned loose `$labId` (deliberate exception).

`customer/dashboard.php` and `customer/order_detail.php` read
`$petcomLayout` fields after including the layout — treat those fields as
an API surface if you touch the layouts.

## Shared helpers — check here before writing new logic

All in `src/helpers.php` unless noted:

| Helper | Purpose |
|---|---|
| `transition_order_status()` | the one lifecycle path (see above) |
| `validate_order_input()` | full order-form validation + normalization (lab scoping, direct-delivery location requirement, 24h HH:MM time) |
| `get_new_order_form_data()` | nuclides/products/locations/product-users for the order form, availability-filtered |
| `fetch_order_audit_trail()` / `describe_order_transition()` | audit feed + human-readable labels |
| `csrf_field()` / `verify_csrf()` | CSRF token field + POST verification |
| `e()` | HTML escaping (htmlspecialchars, ENT_QUOTES, UTF-8) |
| `toast_flash()` | success toast after PRG redirect |
| `field_class()` / `field_error()` | per-field validation display |
| `paginate()` | clamped pagination math — consume its `rangeStart`/`rangeEnd`, don't recompute |
| `form_action()` / `build_query()` | list-page actions/links that preserve filter + page state |
| `bootstrap_session()` | hardened `session_start()` (httponly, samesite=Lax, secure per config) — every page uses this, never bare `session_start()` |
| `app_setting()` | reads `config/app_settings.php` |
| `csv_safe()` | CSV formula-injection neutralization (used by the report export) |
| `customer_display_name()`, `delivery_method_label()`, `format_activity_mci()` | display formatting |

Constants: `DEFAULT_PAGE_SIZE` (10) and `PAGE_SIZE_OPTIONS`
([10, 20, 50, 100]) — reuse, don't redefine.

One deliberate anti-DRY case: `generate_temp_password()` is duplicated
per-file (registrations, customer detail, account detail, bootstrap tool)
on purpose. Copy the shape; don't centralize it.

## Security posture

- PDO with real prepared statements (`ATTR_EMULATE_PREPARES = false`),
  exceptions on error, utf8mb4 DSN charset.
- CSRF token on every POST; token rotated at login.
- Sessions: httponly + SameSite=Lax cookies, `secure` when
  `REQUIRE_SECURE_COOKIES` is on; 15-minute idle timeout; session ID
  regenerated at login.
- Login lockout: 5 failed attempts → 15-minute lock, deliberately
  invisible to the user (every failure shows the same generic message).
  Lockouts are recorded in `lockout_events` and surfaced on the admin
  dashboard.
- Password policy: ≥12 chars, at least one letter and one number, must
  not contain the username/email, can't match the last 5 passwords
  (`password_history`). Admins trigger resets but never see or choose a
  user's real password.
- `require_role()` re-checks `users.active` live on every request, sets
  `Cache-Control: no-store`, `X-Frame-Options: DENY`,
  `X-Content-Type-Options: nosniff`, and forces `/change_password.php`
  while a temp password is in effect.
- `display_errors` off; a global exception handler logs and renders a
  generic 500 page. Timezone pinned to `America/New_York` in code.

## UI conventions

- One shared component CSS library for all three roles — no role-specific
  stylesheets.
- Successful POST → redirect (PRG) → toast via `toast_flash()`. Errors →
  inline `.alert--error` + per-field messages. **Exception:** temporary
  password reveals use a read-once session flash with a 60-second TTL —
  never a toast, never the URL.
- Destructive actions use `data-confirm*` attributes intercepted by
  `script.js` into a custom modal — never `window.confirm`.
- List pages: `.status-tabs` strip with live counts, explicit-submit
  filter forms (never live-as-you-type), shared pagination partial.
- Create/edit modals follow one skeleton (copy `admin/nuclides.php`'s Add
  modal) with dirty-tracking + discard-confirm; the modal shell is
  intentionally not a shared partial.
- Order times are 24-hour `HH:MM` **text inputs** (pattern-validated),
  never a native time picker — a real department requirement.
- Badges: dotted pills for statuses, square no-dot chips for facts (role,
  "Not chargeable").

## Things that look like gaps but are decisions

Don't "fix" these — they are requirements:

- No email sending of any kind. No cost/pricing fields. No phone-in-order
  flag. No per-order quantity limits. No staff-only notes channel. No
  field-level audit log. No category concept for products or staff. No
  app-level uniqueness for lab/PI names. Customers cannot edit their own
  profile (admin-only) — only their password.
