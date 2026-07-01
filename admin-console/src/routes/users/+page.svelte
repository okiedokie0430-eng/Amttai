<script lang="ts">
  export let data: {
    loadError: string | null;
    users: Array<Record<string, any>>;
  };

  export let form:
    | {
        message?: string;
        error?: string;
      }
    | undefined;
</script>

<svelte:head>
  <title>Users — Amttai Admin</title>
</svelte:head>

<h1 class="page-title">Users</h1>
<p class="page-subtitle">
  Manage premium access and serialized custom user IDs.
</p>

{#if data.loadError}
  <p class="flash err">{data.loadError}</p>
{/if}

{#if form?.message}
  <p class="flash ok">{form.message}</p>
{/if}

{#if form?.error}
  <p class="flash err">{form.error}</p>
{/if}

<section class="card" style="margin-bottom: 16px; display: flex; justify-content: space-between; gap: 12px; align-items: center;">
  <div>
    <h3 style="margin: 0 0 4px;">Backfill Missing User IDs</h3>
    <p class="muted" style="margin: 0; font-size: 13px;">Generate serialized IDs for users who still do not have a user code.</p>
  </div>
  <form method="POST" action="?/backfillCodes">
    <button class="primary" type="submit">Generate Missing IDs</button>
  </form>
</section>

<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>Name</th>
        <th>Email</th>
        <th>User Code</th>
        <th>Premium</th>
        <th>Expires</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      {#each data.users as user}
        <tr>
          <td>{user.name || 'Unknown'}</td>
          <td>{user.email || '-'}</td>
          <td>{user.user_code || '-'}</td>
          <td>
            {#if user.is_premium}
              <span class="badge ok">Active</span>
            {:else}
              <span class="badge">Free</span>
            {/if}
          </td>
          <td>{user.premium_expires_at || '-'}</td>
          <td>
            <div class="actions">
              <form method="POST" action="?/setPremium" style="display: flex; gap: 8px;">
                <input type="hidden" name="userId" value={user.id} />
                <select name="months" style="width: 80px;">
                  <option value="1">1M</option>
                  <option value="3">3M</option>
                  <option value="6">6M</option>
                  <option value="12">1Y</option>
                </select>
                <button class="success" type="submit">Set</button>
              </form>

              <form method="POST" action="?/revokePremium">
                <input type="hidden" name="userId" value={user.id} />
                <button class="danger" type="submit">Revoke</button>
              </form>

              <form method="POST" action="?/regenerateCode">
                <input type="hidden" name="userId" value={user.id} />
                <button type="submit">Regenerate ID</button>
              </form>
            </div>
          </td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
