<script lang="ts">
  export let data: {
    loadError: string | null;
    functions: Array<Record<string, any>>;
    knownIds: string[];
  };

  export let form:
    | {
        message?: string;
        error?: string;
      }
    | undefined;
</script>

<svelte:head>
  <title>Functions - Admin</title>
</svelte:head>

<h1 class="page-title">Functions</h1>
<p class="muted" style="margin-top: -6px; margin-bottom: 16px;">
  Trigger backend functions and check deployment readiness. Use the Notifications page for push broadcasts.
</p>

{#if data.loadError}
  <p class="badge err" style="margin-bottom: 12px;">{data.loadError}</p>
{/if}

{#if form?.message}
  <p class="badge ok" style="margin-bottom: 12px;">{form.message}</p>
{/if}

{#if form?.error}
  <p class="badge err" style="margin-bottom: 12px;">{form.error}</p>
{/if}

<section class="card" style="margin-bottom: 16px;">
  <h3 style="margin: 0 0 10px;">Execute Function</h3>
  <form method="POST" action="?/execute" class="form-grid">
    <div>
      <label for="functionId">Function ID</label>
      <input id="functionId" name="functionId" placeholder="broadcast-push" required />
    </div>
    <div style="grid-column: 1 / -1;">
      <label for="payload">JSON Payload</label>
      <textarea id="payload" name="payload" rows="3" placeholder="&#123;&quot;ping&quot;:true&#125;"></textarea>
    </div>
    <div>
      <button class="primary" type="submit">Execute</button>
    </div>
  </form>
</section>

<section class="card" style="margin-bottom: 16px;">
  <h3 style="margin: 0 0 8px;">Expected Function IDs</h3>
  <div class="actions">
    {#each data.knownIds as id}
      <span class="badge">{id}</span>
    {/each}
  </div>
</section>

<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>ID</th>
        <th>Name</th>
        <th>Runtime</th>
        <th>Enabled</th>
        <th>Timeout</th>
        <th>Deployments</th>
      </tr>
    </thead>
    <tbody>
      {#each data.functions as fn}
        <tr>
          <td>{fn.id}</td>
          <td>{fn.name}</td>
          <td>{fn.runtime}</td>
          <td>{fn.enabled ? 'Yes' : 'No'}</td>
          <td>{fn.timeout}s</td>
          <td>{fn.deployments}</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
