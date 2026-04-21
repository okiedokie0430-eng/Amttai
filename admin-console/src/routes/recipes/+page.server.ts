import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { Query } from 'node-appwrite';
import { InputFile } from 'node-appwrite/file';
import {
  bucketIds,
  buildStorageFileViewUrl,
  collectionIds,
  databaseId,
  databases,
  ensureAppwriteReady,
  filterDataForCollection,
  formatAdminError,
  mapDocumentWithId,
  storage
} from '$lib/server/appwrite';

type RecipeIngredient = {
  name: string;
  amount: string;
  unit?: string;
};

type RecipeStep = {
  order: number;
  description: string;
  image_url?: string;
  timer_seconds?: number;
};

type RecipeNutrition = {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
};

function parseEnglishKeywords(raw: string) {
  return raw
    .split(/[\n,]/)
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

function buildSearchText({
  title,
  category,
  description,
  englishKeywords
}: {
  title: string;
  category: string;
  description: string;
  englishKeywords: string[];
}) {
  return Array.from(
    new Set(
      [title, category, description, ...englishKeywords]
        .map((item) => item.trim().toLowerCase())
        .filter(Boolean)
    )
  ).join(' ');
}

function toPositiveInt(value: FormDataEntryValue | null, fallback: number, min = 0) {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.max(min, Math.round(parsed));
}

function normalizeLines(input: string) {
  return input
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function parseJsonArray(raw: string) {
  if (!raw.trim().startsWith('[')) {
    return null;
  }

  const parsed = JSON.parse(raw) as unknown;
  if (!Array.isArray(parsed)) {
    throw new Error('JSON input must be an array.');
  }

  return parsed;
}

function parseIngredients(raw: string) {
  const text = raw.trim();
  if (!text) {
    throw new Error('At least one ingredient is required.');
  }

  const jsonArray = parseJsonArray(text);
  if (jsonArray) {
    const normalized = jsonArray.map((entry, index) => {
      if (!entry || typeof entry !== 'object') {
        throw new Error(`Ingredient ${index + 1} is invalid.`);
      }

      const item = entry as Record<string, unknown>;
      const name = String(item.name ?? '').trim();
      const amount = String(item.amount ?? '').trim();
      const unit = String(item.unit ?? '').trim();

      if (!name || !amount) {
        throw new Error(`Ingredient ${index + 1} must include name and amount.`);
      }

      return {
        name,
        amount,
        ...(unit ? { unit } : {})
      } satisfies RecipeIngredient;
    });

    if (normalized.length === 0) {
      throw new Error('At least one ingredient is required.');
    }

    return normalized;
  }

  const lines = normalizeLines(text);
  if (lines.length === 0) {
    throw new Error('At least one ingredient is required.');
  }

  return lines.map((line, index) => {
    const [nameRaw = '', amountRaw = '', unitRaw = ''] = line.split('|').map((part) => part.trim());
    const name = nameRaw;
    const amount = amountRaw;
    const unit = unitRaw;

    if (!name || !amount) {
      throw new Error(`Ingredient line ${index + 1} must be in the format: name | amount | unit`);
    }

    return {
      name,
      amount,
      ...(unit ? { unit } : {})
    } satisfies RecipeIngredient;
  });
}

function parseSteps(raw: string) {
  const text = raw.trim();
  if (!text) {
    throw new Error('At least one step is required.');
  }

  const jsonArray = parseJsonArray(text);
  if (jsonArray) {
    const normalized = jsonArray.map((entry, index) => {
      if (!entry || typeof entry !== 'object') {
        throw new Error(`Step ${index + 1} is invalid.`);
      }

      const item = entry as Record<string, unknown>;
      const description = String(item.description ?? '').trim();
      const imageUrl = String(item.image_url ?? '').trim();
      const timerRaw = item.timer_seconds;
      const stepOrder = Number(item.order ?? index + 1);

      if (!description) {
        throw new Error(`Step ${index + 1} must include a description.`);
      }

      const timerSeconds = Number(timerRaw);

      return {
        order: Number.isFinite(stepOrder) && stepOrder > 0 ? Math.round(stepOrder) : index + 1,
        description,
        ...(imageUrl ? { image_url: imageUrl } : {}),
        ...(Number.isFinite(timerSeconds) && timerSeconds > 0
          ? { timer_seconds: Math.round(timerSeconds) }
          : {})
      } satisfies RecipeStep;
    });

    if (normalized.length === 0) {
      throw new Error('At least one step is required.');
    }

    return normalized;
  }

  const lines = normalizeLines(text);
  if (lines.length === 0) {
    throw new Error('At least one step is required.');
  }

  return lines.map((line, index) => {
    const [descriptionRaw = '', imageUrlRaw = '', timerRaw = ''] = line
      .split('|')
      .map((part) => part.trim());

    if (!descriptionRaw) {
      throw new Error(`Step line ${index + 1} must start with a description.`);
    }

    const parsedTimer = Number(timerRaw);

    return {
      order: index + 1,
      description: descriptionRaw,
      ...(imageUrlRaw ? { image_url: imageUrlRaw } : {}),
      ...(Number.isFinite(parsedTimer) && parsedTimer > 0
        ? { timer_seconds: Math.round(parsedTimer) }
        : {})
    } satisfies RecipeStep;
  });
}

function getStringValues(formData: FormData, key: string) {
  return formData.getAll(key).map((value) => (typeof value === 'string' ? value.trim() : ''));
}

function getFileValues(formData: FormData, key: string) {
  return formData
    .getAll(key)
    .map((value) => (value instanceof File ? value : null));
}

async function uploadRecipeImage(uploadedFile: File, fallbackName: string) {
  const arrayBuffer = await uploadedFile.arrayBuffer();
  const fileBuffer = Buffer.from(arrayBuffer);
  const uploaded = await storage.createFile(
    bucketIds.recipeImages,
    'unique()',
    InputFile.fromBuffer(fileBuffer, uploadedFile.name || fallbackName)
  );

  return buildStorageFileViewUrl(bucketIds.recipeImages, uploaded.$id);
}

async function parseStructuredSteps(formData: FormData) {
  const descriptions = getStringValues(formData, 'stepDescription');
  const imageUrls = getStringValues(formData, 'stepImageUrl');
  const timers = getStringValues(formData, 'stepTimerSeconds');
  const imageFiles = getFileValues(formData, 'stepImageFile');

  const rowCount = Math.max(descriptions.length, imageUrls.length, timers.length, imageFiles.length);
  if (rowCount === 0) {
    return null;
  }

  const steps: RecipeStep[] = [];

  for (let index = 0; index < rowCount; index += 1) {
    const description = descriptions[index] ?? '';
    const imageUrlInput = imageUrls[index] ?? '';
    const timerRaw = timers[index] ?? '';
    const imageFile = imageFiles[index];

    let resolvedImageUrl = imageUrlInput;
    if (imageFile instanceof File && imageFile.size > 0) {
      resolvedImageUrl = await uploadRecipeImage(imageFile, `recipe-step-${index + 1}`);
    }

    const parsedTimer = Number(timerRaw);
    const hasTimer = Number.isFinite(parsedTimer) && parsedTimer > 0;
    const hasImage = Boolean(resolvedImageUrl);
    const hasAnyStepData = Boolean(description) || hasTimer || hasImage;

    if (!hasAnyStepData) {
      continue;
    }

    if (!description) {
      throw new Error(`Step ${index + 1} must include a description.`);
    }

    steps.push({
      order: steps.length + 1,
      description,
      ...(hasImage ? { image_url: resolvedImageUrl } : {}),
      ...(hasTimer ? { timer_seconds: Math.round(parsedTimer) } : {})
    } satisfies RecipeStep);
  }

  return steps.length > 0 ? steps : null;
}

async function resolveRecipeSteps(formData: FormData, fallbackRawSteps: string) {
  const structured = await parseStructuredSteps(formData);
  if (structured && structured.length > 0) {
    return structured;
  }

  return parseSteps(fallbackRawSteps);
}

function parseNutrition(formData: FormData) {
  const calories = String(formData.get('nutritionCalories') ?? '').trim();
  const protein = String(formData.get('nutritionProtein') ?? '').trim();
  const carbs = String(formData.get('nutritionCarbs') ?? '').trim();
  const fat = String(formData.get('nutritionFat') ?? '').trim();

  if (!calories && !protein && !carbs && !fat) {
    return null;
  }

  return {
    calories: Math.max(0, Number(calories || 0)),
    protein: Math.max(0, Number(protein || 0)),
    carbs: Math.max(0, Number(carbs || 0)),
    fat: Math.max(0, Number(fat || 0))
  } satisfies RecipeNutrition;
}

async function resolveMainImageUrl(formData: FormData, fallback = '') {
  const imageUrl = String(formData.get('imageUrl') ?? '').trim();
  const uploadedFile = formData.get('imageFile');

  if (uploadedFile instanceof File && uploadedFile.size > 0) {
    return uploadRecipeImage(uploadedFile, 'recipe-image');
  }

  return imageUrl || fallback;
}

async function createRecipeDocument(data: Record<string, any>) {
  let payload = { ...data };

  for (let attempt = 0; attempt < 8; attempt += 1) {
    try {
      return await databases.createDocument(databaseId, collectionIds.recipes, 'unique()', payload);
    } catch (error) {
      const message = formatAdminError(error);
      const unknownAttribute = message.match(/Unknown attribute:\s*"?([a-zA-Z0-9_]+)"?/i)?.[1];

      if (!unknownAttribute || !(unknownAttribute in payload)) {
        throw error;
      }

      delete payload[unknownAttribute];
    }
  }

  throw new Error('Recipe could not be saved because the database schema rejected multiple fields.');
}

export const load: PageServerLoad = async () => {
  try {
    ensureAppwriteReady();

    let result;

    try {
      result = await databases.listDocuments(databaseId, collectionIds.recipes, [
        Query.orderDesc('created_at'),
        Query.limit(200)
      ]);
    } catch {
      // Fall back to Appwrite system timestamp when custom created_at is unavailable.
      result = await databases.listDocuments(databaseId, collectionIds.recipes, [
        Query.orderDesc('$createdAt'),
        Query.limit(200)
      ]);
    }

    const recipes = result.documents.map((doc) => mapDocumentWithId(doc));

    return { recipes, loadError: null };
  } catch (error) {
    return { recipes: [], loadError: formatAdminError(error) };
  }
};

export const actions: Actions = {
  togglePremium: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const recipeId = String(formData.get('recipeId') ?? '');
      const current = String(formData.get('current') ?? 'false') === 'true';

      if (!recipeId) {
        return fail(400, { error: 'Missing recipeId.' });
      }

      await databases.updateDocument(databaseId, collectionIds.recipes, recipeId, {
        is_premium: !current
      });

      return { message: !current ? 'Recipe is now premium.' : 'Recipe moved to free.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  createRecipe: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const title = String(formData.get('title') ?? '').trim();
      const category = String(formData.get('category') ?? '').trim();
      const description = String(formData.get('description') ?? '').trim();
      const difficulty = String(formData.get('difficulty') ?? 'easy').trim().toLowerCase();
      const isPremium = String(formData.get('isPremium') ?? 'false') === 'true';
      const videoUrl = String(formData.get('videoUrl') ?? '').trim();
      const englishKeywordsRaw = String(formData.get('englishKeywords') ?? '').trim();
      const ingredientsRaw = String(formData.get('ingredients') ?? '').trim();
      const stepsRaw = String(formData.get('steps') ?? '').trim();

      if (!title || !category || !description) {
        return fail(400, { error: 'Title, category and description are required.' });
      }

      if (!['easy', 'medium', 'hard'].includes(difficulty)) {
        return fail(400, { error: 'Difficulty must be one of: easy, medium, hard.' });
      }

      let ingredients: RecipeIngredient[];
      let steps: RecipeStep[];

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
      const searchText = buildSearchText({
        title,
        category,
        description,
        englishKeywords
      });

      const imageUrl = await resolveMainImageUrl(formData);

      const candidatePayload = {
        title,
        category,
        description,
        image_url: imageUrl,
        video_url: videoUrl,
        prep_time_minutes: toPositiveInt(formData.get('prepTimeMinutes'), 15, 0),
        cook_time_minutes: toPositiveInt(formData.get('cookTimeMinutes'), 30, 0),
        servings: toPositiveInt(formData.get('servings'), 2, 1),
        difficulty,
        is_premium: isPremium,
        ingredients: ingredientsJson,
        steps: stepsJson,
        nutrition: nutritionJson,
        ingredients_json: ingredientsJson,
        steps_json: stepsJson,
        nutrition_json: nutritionJson,
        english_keywords: englishKeywords,
        search_text: searchText,
        average_rating: 0,
        total_ratings: 0,
        created_at: new Date().toISOString()
      };

      const cleanedPayload = Object.fromEntries(
        Object.entries(candidatePayload).filter(([, value]) => value !== undefined && value !== null)
      );
      const payload = await filterDataForCollection(collectionIds.recipes, cleanedPayload);

      await createRecipeDocument(payload);

      return { message: 'Recipe created with full details.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  updateRecipe: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const recipeId = String(formData.get('recipeId') ?? '').trim();
      const title = String(formData.get('title') ?? '').trim();
      const category = String(formData.get('category') ?? '').trim();
      const description = String(formData.get('description') ?? '').trim();
      const difficulty = String(formData.get('difficulty') ?? 'easy').trim().toLowerCase();
      const isPremium = String(formData.get('isPremium') ?? 'false') === 'true';
      const videoUrl = String(formData.get('videoUrl') ?? '').trim();
      const englishKeywordsRaw = String(formData.get('englishKeywords') ?? '').trim();
      const ingredientsRaw = String(formData.get('ingredients') ?? '').trim();
      const stepsRaw = String(formData.get('steps') ?? '').trim();

      if (!recipeId) {
        return fail(400, { error: 'Missing recipeId.' });
      }

      if (!title || !category || !description) {
        return fail(400, { error: 'Title, category and description are required.' });
      }

      if (!['easy', 'medium', 'hard'].includes(difficulty)) {
        return fail(400, { error: 'Difficulty must be one of: easy, medium, hard.' });
      }

      let ingredients: RecipeIngredient[];
      let steps: RecipeStep[];

      try {
        ingredients = parseIngredients(ingredientsRaw);
        steps = await resolveRecipeSteps(formData, stepsRaw);
      } catch (error) {
        return fail(400, { error: formatAdminError(error) });
      }

      const existing = await databases.getDocument(databaseId, collectionIds.recipes, recipeId);
      const existingData = mapDocumentWithId(existing);

      const nutrition = parseNutrition(formData);
      const nutritionJson = JSON.stringify(nutrition ?? {});
      const ingredientsJson = JSON.stringify(ingredients);
      const stepsJson = JSON.stringify(steps);
      const englishKeywords = parseEnglishKeywords(englishKeywordsRaw);
      const searchText = buildSearchText({
        title,
        category,
        description,
        englishKeywords
      });

      const currentImageUrl = String(existingData.image_url ?? '');
      const imageUrl = await resolveMainImageUrl(formData, currentImageUrl);
      const createdAt =
        String(existingData.created_at ?? '').trim() ||
        String(existingData.$createdAt ?? '').trim() ||
        new Date().toISOString();

      const candidatePayload = {
        title,
        category,
        description,
        image_url: imageUrl,
        video_url: videoUrl,
        prep_time_minutes: toPositiveInt(formData.get('prepTimeMinutes'), 15, 0),
        cook_time_minutes: toPositiveInt(formData.get('cookTimeMinutes'), 30, 0),
        servings: toPositiveInt(formData.get('servings'), 2, 1),
        difficulty,
        is_premium: isPremium,
        ingredients: ingredientsJson,
        steps: stepsJson,
        nutrition: nutritionJson,
        ingredients_json: ingredientsJson,
        steps_json: stepsJson,
        nutrition_json: nutritionJson,
        english_keywords: englishKeywords,
        search_text: searchText,
        average_rating: Number(existingData.average_rating ?? 0),
        total_ratings: Number(existingData.total_ratings ?? 0),
        created_at: createdAt
      };

      const cleanedPayload = Object.fromEntries(
        Object.entries(candidatePayload).filter(([, value]) => value !== undefined && value !== null)
      );
      const payload = await filterDataForCollection(collectionIds.recipes, cleanedPayload);

      await databases.updateDocument(databaseId, collectionIds.recipes, recipeId, payload);
      return { message: 'Recipe updated successfully.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  deleteRecipe: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const recipeId = String(formData.get('recipeId') ?? '');

      if (!recipeId) {
        return fail(400, { error: 'Missing recipeId.' });
      }

      await databases.deleteDocument(databaseId, collectionIds.recipes, recipeId);
      return { message: 'Recipe deleted.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  }
};
