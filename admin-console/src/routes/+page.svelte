<script lang="ts">
  export let data: {
    loadError: string | null;
    stats: Array<{ label: string; value: number }>;
  };
</script>

<svelte:head>
  <title>Admin Dashboard</title>
</svelte:head>

<h1 class="page-title">Backend Overview</h1>
<p class="muted" style="margin-top: -6px; margin-bottom: 16px;">
  Central control for Appwrite data, premium lifecycle, and operational health.
</p>

{#if data.loadError}
  <p class="badge err" style="margin-bottom: 12px;">{data.loadError}</p>
{/if}

<section class="grid">
  {#each data.stats as stat}
    <article class="card">
      <h3>{stat.label}</h3>
      <strong>{stat.value}</strong>
    </article>
  {/each}
</section>
