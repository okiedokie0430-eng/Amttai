<script lang="ts">
  export let form:
    | {
        error?: string;
      }
    | undefined;
</script>

<svelte:head>
  <title>Admin Login</title>
</svelte:head>

<div class="auth-shell">
  <form class="auth-card" method="POST">
    <h1 class="page-title" style="margin-bottom: 8px;">Admin Login</h1>
    <p class="muted" style="margin-top: 0; margin-bottom: 16px;">
      Enter admin password to access backend controls.
    </p>

    <label for="password">Password</label>
    <input id="password" name="password" type="password" autocomplete="current-password" required />

    {#if form?.error}
      <p class="badge err" style="margin-top: 10px;">{form.error}</p>
    {/if}

    <button class="primary" type="submit" style="margin-top: 14px; width: 100%;">Sign in</button>
  </form>
</div>
