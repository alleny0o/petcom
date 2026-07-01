<?php
/**
 * Self-registration page.
 *
 * Standalone: no shared header/footer (pre-login flow).
 * Submitting creates a pending registration REQUEST, not an active account.
 * An admin must approve before the account is activated.
 *
 * Right now this only RENDERS the form. Submitting it does nothing until
 * db.php + schema exist.
 *
 * TODO (once schema exists):
 *   1. Verify CSRF token
 *   2. Validate all required fields server-side
 *   3. Check no existing account/request with this email
 *   4. INSERT into customer_registration_requests (status = 'pending')
 *   5. Show success message ("Your request has been submitted...")
 */

$error = '';
$success = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  // TODO: wire to db.php once schema exists.
  $error = 'Registration is not wired up yet.';
}

// TODO: replace with a real db query once schema exists.
// SELECT id, name FROM institutes WHERE active = 1 ORDER BY name
$institutes = [
  'CC' => 'CC — Clinical Center',
  'FIC' => 'FIC — Fogarty International Center',
  'NCATS' => 'NCATS — National Center for Advancing Translational Sciences',
  'NCCIH' => 'NCCIH — National Center for Complementary and Integrative Health',
  'NCI' => 'NCI — National Cancer Institute',
  'NEI' => 'NEI — National Eye Institute',
  'NHGRI' => 'NHGRI — National Human Genome Research Institute',
  'NHLBI' => 'NHLBI — National Heart, Lung, and Blood Institute',
  'NIA' => 'NIA — National Institute on Aging',
  'NIAAA' => 'NIAAA — National Institute on Alcohol Abuse and Alcoholism',
  'NIAID' => 'NIAID — National Institute of Allergy and Infectious Diseases',
  'NIAMS' => 'NIAMS — National Institute of Arthritis and Musculoskeletal and Skin Diseases',
  'NIBIB' => 'NIBIB — National Institute of Biomedical Imaging and Bioengineering',
  'NICHD' => 'NICHD — Eunice Kennedy Shriver National Institute of Child Health and Human Development',
  'NIDA' => 'NIDA — National Institute on Drug Abuse',
  'NIDCD' => 'NIDCD — National Institute on Deafness and Other Communication Disorders',
  'NIDCR' => 'NIDCR — National Institute of Dental and Craniofacial Research',
  'NIDDK' => 'NIDDK — National Institute of Diabetes and Digestive and Kidney Diseases',
  'NIEHS' => 'NIEHS — National Institute of Environmental Health Sciences',
  'NIGMS' => 'NIGMS — National Institute of General Medical Sciences',
  'NIMH' => 'NIMH — National Institute of Mental Health',
  'NIMHD' => 'NIMHD — National Institute on Minority Health and Health Disparities',
  'NINDS' => 'NINDS — National Institute of Neurological Disorders and Stroke',
  'NINR' => 'NINR — National Institute of Nursing Research',
  'NLM' => 'NLM — National Library of Medicine',
  'ODP' => 'ODP — Office of Disease Prevention',
  'ORS' => 'ORS — Office of Research Services',
];

// Re-populate fields on error so the user doesn't lose their input
$old = $_POST ?? [];
function old(string $key, string $default = ''): string
{
  global $old;
  return htmlspecialchars($old[$key] ?? $default);
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
  <?php $pageTitle = 'Register';
  include '../src/partials/head.php'; ?>

  <style>
    /* Register card is wider than the login card */
    .auth-card {
      max-width: 540px;
    }

    .form-section {
      font-size: 11px;
      font-weight: 600;
      color: var(--color-text-secondary);
      letter-spacing: 0.06em;
      text-transform: uppercase;
      padding-bottom: 0.4rem;
      border-bottom: 1px solid var(--color-border-hr);
      margin: 1.5rem 0 1rem;
    }

    .form-section:first-of-type {
      margin-top: 0;
    }

    .form-section__note {
      font-size: 12px;
      color: var(--color-text-placeholder);
      font-weight: 400;
      text-transform: none;
      letter-spacing: 0;
      margin-top: 0.2rem;
    }

    .form-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0.75rem 1rem;
    }

    .form-grid .span-2 {
      grid-column: 1 / -1;
    }

    @media (max-width: 520px) {
      .form-grid {
        grid-template-columns: 1fr;
      }

      .form-grid .span-2 {
        grid-column: 1;
      }
    }
  </style>
</head>

<body>

  <div class="auth-wrap">
    <div class="auth-card">

      <!-- Header -->
      <div class="auth-card__head">
        <div class="auth-card__brand">
          <div class="auth-card__logo">P</div>
          <div>
            <div class="auth-card__title">Request an account</div>
            <div class="auth-card__subtitle">An admin will review and activate your account</div>
          </div>
        </div>
      </div>

      <!-- Body -->
      <div class="auth-card__body">

        <?php if ($error): ?>
          <div class="alert alert--error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <?php if ($success): ?>
          <div class="alert alert--success">
            Your request has been submitted. An admin will contact you via NIH
            email once your account is activated.
          </div>
        <?php else: ?>

          <form method="post" action="register.php">

            <!-- 1. Institute -->
            <div class="form-section">Institute</div>
            <div class="field">
              <label for="institute">NIH Institute</label>
              <select id="institute" name="institute" required>
                <option value="" disabled <?= !old('institute') ? 'selected' : '' ?>>
                  Select your institute
                </option>
                <?php foreach ($institutes as $code => $label): ?>
                  <option value="<?= htmlspecialchars($code) ?>" <?= old('institute') === $code ? 'selected' : '' ?>>
                    <?= htmlspecialchars($label) ?>
                  </option>
                <?php endforeach; ?>
              </select>
            </div>

            <!-- 2. Investigator (the person registering) -->
            <div class="form-section">Investigator (you)</div>
            <div class="form-grid">
              <div class="field">
                <label for="inv_name">Full name</label>
                <input type="text" id="inv_name" name="inv_name" value="<?= old('inv_name') ?>" required>
              </div>
              <div class="field">
                <label for="inv_email">NIH email <span class="muted">(your login)</span></label>
                <input type="email" id="inv_email" name="inv_email" value="<?= old('inv_email') ?>"
                  autocomplete="username" required>
              </div>
              <div class="field">
                <label for="inv_phone">Phone</label>
                <input type="text" id="inv_phone" name="inv_phone" value="<?= old('inv_phone') ?>" required>
              </div>
              <div class="field">
                <label for="inv_lab">Lab <span class="muted">(Building &amp; Room)</span></label>
                <input type="text" id="inv_lab" name="inv_lab" placeholder="e.g. Bldg 10, Rm 1C401"
                  value="<?= old('inv_lab') ?>" required>
              </div>
            </div>

            <!-- 3. Principal Investigator -->
            <div class="form-section">Principal Investigator</div>
            <div class="form-grid">
              <div class="field span-2">
                <label for="pi_name">PI name</label>
                <input type="text" id="pi_name" name="pi_name" value="<?= old('pi_name') ?>" required>
              </div>
              <div class="field">
                <label for="pi_email">PI email</label>
                <input type="email" id="pi_email" name="pi_email" value="<?= old('pi_email') ?>" required>
              </div>
              <div class="field">
                <label for="pi_phone">PI phone</label>
                <input type="text" id="pi_phone" name="pi_phone" value="<?= old('pi_phone') ?>" required>
              </div>
            </div>

            <!-- 4. NRC License Contact -->
            <div class="form-section">
              NRC License Contact
              <div class="form-section__note">For shipping orders only</div>
            </div>
            <div class="form-grid">
              <div class="field span-2">
                <label for="nrc_name">Contact name</label>
                <input type="text" id="nrc_name" name="nrc_name" value="<?= old('nrc_name') ?>">
              </div>
              <div class="field">
                <label for="nrc_phone">Contact phone</label>
                <input type="text" id="nrc_phone" name="nrc_phone" value="<?= old('nrc_phone') ?>">
              </div>
              <div class="field">
                <label for="nrc_email">Contact email</label>
                <input type="email" id="nrc_email" name="nrc_email" value="<?= old('nrc_email') ?>">
              </div>
            </div>

            <button type="submit" class="btn btn--primary btn--block">
              Submit request
            </button>

          </form>

        <?php endif; ?>

        <div class="auth-card__foot">
          Already have an account? <a href="login.php">Sign in</a>
        </div>

      </div>
    </div>
  </div>

</body>

</html>