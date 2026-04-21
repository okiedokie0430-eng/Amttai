<script lang="ts">
  export let data: {
    loadError: string | null;
    recipes: Array<Record<string, any>>;
  };

  export let form:
    | {
        message?: string;
        error?: string;
      }
    | undefined;

  type StepDraft = {
    description: string;
    imageUrl: string;
    timerSeconds: string;
  };

  function parseArray(raw: unknown) {
    if (Array.isArray(raw)) {
      return raw;
    }

    if (typeof raw === 'string' && raw.trim()) {
      try {
        const decoded = JSON.parse(raw);
        if (Array.isArray(decoded)) {
          return decoded;
        }
      } catch {
        return [];
      }
    }

    return [];
  }

  function parseObject(raw: unknown) {
    if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
      return raw as Record<string, any>;
    }

    if (typeof raw === 'string' && raw.trim()) {
      try {
        const decoded = JSON.parse(raw);
        if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) {
          return decoded as Record<string, any>;
        }
      } catch {
        return {};
      }
    }

    return {};
  }

  function ingredientsToText(recipe: Record<string, any>) {
    const list = parseArray(recipe.ingredients_json ?? recipe.ingredients);
    return list
      .map((entry) => {
        const item = entry as Record<string, any>;
        const name = String(item.name ?? '').trim();
        const amount = String(item.amount ?? '').trim();
        const unit = String(item.unit ?? '').trim();
        return [name, amount, unit].join(' | ').trim();
      })
      .filter(Boolean)
      .join('\n');
  }

  function nutritionValue(recipe: Record<string, any>, key: string) {
    const info = parseObject(recipe.nutrition_json ?? recipe.nutrition);
    return info[key] ?? '';
  }

  function englishKeywordsToText(recipe: Record<string, any>) {
    const raw = recipe.english_keywords;
    if (Array.isArray(raw)) {
      return raw.map((item) => String(item).trim()).filter(Boolean).join(', ');
    }

    if (typeof raw === 'string') {
      return raw;
    }

    return '';
  }

  function createBlankStep(): StepDraft {
    return {
      description: '',
      imageUrl: '',
      timerSeconds: ''
    };
  }

  function parseStepDrafts(recipe: Record<string, any>) {
    const list = parseArray(recipe.steps_json ?? recipe.steps);
    const drafts = list
      .map((entry) => {
        const item = entry as Record<string, any>;
        return {
          description: String(item.description ?? '').trim(),
          imageUrl: String(item.image_url ?? '').trim(),
          timerSeconds: String(item.timer_seconds ?? '').trim()
        } satisfies StepDraft;
      })
      .filter((step) => step.description || step.imageUrl || step.timerSeconds);

    return drafts.length > 0 ? drafts : [createBlankStep()];
  }

  let createStepDrafts: StepDraft[] = [createBlankStep()];
  let editStepDraftsByRecipe: Record<string, StepDraft[]> = {};

  function updateCreateStep(index: number, key: keyof StepDraft, value: string) {
    const next = [...createStepDrafts];
    next[index] = { ...next[index], [key]: value };
    createStepDrafts = next;
  }

  function addCreateStep() {
    createStepDrafts = [...createStepDrafts, createBlankStep()];
  }

  function removeCreateStep(index: number) {
    if (createStepDrafts.length === 1) {
      createStepDrafts = [createBlankStep()];
      return;
    }

    createStepDrafts = createStepDrafts.filter((_, itemIndex) => itemIndex !== index);
  }

  function getEditStepDrafts(recipe: Record<string, any>) {
    const recipeId = String(recipe.id ?? '');

    if (!editStepDraftsByRecipe[recipeId]) {
      editStepDraftsByRecipe = {
        ...editStepDraftsByRecipe,
        [recipeId]: parseStepDrafts(recipe)
      };
    }

    return editStepDraftsByRecipe[recipeId] ?? [createBlankStep()];
  }

  function updateEditStep(recipeId: string, index: number, key: keyof StepDraft, value: string) {
    const current = editStepDraftsByRecipe[recipeId] ?? [createBlankStep()];
    const next = [...current];
    next[index] = { ...next[index], [key]: value };

    editStepDraftsByRecipe = {
      ...editStepDraftsByRecipe,
      [recipeId]: next
    };
  }

  function addEditStep(recipeId: string) {
    const current = editStepDraftsByRecipe[recipeId] ?? [createBlankStep()];
    editStepDraftsByRecipe = {
      ...editStepDraftsByRecipe,
      [recipeId]: [...current, createBlankStep()]
    };
  }

  function removeEditStep(recipeId: string, index: number) {
    const current = editStepDraftsByRecipe[recipeId] ?? [createBlankStep()];

    if (current.length === 1) {
      editStepDraftsByRecipe = {
        ...editStepDraftsByRecipe,
        [recipeId]: [createBlankStep()]
      };
      return;
    }

    editStepDraftsByRecipe = {
      ...editStepDraftsByRecipe,
      [recipeId]: current.filter((_, itemIndex) => itemIndex !== index)
    };
  }
</script>

<svelte:head>
  <title>Recipes - Admin</title>
</svelte:head>

<h1 class="page-title">Recipes</h1>

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
  <h3 style="margin: 0 0 8px;">Create Detailed Recipe</h3>
  <p class="muted" style="margin: 0 0 14px; font-size: 13px;">
    Include rich instructions, ingredient list, nutrition values, and searchable English keywords.
    Ingredient format: <strong>name | amount | unit</strong> per line.
    Steps now support individual fields and optional image upload for each step.
  </p>
  <form method="POST" action="?/createRecipe" class="form-grid" enctype="multipart/form-data">
    <div>
      <label for="title">Title</label>
      <input id="title" name="title" required />
    </div>
    <div>
      <label for="category">Category</label>
      <input id="category" name="category" required />
    </div>
    <div>
      <label for="difficulty">Difficulty</label>
      <select id="difficulty" name="difficulty">
        <option value="easy">Easy</option>
        <option value="medium">Medium</option>
        <option value="hard">Hard</option>
      </select>
    </div>
    <div>
      <label for="isPremium">Access</label>
      <select id="isPremium" name="isPremium">
        <option value="false">Free</option>
        <option value="true">Premium</option>
      </select>
    </div>
    <div>
      <label for="servings">Servings</label>
      <input id="servings" name="servings" type="number" min="1" value="2" />
    </div>
    <div>
      <label for="prepTimeMinutes">Prep Time (minutes)</label>
      <input id="prepTimeMinutes" name="prepTimeMinutes" type="number" min="0" value="15" />
    </div>
    <div>
      <label for="cookTimeMinutes">Cook Time (minutes)</label>
      <input id="cookTimeMinutes" name="cookTimeMinutes" type="number" min="0" value="30" />
    </div>
    <div>
      <label for="imageUrl">Main Image URL (optional)</label>
      <input id="imageUrl" name="imageUrl" type="url" placeholder="https://..." />
    </div>
    <div>
      <label for="imageFile">Upload Main Image (optional)</label>
      <input id="imageFile" name="imageFile" type="file" accept="image/*" />
    </div>
    <div>
      <label for="videoUrl">Video URL (optional)</label>
      <input id="videoUrl" name="videoUrl" type="url" placeholder="https://..." />
    </div>
    <div style="grid-column: 1 / -1;">
      <label for="englishKeywords">English Keywords (comma or line separated)</label>
      <textarea
        id="englishKeywords"
        name="englishKeywords"
        rows="2"
        placeholder="dumpling, steamed, buuz"
      ></textarea>
    </div>
    <div style="grid-column: 1 / -1;">
      <label for="description">Description</label>
      <textarea
        id="description"
        name="description"
        rows="4"
        required
        placeholder="Write a complete recipe description, context, and cooking notes."
      ></textarea>
    </div>
    <div style="grid-column: 1 / -1;">
      <label for="ingredients">Ingredients (required)</label>
      <textarea
        id="ingredients"
        name="ingredients"
        rows="6"
        required
        placeholder="Beef | 500 | g&#10;Onion | 2 | pcs&#10;Salt | 1 | tsp"
      ></textarea>
    </div>

    <input type="hidden" name="steps" value="" />
    <div style="grid-column: 1 / -1;">
      <p style="margin: 0; font-weight: 600;">Steps (required)</p>
      <p class="muted" style="margin: 4px 0 8px; font-size: 12px;">
        Each step can have text, timer, and either an image URL or uploaded image.
      </p>

      {#each createStepDrafts as step, index}
        <div class="card" style="margin-bottom: 10px; padding: 12px;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
            <strong>Step {index + 1}</strong>
            <button type="button" on:click={() => removeCreateStep(index)} disabled={createStepDrafts.length === 1}>
              Remove
            </button>
          </div>

          <div class="form-grid" style="grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));">
            <div style="grid-column: 1 / -1;">
              <label for={'create-step-description-' + index}>Description</label>
              <textarea
                id={'create-step-description-' + index}
                name="stepDescription"
                rows="2"
                placeholder="Describe this cooking step"
                on:input={(event) => updateCreateStep(index, 'description', (event.currentTarget as HTMLTextAreaElement).value)}
              >{step.description}</textarea>
            </div>
            <div>
              <label for={'create-step-image-url-' + index}>Image URL (optional)</label>
              <input
                id={'create-step-image-url-' + index}
                name="stepImageUrl"
                type="url"
                placeholder="https://..."
                value={step.imageUrl}
                on:input={(event) => updateCreateStep(index, 'imageUrl', (event.currentTarget as HTMLInputElement).value)}
              />
            </div>
            <div>
              <label for={'create-step-image-file-' + index}>Upload Image (optional)</label>
              <input id={'create-step-image-file-' + index} name="stepImageFile" type="file" accept="image/*" />
            </div>
            <div>
              <label for={'create-step-timer-' + index}>Timer Seconds (optional)</label>
              <input
                id={'create-step-timer-' + index}
                name="stepTimerSeconds"
                type="number"
                min="0"
                step="1"
                value={step.timerSeconds}
                on:input={(event) => updateCreateStep(index, 'timerSeconds', (event.currentTarget as HTMLInputElement).value)}
              />
            </div>
          </div>
        </div>
      {/each}

      <button type="button" on:click={addCreateStep}>Add Step</button>
    </div>

    <div>
      <label for="nutritionCalories">Calories</label>
      <input id="nutritionCalories" name="nutritionCalories" type="number" min="0" step="1" />
    </div>
    <div>
      <label for="nutritionProtein">Protein (g)</label>
      <input id="nutritionProtein" name="nutritionProtein" type="number" min="0" step="0.1" />
    </div>
    <div>
      <label for="nutritionCarbs">Carbs (g)</label>
      <input id="nutritionCarbs" name="nutritionCarbs" type="number" min="0" step="0.1" />
    </div>
    <div>
      <label for="nutritionFat">Fat (g)</label>
      <input id="nutritionFat" name="nutritionFat" type="number" min="0" step="0.1" />
    </div>
    <div>
      <button class="primary" type="submit">Create</button>
    </div>
  </form>
</section>

<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>Title</th>
        <th>Category</th>
        <th>Time</th>
        <th>Premium</th>
        <th>Rating</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      {#each data.recipes as recipe}
        {@const recipeId = String(recipe.id)}
        {@const editStepDrafts = getEditStepDrafts(recipe)}

        <tr>
          <td>{recipe.title}</td>
          <td>{recipe.category}</td>
          <td>{recipe.prep_time_minutes || 0}m + {recipe.cook_time_minutes || 0}m</td>
          <td>
            {#if recipe.is_premium}
              <span class="badge ok">Premium</span>
            {:else}
              <span class="badge">Free</span>
            {/if}
          </td>
          <td>{recipe.average_rating || 0} ({recipe.total_ratings || 0})</td>
          <td>
            <div class="actions">
              <form method="POST" action="?/togglePremium">
                <input type="hidden" name="recipeId" value={recipe.id} />
                <input type="hidden" name="current" value={recipe.is_premium ? 'true' : 'false'} />
                <button type="submit">Toggle Premium</button>
              </form>

              <form method="POST" action="?/deleteRecipe">
                <input type="hidden" name="recipeId" value={recipe.id} />
                <button class="danger" type="submit">Delete</button>
              </form>
            </div>
          </td>
        </tr>
        <tr>
          <td colspan="6" style="background: var(--surface-elevated, #f9fafb);">
            <details>
              <summary style="cursor: pointer; font-weight: 600;">Edit Recipe</summary>
              <form
                method="POST"
                action="?/updateRecipe"
                class="form-grid"
                style="margin-top: 12px;"
                enctype="multipart/form-data"
              >
                <input type="hidden" name="recipeId" value={recipe.id} />
                <input type="hidden" name="steps" value="" />

                <div>
                  <label for={'edit-title-' + recipe.id}>Title</label>
                  <input id={'edit-title-' + recipe.id} name="title" value={recipe.title || ''} required />
                </div>
                <div>
                  <label for={'edit-category-' + recipe.id}>Category</label>
                  <input id={'edit-category-' + recipe.id} name="category" value={recipe.category || ''} required />
                </div>
                <div>
                  <label for={'edit-difficulty-' + recipe.id}>Difficulty</label>
                  <select id={'edit-difficulty-' + recipe.id} name="difficulty">
                    <option value="easy" selected={recipe.difficulty === 'easy'}>Easy</option>
                    <option value="medium" selected={recipe.difficulty === 'medium'}>Medium</option>
                    <option value="hard" selected={recipe.difficulty === 'hard'}>Hard</option>
                  </select>
                </div>
                <div>
                  <label for={'edit-premium-' + recipe.id}>Access</label>
                  <select id={'edit-premium-' + recipe.id} name="isPremium">
                    <option value="false" selected={!recipe.is_premium}>Free</option>
                    <option value="true" selected={!!recipe.is_premium}>Premium</option>
                  </select>
                </div>
                <div>
                  <label for={'edit-servings-' + recipe.id}>Servings</label>
                  <input
                    id={'edit-servings-' + recipe.id}
                    name="servings"
                    type="number"
                    min="1"
                    value={recipe.servings || 1}
                    required
                  />
                </div>
                <div>
                  <label for={'edit-prep-' + recipe.id}>Prep Time (minutes)</label>
                  <input
                    id={'edit-prep-' + recipe.id}
                    name="prepTimeMinutes"
                    type="number"
                    min="0"
                    value={recipe.prep_time_minutes || 0}
                    required
                  />
                </div>
                <div>
                  <label for={'edit-cook-' + recipe.id}>Cook Time (minutes)</label>
                  <input
                    id={'edit-cook-' + recipe.id}
                    name="cookTimeMinutes"
                    type="number"
                    min="0"
                    value={recipe.cook_time_minutes || 0}
                    required
                  />
                </div>
                <div>
                  <label for={'edit-image-url-' + recipe.id}>Main Image URL</label>
                  <input id={'edit-image-url-' + recipe.id} name="imageUrl" type="url" value={recipe.image_url || ''} />
                </div>
                <div>
                  <label for={'edit-image-file-' + recipe.id}>Replace Main Image</label>
                  <input id={'edit-image-file-' + recipe.id} name="imageFile" type="file" accept="image/*" />
                </div>
                <div>
                  <label for={'edit-video-url-' + recipe.id}>Video URL</label>
                  <input id={'edit-video-url-' + recipe.id} name="videoUrl" type="url" value={recipe.video_url || ''} />
                </div>
                <div style="grid-column: 1 / -1;">
                  <label for={'edit-keywords-' + recipe.id}>English Keywords</label>
                  <textarea id={'edit-keywords-' + recipe.id} name="englishKeywords" rows="2">{englishKeywordsToText(recipe)}</textarea>
                </div>
                <div style="grid-column: 1 / -1;">
                  <label for={'edit-description-' + recipe.id}>Description</label>
                  <textarea id={'edit-description-' + recipe.id} name="description" rows="4" required>{recipe.description || ''}</textarea>
                </div>
                <div style="grid-column: 1 / -1;">
                  <label for={'edit-ingredients-' + recipe.id}>Ingredients</label>
                  <textarea id={'edit-ingredients-' + recipe.id} name="ingredients" rows="6" required>{ingredientsToText(recipe)}</textarea>
                </div>

                <div style="grid-column: 1 / -1;">
                  <p style="margin: 0; font-weight: 600;">Steps</p>
                  <p class="muted" style="margin: 4px 0 8px; font-size: 12px;">
                    Update each step individually and optionally upload a new image for any step.
                  </p>

                  {#each editStepDrafts as step, index}
                    <div class="card" style="margin-bottom: 10px; padding: 12px;">
                      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                        <strong>Step {index + 1}</strong>
                        <button type="button" on:click={() => removeEditStep(recipeId, index)} disabled={editStepDrafts.length === 1}>
                          Remove
                        </button>
                      </div>

                      <div class="form-grid" style="grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));">
                        <div style="grid-column: 1 / -1;">
                          <label for={'edit-step-description-' + recipe.id + '-' + index}>Description</label>
                          <textarea
                            id={'edit-step-description-' + recipe.id + '-' + index}
                            name="stepDescription"
                            rows="2"
                            on:input={(event) => updateEditStep(recipeId, index, 'description', (event.currentTarget as HTMLTextAreaElement).value)}
                          >{step.description}</textarea>
                        </div>
                        <div>
                          <label for={'edit-step-image-url-' + recipe.id + '-' + index}>Image URL (optional)</label>
                          <input
                            id={'edit-step-image-url-' + recipe.id + '-' + index}
                            name="stepImageUrl"
                            type="url"
                            value={step.imageUrl}
                            on:input={(event) => updateEditStep(recipeId, index, 'imageUrl', (event.currentTarget as HTMLInputElement).value)}
                          />
                        </div>
                        <div>
                          <label for={'edit-step-image-file-' + recipe.id + '-' + index}>Upload Image (optional)</label>
                          <input id={'edit-step-image-file-' + recipe.id + '-' + index} name="stepImageFile" type="file" accept="image/*" />
                        </div>
                        <div>
                          <label for={'edit-step-timer-' + recipe.id + '-' + index}>Timer Seconds (optional)</label>
                          <input
                            id={'edit-step-timer-' + recipe.id + '-' + index}
                            name="stepTimerSeconds"
                            type="number"
                            min="0"
                            step="1"
                            value={step.timerSeconds}
                            on:input={(event) => updateEditStep(recipeId, index, 'timerSeconds', (event.currentTarget as HTMLInputElement).value)}
                          />
                        </div>
                      </div>
                    </div>
                  {/each}

                  <button type="button" on:click={() => addEditStep(recipeId)}>Add Step</button>
                </div>

                <div>
                  <label for={'edit-calories-' + recipe.id}>Calories</label>
                  <input
                    id={'edit-calories-' + recipe.id}
                    name="nutritionCalories"
                    type="number"
                    min="0"
                    step="1"
                    value={nutritionValue(recipe, 'calories')}
                  />
                </div>
                <div>
                  <label for={'edit-protein-' + recipe.id}>Protein (g)</label>
                  <input
                    id={'edit-protein-' + recipe.id}
                    name="nutritionProtein"
                    type="number"
                    min="0"
                    step="0.1"
                    value={nutritionValue(recipe, 'protein')}
                  />
                </div>
                <div>
                  <label for={'edit-carbs-' + recipe.id}>Carbs (g)</label>
                  <input
                    id={'edit-carbs-' + recipe.id}
                    name="nutritionCarbs"
                    type="number"
                    min="0"
                    step="0.1"
                    value={nutritionValue(recipe, 'carbs')}
                  />
                </div>
                <div>
                  <label for={'edit-fat-' + recipe.id}>Fat (g)</label>
                  <input
                    id={'edit-fat-' + recipe.id}
                    name="nutritionFat"
                    type="number"
                    min="0"
                    step="0.1"
                    value={nutritionValue(recipe, 'fat')}
                  />
                </div>
                <div>
                  <button class="primary" type="submit">Save Changes</button>
                </div>
              </form>
            </details>
          </td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
