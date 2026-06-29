<?php
/**
 * Login page.
 *
 * Standalone: no shared header/footer (you're not logged in yet, so there's
 * no nav). Just the centered auth card on a slate page.
 *
 * Right now this only RENDERS the form. Submitting it does nothing until
 * auth.php exists (needs the database + schema first). The form posts to
 * itself; the POST-handling block at the top is stubbed and marked TODO.
 */

// --- Form handling (stub until auth.php is ready) ---
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // TODO: wire to auth.php once schema + db.php exist.
    //   1. read $_POST['email'] and $_POST['password']
    //   2. verify CSRF token
    //   3. look up the account, check the password hash
    //   4. on success, start session + redirect to index.php
    //   5. on failure, set $error to a friendly message
    $error = 'Login is not wired up yet.';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sign in &middot; PETStack</title>

  <!-- Favicon -->
  <link rel="icon" href="/favicons/favicon.ico" sizes="any">
  <link rel="icon" type="image/png" sizes="32x32" href="/favicons/favicon-32x32.png">
  <link rel="icon" type="image/png" sizes="16x16" href="/favicons/favicon-16x16.png">
  <link rel="apple-touch-icon" href="/favicons/apple-touch-icon.png">
  <link rel="manifest" href="/favicons/site.webmanifest">

  <!-- Inter font -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

  <!-- App styles -->
  <link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>

  <div class="auth-wrap">
    <div class="auth-card">

      <div class="auth-card__head">
        <div class="auth-card__brand">
          <div class="auth-card__logo">P</div>
          <div>
            <div class="auth-card__title">PETStack</div>
            <div class="auth-card__subtitle">PET Department Ordering</div>
          </div>
        </div>
      </div>

      <div class="auth-card__body">

        <?php if ($error): ?>
          <div class="alert alert--error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <form method="post" action="login.php">

          <div class="field">
            <label for="email">NIH email</label>
            <input type="email" id="email" name="email"
                   autocomplete="username" required autofocus>
          </div>

          <div class="field">
            <label for="password">Password</label>
            <input type="password" id="password" name="password"
                   autocomplete="current-password" required>
          </div>

          <button type="submit" class="btn btn--primary btn--block">Sign in</button>

        </form>

        <div class="auth-card__foot">
          Need an account? <a href="register.php">Register</a>
        </div>

      </div>
    </div>
  </div>

</body>
</html>