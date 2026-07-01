import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';
import {
  buildRecipePayload,
  buildSearchText,
  createRecipeDocument,
  parseEnglishKeywords,
  parseIngredients,
  parseNutrition,
  resolveMainImageUrl,
  resolveRecipeSteps
} from '$lib/server/recipes';
import { ensureAppwriteReady, filterDataForCollection, formatAdminError } from '$lib/server/appwrite';

export const actions: Actions = {
  default: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const title = String(formData.get('title') ?? '').trim();
      const category = String(formData.get('category') ?? '').trim();
      const description = String(formData.get('description') ?? '').trim();
      const difficulty = String(formData.get('difficulty') ?? 'easy').trim().toLowerCase();
      const englishKeywordsRaw = String(formData.get('englishKeywords') ?? '').trim();
      const ingredientsRaw = String(formData.get('ingredients') ?? '').trim();
      const stepsRaw = String(formData.get('steps') ?? '').trim();

      if (!title || !category || !description) {
        return fail(400, { error: 'Title, category and description are required.' });
      }

      if (!['easy', 'medium', 'hard'].includes(difficulty)) {
        return fail(400, { error: 'Difficulty must be one of: easy, medium, hard.' });
      }

      let ingredients;
      let steps;
      try {
        ingredients = parseIngredients(ingredientsRaw);
        steps = await resolveRecipeSteps(formData, stepsRaw);
      } catch (error) {
        return fail(400, { error: formatAdminError(error) });
      }

      const nutrition = parseNutrition(formData);
      const nutritionJson = JSON.stringify(nutrition ?? {});
      const ingredientsJson = JSON.stringify(ingredients);
      const stepsJson = JSON.stringify(steps);
      const englishKeywords = parseEnglishKeywords(englishKeywordsRaw);
      const searchText = buildSearchText({ title, category, description, englishKeywords });
      const imageUrl = await resolveMainImageUrl(formData);

      const candidatePayload = buildRecipePayload(
        formData,
        imageUrl,
        ingredientsJson,
        stepsJson,
        nutritionJson,
        englishKeywords,
        searchText
      );

      const payload = await filterDataForCollection('recipes', candidatePayload);
      await createRecipeDocument(payload);

      throw redirect(303, '/recipes');
    } catch (error) {
      if (error instanceof Response) throw error;
      return fail(500, { error: formatAdminError(error) });
    }
  }
};
