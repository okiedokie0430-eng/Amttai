<script lang="ts">
  export let data: {
    loadError: string | null;
    stats: Array<{ label: string; value: number }>;
  };
</script>

<svelte:head>
  <title>Dashboard — Amttai Admin</title>
</svelte:head>

<h1 class="page-title">Dashboard</h1>
<p class="page-subtitle">
  Central control for Appwrite data, premium lifecycle, and operational health.
</p>

{#if data.loadError}
  <p class="flash err">{data.loadError}</p>
{/if}

<section class="grid">
  {#each data.stats as stat}
    <article class="card stat-card">
      <h3>{stat.label}</h3>
      <strong>{stat.value}</strong>
    </article>
  {/each}
</section>
