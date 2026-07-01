<script lang="ts">
  export let data: {
    loadError: string | null;
    recipes: Array<Record<string, any>>;
    page: number;
    pageSize: number;
    total: number;
    totalPages: number;
  };

  export let form:
    | {
        message?: string;
        error?: string;
      }
    | undefined;

  let searchQuery = '';
  let categoryFilter = 'all';
  let premiumFilter = 'all';
  let showDeleteAllConfirm = false;

  $: categories = [...new Set(data.recipes.map((r) => r.category).filter(Boolean))];

  $: filteredRecipes = data.recipes.filter((recipe) => {
    const matchesSearch = !searchQuery ||
      String(recipe.title ?? '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      String(recipe.category ?? '').toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory = categoryFilter === 'all' || recipe.category === categoryFilter;
    const matchesPremium = premiumFilter === 'all' ||
      (premiumFilter === 'premium' && recipe.is_premium) ||
      (premiumFilter === 'free' && !recipe.is_premium);
    return matchesSearch && matchesCategory && matchesPremium;
  });

  function formatTime(prep: number, cook: number) {
    const total = (prep || 0) + (cook || 0);
    return `${total} min`;
  }
</script>

<svelte:head>
  <title>Recipes — Amttai Admin</title>
</svelte:head>

<h1 class="page-title">Recipes</h1>
<p class="page-subtitle">
  Manage your recipe catalog. Create new recipes or edit existing ones with rich metadata.
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

<div class="toolbar">
  <div class="toolbar-group">
    <div class="search-bar" style="width: 280px;">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
      <input type="text" placeholder="Search recipes..." bind:value={searchQuery} />
    </div>

    <select bind:value={categoryFilter} style="width: 160px;">
      <option value="all">All Categories</option>
      {#each categories as cat}
        <option value={cat}>{cat}</option>
      {/each}
    </select>

    <select bind:value={premiumFilter} style="width: 140px;">
      <option value="all">All Access</option>
      <option value="premium">Premium Only</option>
      <option value="free">Free Only</option>
    </select>
  </div>

  <div class="toolbar-group">
    <a class="button primary" href="/recipes/new">+ New Recipe</a>
    {#if data.recipes.length > 0}
      <button class="danger" type="button" on:click={() => showDeleteAllConfirm = true}>Delete All</button>
    {/if}
  </div>
</div>

{#if data.totalPages > 1}
  <div class="pagination">
    <span class="pagination-info">
      Showing {(data.page - 1) * data.pageSize + 1}–{Math.min(data.page * data.pageSize, data.total)} of {data.total} recipes
    </span>
    <div class="pagination-controls">
      {#if data.page > 1}
        <a class="button ghost" href="?page={data.page - 1}">← Prev</a>
      {/if}
      <span class="pagination-pages">Page {data.page} of {data.totalPages}</span>
      {#if data.page < data.totalPages}
        <a class="button ghost" href="?page={data.page + 1}">Next →</a>
      {/if}
    </div>
  </div>
{/if}

{#if showDeleteAllConfirm}
  <div role="button" tabindex="0" aria-label="Close dialog" style="position:fixed;inset:0;z-index:100;background:rgba(0,0,0,0.4);display:flex;align-items:center;justify-content:center;padding:16px;cursor:default;" on:click={() => showDeleteAllConfirm = false} on:keydown={(e) => e.key === 'Escape' && (showDeleteAllConfirm = false)}>
    <div role="dialog" aria-modal="true" tabindex="-1" class="card" style="width:min(420px,100%);padding:24px;cursor:default;" on:click|stopPropagation>
      <h3 style="margin:0 0 8px;font-size:18px;">Delete All Recipes?</h3>
      <p class="muted" style="margin:0 0 20px;">This will permanently remove <strong>{data.recipes.length}</strong> recipes from the database. This action cannot be undone.</p>
      <div style="display:flex;gap:12px;justify-content:flex-end;">
        <button class="ghost" type="button" on:click={() => showDeleteAllConfirm = false}>Cancel</button>
        <form method="POST" action="?/deleteAllRecipes">
          <button class="danger" type="submit">Yes, Delete All</button>
        </form>
      </div>
    </div>
  </div>
{/if}

{#if filteredRecipes.length === 0}
  <div class="empty-state">
    <h3>No recipes found</h3>
    <p class="muted">Try adjusting your search or filters, or create a new recipe.</p>
  </div>
{:else}
  <div class="card-grid">
    {#each filteredRecipes as recipe}
      <div class="recipe-card">
        {#if recipe.image_url}
          <img class="recipe-card-image" src={recipe.image_url} alt={recipe.title} loading="lazy" />
        {:else}
          <div class="recipe-card-image" style="display:flex;align-items:center;justify-content:center;color:var(--text-muted);font-size:13px;">
            No image
          </div>
        {/if}

        <div class="recipe-card-body">
          <div class="recipe-card-meta">
            {#if recipe.is_premium}
              <span class="badge premium">Premium</span>
            {:else}
              <span class="badge">Free</span>
            {/if}
            <span class="badge info">{recipe.difficulty || 'easy'}</span>
            <span class="muted" style="font-size:12px;">{formatTime(recipe.prep_time_minutes, recipe.cook_time_minutes)}</span>
          </div>

          <h3 class="recipe-card-title">{recipe.title}</h3>
          <p class="muted" style="font-size:13px;margin-bottom:var(--space-3);">{recipe.category}</p>

          <div class="recipe-card-actions">
            <a class="button" href="/recipes/{recipe.id}/edit">Edit</a>

            <form method="POST" action="?/togglePremium">
              <input type="hidden" name="recipeId" value={recipe.id} />
              <input type="hidden" name="current" value={recipe.is_premium ? 'true' : 'false'} />
              <button class="ghost" type="submit">
                {recipe.is_premium ? 'Make Free' : 'Make Premium'}
              </button>
            </form>

            <form method="POST" action="?/deleteRecipe">
              <input type="hidden" name="recipeId" value={recipe.id} />
              <button class="danger" type="submit">Delete</button>
            </form>
          </div>
        </div>
      </div>
    {/each}
  </div>
{/if}
