<script lang="ts">
  export let data: {
    recipe: Record<string, any> | null;
    loadError: string | null;
  };

  export let form:
    | {
        error?: string;
      }
    | undefined;

  type IngredientDraft = { name: string; amount: string; unit: string };
  type StepDraft = { description: string; imageUrl: string; timerSeconds: string };

  function parseArray(raw: unknown) {
    if (Array.isArray(raw)) return raw;
    if (typeof raw === 'string' && raw.trim()) {
      try { const d = JSON.parse(raw); if (Array.isArray(d)) return d; } catch { /*ignore*/ }
    }
    return [];
  }

  function parseIngredientsFromRecipe() {
    if (!data.recipe) return [{ name: '', amount: '', unit: '' }];
    const list = parseArray(data.recipe.ingredients_json ?? data.recipe.ingredients);
    if (list.length === 0) return [{ name: '', amount: '', unit: '' }];
    return list.map((entry: any) => ({
      name: String(entry.name ?? ''),
      amount: String(entry.amount ?? ''),
      unit: String(entry.unit ?? '')
    }));
  }

  function parseStepsFromRecipe() {
    if (!data.recipe) return [{ description: '', imageUrl: '', timerSeconds: '' }];
    const list = parseArray(data.recipe.steps_json ?? data.recipe.steps);
    if (list.length === 0) return [{ description: '', imageUrl: '', timerSeconds: '' }];
    return list.map((entry: any) => ({
      description: String(entry.description ?? ''),
      imageUrl: String(entry.image_url ?? ''),
      timerSeconds: String(entry.timer_seconds ?? '')
    }));
  }

  function parseKeywords() {
    if (!data.recipe) return '';
    const raw = data.recipe.english_keywords;
    if (Array.isArray(raw)) return raw.map(String).filter(Boolean).join(', ');
    if (typeof raw === 'string') return raw;
    return '';
  }

  function parseNutritionValue(key: string) {
    if (!data.recipe) return '';
    const raw = data.recipe.nutrition_json ?? data.recipe.nutrition;
    if (typeof raw === 'string' && raw.trim()) {
      try { const obj = JSON.parse(raw); return String(obj[key] ?? ''); } catch { /*ignore*/ }
    }
    if (raw && typeof raw === 'object') return String((raw as any)[key] ?? '');
    return '';
  }

  let ingredients: IngredientDraft[] = parseIngredientsFromRecipe();
  let steps: StepDraft[] = parseStepsFromRecipe();
  let imagePreview: string | null = data.recipe?.image_url ?? null;

  $: ingredientsText = ingredients
    .map((ing) => `${ing.name} | ${ing.amount} | ${ing.unit}`)
    .join('\n');

  function addIngredient() {
    ingredients = [...ingredients, { name: '', amount: '', unit: '' }];
  }

  function removeIngredient(index: number) {
    if (ingredients.length === 1) {
      ingredients = [{ name: '', amount: '', unit: '' }];
      return;
    }
    ingredients = ingredients.filter((_, i) => i !== index);
  }

  function addStep() {
    steps = [...steps, { description: '', imageUrl: '', timerSeconds: '' }];
  }

  function removeStep(index: number) {
    if (steps.length === 1) {
      steps = [{ description: '', imageUrl: '', timerSeconds: '' }];
      return;
    }
    steps = steps.filter((_, i) => i !== index);
  }

  function handleImageChange(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (file) {
      imagePreview = URL.createObjectURL(file);
    }
  }
</script>

<svelte:head>
  <title>Edit Recipe — Amttai Admin</title>
</svelte:head>

<div class="toolbar" style="margin-bottom: var(--space-5);">
  <a class="button ghost" href="/recipes">Back to Recipes</a>
</div>

<h1 class="page-title">Edit Recipe</h1>
<p class="page-subtitle">Update recipe details, ingredients, steps, and media.</p>

{#if data.loadError}
  <p class="flash err">{data.loadError}</p>
{/if}

{#if form?.error}
  <p class="flash err">{form.error}</p>
{/if}

{#if data.recipe}
  <form method="POST" enctype="multipart/form-data">
    <input type="hidden" name="steps" value="" />

    <!-- Section 1: Basic Info -->
    <div class="form-section">
      <div class="form-section-header">
        <div class="form-section-title"><span class="num">1</span> Basic Information</div>
      </div>
      <div class="form-section-body">
        <div class="form-grid">
          <div class="field">
            <label for="title">Recipe Title</label>
            <input id="title" name="title" value={data.recipe.title || ''} placeholder="e.g. Traditional Buuz" required />
          </div>
          <div class="field">
            <label for="category">Category</label>
            <input id="category" name="category" value={data.recipe.category || ''} placeholder="e.g. Dumplings" required />
          </div>
          <div class="field">
            <label for="difficulty">Difficulty</label>
            <select id="difficulty" name="difficulty">
              <option value="easy" selected={data.recipe.difficulty === 'easy'}>Easy</option>
              <option value="medium" selected={data.recipe.difficulty === 'medium'}>Medium</option>
              <option value="hard" selected={data.recipe.difficulty === 'hard'}>Hard</option>
            </select>
          </div>
          <div class="field">
            <label for="servings">Servings</label>
            <input id="servings" name="servings" type="number" min="1" value={data.recipe.servings || 2} />
          </div>
          <div class="field">
            <label for="prepTimeMinutes">Prep Time (min)</label>
            <input id="prepTimeMinutes" name="prepTimeMinutes" type="number" min="0" value={data.recipe.prep_time_minutes || 0} />
          </div>
          <div class="field">
            <label for="cookTimeMinutes">Cook Time (min)</label>
            <input id="cookTimeMinutes" name="cookTimeMinutes" type="number" min="0" value={data.recipe.cook_time_minutes || 0} />
          </div>
        </div>
        <div class="field" style="margin-top: var(--space-4);">
          <label for="description">Description</label>
          <textarea id="description" name="description" rows="4" placeholder="Describe the dish..." required>{data.recipe.description || ''}</textarea>
        </div>
      </div>
    </div>

    <!-- Section 2: Media -->
    <div class="form-section">
      <div class="form-section-header">
        <div class="form-section-title"><span class="num">2</span> Media</div>
      </div>
      <div class="form-section-body">
        <div class="form-grid">
          <div class="field">
            <label for="imageFile">Main Image</label>
            {#if imagePreview}
              <img class="image-preview" src={imagePreview} alt="Preview" />
            {:else}
              <div class="image-upload" style="padding: var(--space-6) 0;">
                <p class="muted" style="font-size: 13px;">Upload a main recipe photo</p>
              </div>
            {/if}
            <input id="imageFile" name="imageFile" type="file" accept="image/*" on:change={handleImageChange} />
          </div>
          <div class="field">
            <label for="imageUrl">Or Image URL</label>
            <input id="imageUrl" name="imageUrl" type="url" placeholder="https://..." value={data.recipe.image_url || ''} />
            <p class="field-hint">Used if no file is uploaded.</p>
          </div>
          <div class="field">
            <label for="videoUrl">Video URL</label>
            <input id="videoUrl" name="videoUrl" type="url" placeholder="https://..." value={data.recipe.video_url || ''} />
          </div>
        </div>
      </div>
    </div>

    <!-- Section 3: Ingredients -->
    <div class="form-section">
      <div class="form-section-header">
        <div class="form-section-title"><span class="num">3</span> Ingredients</div>
        <button type="button" class="primary" on:click={addIngredient}>+ Add Ingredient</button>
      </div>
      <div class="form-section-body">
        {#each ingredients as ing, index}
          <div class="dynamic-row">
            <div class="field" style="margin-bottom:0;">
              <label for="ing-name-{index}" style="font-size:11px;">Name</label>
              <input id="ing-name-{index}" name="ingredientName" value={ing.name} placeholder="Beef" required />
            </div>
            <div class="field" style="margin-bottom:0;">
              <label for="ing-amount-{index}" style="font-size:11px;">Amount</label>
              <input id="ing-amount-{index}" name="ingredientAmount" value={ing.amount} placeholder="500" required />
            </div>
            <div class="field" style="margin-bottom:0;">
              <label for="ing-unit-{index}" style="font-size:11px;">Unit</label>
              <input id="ing-unit-{index}" name="ingredientUnit" value={ing.unit} placeholder="g" />
            </div>
            <button type="button" class="danger" on:click={() => removeIngredient(index)} title="Remove">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6 6 18M6 6l12 12"/></svg>
            </button>
          </div>
        {/each}
        <textarea name="ingredients" style="display:none;" required>{ingredientsText}</textarea>
      </div>
    </div>

    <!-- Section 4: Steps -->
    <div class="form-section">
      <div class="form-section-header">
        <div class="form-section-title"><span class="num">4</span> Cooking Steps</div>
        <button type="button" class="primary" on:click={addStep}>+ Add Step</button>
      </div>
      <div class="form-section-body">
        {#each steps as step, index}
          <div class="step-card">
            <div class="step-card-header">
              <div style="display:flex;align-items:center;gap:var(--space-2);">
                <span class="step-number">{index + 1}</span>
                <span style="font-weight:600;">Step {index + 1}</span>
              </div>
              <button type="button" class="ghost" on:click={() => removeStep(index)} aria-label="Remove step">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6 6 18M6 6l12 12"/></svg>
              </button>
            </div>
            <div class="field" style="margin-bottom:0;">
              <label for={'step-desc-' + index}>Description</label>
              <textarea id={'step-desc-' + index} name="stepDescription" rows="2" placeholder="Describe this cooking step..." required>{step.description}</textarea>
            </div>
            <div class="form-grid" style="margin-top: var(--space-3);">
              <div class="field" style="margin-bottom:0;">
                <label for={'step-img-' + index}>Image URL</label>
                <input id={'step-img-' + index} name="stepImageUrl" type="url" placeholder="https://..." value={step.imageUrl} />
              </div>
              <div class="field" style="margin-bottom:0;">
                <label for={'step-file-' + index}>Upload Image</label>
                <input id={'step-file-' + index} name="stepImageFile" type="file" accept="image/*" />
              </div>
              <div class="field" style="margin-bottom:0;">
                <label for={'step-timer-' + index}>Timer (seconds)</label>
                <input id={'step-timer-' + index} name="stepTimerSeconds" type="number" min="0" placeholder="300" value={step.timerSeconds} />
              </div>
            </div>
          </div>
        {/each}
      </div>
    </div>

    <!-- Section 5: Nutrition -->
    <div class="form-section">
      <div class="form-section-header">
        <div class="form-section-title"><span class="num">5</span> Nutrition (per serving)</div>
      </div>
      <div class="form-section-body">
        <div class="form-grid form-grid-4">
          <div class="field">
            <label for="nutritionCalories">Calories</label>
            <input id="nutritionCalories" name="nutritionCalories" type="number" min="0" value={parseNutritionValue('calories')} />
          </div>
          <div class="field">
            <label for="nutritionProtein">Protein (g)</label>
            <input id="nutritionProtein" name="nutritionProtein" type="number" min="0" step="0.1" value={parseNutritionValue('protein')} />
          </div>
          <div class="field">
            <label for="nutritionCarbs">Carbs (g)</label>
            <input id="nutritionCarbs" name="nutritionCarbs" type="number" min="0" step="0.1" value={parseNutritionValue('carbs')} />
          </div>
          <div class="field">
            <label for="nutritionFat">Fat (g)</label>
            <input id="nutritionFat" name="nutritionFat" type="number" min="0" step="0.1" value={parseNutritionValue('fat')} />
          </div>
        </div>
      </div>
    </div>

    <!-- Section 6: Keywords & Access -->
    <div class="form-section">
      <div class="form-section-header">
        <div class="form-section-title"><span class="num">6</span> Keywords & Access</div>
      </div>
      <div class="form-section-body">
        <div class="form-grid">
          <div class="field" style="grid-column: 1 / -1;">
            <label for="englishKeywords">English Keywords</label>
            <textarea id="englishKeywords" name="englishKeywords" rows="2" placeholder="dumpling, steamed, buuz, mongolian">{parseKeywords()}</textarea>
            <p class="field-hint">Comma or line separated. Used for search indexing.</p>
          </div>
          <div class="field">
            <label for="isPremium">Access Level</label>
            <select id="isPremium" name="isPremium">
              <option value="false" selected={!data.recipe.is_premium}>Free</option>
              <option value="true" selected={!!data.recipe.is_premium}>Premium</option>
            </select>
          </div>
        </div>
      </div>
    </div>

    <div class="toolbar" style="justify-content: flex-start;">
      <button type="submit" class="primary" style="padding: 12px 28px; font-size: 15px;">Save Changes</button>
      <a class="button" href="/recipes">Cancel</a>
    </div>
  </form>
{/if}
