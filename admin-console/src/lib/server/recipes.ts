import { InputFile } from 'node-appwrite/file';
import {
  bucketIds,
  buildStorageFileViewUrl,
  collectionIds,
  databaseId,
  databases,
  filterDataForCollection,
  formatAdminError,
  storage
} from './appwrite';

export type RecipeIngredient = { name: string; amount: string; unit?: string };
export type RecipeStep = { order: number; description: string; image_url?: string; timer_seconds?: number };
export type RecipeNutrition = { calories: number; protein: number; carbs: number; fat: number };

export function parseEnglishKeywords(raw: string) {
  return raw
    .split(/[\n,]/)
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

export function buildSearchText({ title, category, description, englishKeywords }: {
  title: string; category: string; description: string; englishKeywords: string[];
}) {
  return Array.from(
    new Set(
      [title, category, description, ...englishKeywords]
        .map((item) => item.trim().toLowerCase())
        .filter(Boolean)
    )
  ).join(' ');
}

export function toPositiveInt(value: FormDataEntryValue | null, fallback: number, min = 0) {
  const parsed = Number(value ?? fallback);
  return !Number.isFinite(parsed) ? fallback : Math.max(min, Math.round(parsed));
}

function normalizeLines(input: string) {
  return input.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
}

function parseJsonArray(raw: string) {
  if (!raw.trim().startsWith('[')) return null;
  const parsed = JSON.parse(raw) as unknown;
  if (!Array.isArray(parsed)) throw new Error('JSON input must be an array.');
  return parsed;
}

export function parseIngredients(raw: string): RecipeIngredient[] {
  const text = raw.trim();
  if (!text) throw new Error('At least one ingredient is required.');

  const jsonArray = parseJsonArray(text);
  if (jsonArray) {
    const normalized = jsonArray.map((entry, index) => {
      if (!entry || typeof entry !== 'object') throw new Error(`Ingredient ${index + 1} is invalid.`);
      const item = entry as Record<string, unknown>;
      const name = String(item.name ?? '').trim();
      const amount = String(item.amount ?? '').trim();
      const unit = String(item.unit ?? '').trim();
      if (!name || !amount) throw new Error(`Ingredient ${index + 1} must include name and amount.`);
      return { name, amount, ...(unit ? { unit } : {}) };
    });
    if (normalized.length === 0) throw new Error('At least one ingredient is required.');
    return normalized;
  }

  const lines = normalizeLines(text);
  if (lines.length === 0) throw new Error('At least one ingredient is required.');

  return lines.map((line, index) => {
    const [nameRaw = '', amountRaw = '', unitRaw = ''] = line.split('|').map((p) => p.trim());
    if (!nameRaw || !amountRaw) throw new Error(`Ingredient line ${index + 1} must be: name | amount | unit`);
    return { name: nameRaw, amount: amountRaw, ...(unitRaw ? { unit: unitRaw } : {}) };
  });
}

export function parseSteps(raw: string): RecipeStep[] {
  const text = raw.trim();
  if (!text) throw new Error('At least one step is required.');

  const jsonArray = parseJsonArray(text);
  if (jsonArray) {
    const normalized = jsonArray.map((entry, index) => {
      if (!entry || typeof entry !== 'object') throw new Error(`Step ${index + 1} is invalid.`);
      const item = entry as Record<string, unknown>;
      const description = String(item.description ?? '').trim();
      const imageUrl = String(item.image_url ?? '').trim();
      const timerRaw = item.timer_seconds;
      const stepOrder = Number(item.order ?? index + 1);
      if (!description) throw new Error(`Step ${index + 1} must include a description.`);
      const timerSeconds = Number(timerRaw);
      return {
        order: Number.isFinite(stepOrder) && stepOrder > 0 ? Math.round(stepOrder) : index + 1,
        description,
        ...(imageUrl ? { image_url: imageUrl } : {}),
        ...(Number.isFinite(timerSeconds) && timerSeconds > 0 ? { timer_seconds: Math.round(timerSeconds) } : {})
      };
    });
    if (normalized.length === 0) throw new Error('At least one step is required.');
    return normalized;
  }

  const lines = normalizeLines(text);
  if (lines.length === 0) throw new Error('At least one step is required.');

  return lines.map((line, index) => {
    const [descriptionRaw = '', imageUrlRaw = '', timerRaw = ''] = line.split('|').map((p) => p.trim());
    if (!descriptionRaw) throw new Error(`Step line ${index + 1} must start with a description.`);
    const parsedTimer = Number(timerRaw);
    return {
      order: index + 1,
      description: descriptionRaw,
      ...(imageUrlRaw ? { image_url: imageUrlRaw } : {}),
      ...(Number.isFinite(parsedTimer) && parsedTimer > 0 ? { timer_seconds: Math.round(parsedTimer) } : {})
    };
  });
}

export function getStringValues(formData: FormData, key: string) {
  return formData.getAll(key).map((value) => (typeof value === 'string' ? value.trim() : ''));
}

export function getFileValues(formData: FormData, key: string) {
  return formData.getAll(key).map((value) => (value instanceof File ? value : null));
}

export async function uploadRecipeImage(uploadedFile: File, fallbackName: string) {
  const arrayBuffer = await uploadedFile.arrayBuffer();
  const fileBuffer = Buffer.from(arrayBuffer);
  const uploaded = await storage.createFile(
    bucketIds.recipeImages,
    'unique()',
    InputFile.fromBuffer(fileBuffer, uploadedFile.name || fallbackName)
  );
  return buildStorageFileViewUrl(bucketIds.recipeImages, uploaded.$id);
}

export async function parseStructuredSteps(formData: FormData) {
  const descriptions = getStringValues(formData, 'stepDescription');
  const imageUrls = getStringValues(formData, 'stepImageUrl');
  const timers = getStringValues(formData, 'stepTimerSeconds');
  const imageFiles = getFileValues(formData, 'stepImageFile');

  const rowCount = Math.max(descriptions.length, imageUrls.length, timers.length, imageFiles.length);
  if (rowCount === 0) return null;

  const steps: RecipeStep[] = [];
  for (let index = 0; index < rowCount; index++) {
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
    const hasAny = Boolean(description) || hasTimer || hasImage;
    if (!hasAny) continue;
    if (!description) throw new Error(`Step ${index + 1} must include a description.`);

    steps.push({
      order: steps.length + 1,
      description,
      ...(hasImage ? { image_url: resolvedImageUrl } : {}),
      ...(hasTimer ? { timer_seconds: Math.round(parsedTimer) } : {})
    });
  }
  return steps.length > 0 ? steps : null;
}

export async function resolveRecipeSteps(formData: FormData, fallbackRawSteps: string) {
  const structured = await parseStructuredSteps(formData);
  if (structured && structured.length > 0) return structured;
  return parseSteps(fallbackRawSteps);
}

export function parseNutrition(formData: FormData) {
  const calories = String(formData.get('nutritionCalories') ?? '').trim();
  const protein = String(formData.get('nutritionProtein') ?? '').trim();
  const carbs = String(formData.get('nutritionCarbs') ?? '').trim();
  const fat = String(formData.get('nutritionFat') ?? '').trim();
  if (!calories && !protein && !carbs && !fat) return null;
  return {
    calories: Math.max(0, Number(calories || 0)),
    protein: Math.max(0, Number(protein || 0)),
    carbs: Math.max(0, Number(carbs || 0)),
    fat: Math.max(0, Number(fat || 0))
  };
}

export async function resolveMainImageUrl(formData: FormData, fallback = '') {
  const imageUrl = String(formData.get('imageUrl') ?? '').trim();
  const uploadedFile = formData.get('imageFile');
  if (uploadedFile instanceof File && uploadedFile.size > 0) {
    return uploadRecipeImage(uploadedFile, 'recipe-image');
  }
  return imageUrl || fallback;
}

export async function createRecipeDocument(data: Record<string, any>) {
  let payload = { ...data };
  for (let attempt = 0; attempt < 8; attempt++) {
    try {
      return await databases.createDocument(databaseId, collectionIds.recipes, 'unique()', payload);
    } catch (error) {
      const message = formatAdminError(error);
      const unknownAttribute = message.match(/Unknown attribute:\s*"?([a-zA-Z0-9_]+)"?/i)?.[1];
      if (!unknownAttribute || !(unknownAttribute in payload)) throw error;
      delete payload[unknownAttribute];
    }
  }
  throw new Error('Recipe could not be saved because the database schema rejected multiple fields.');
}

export function buildRecipePayload(formData: FormData, imageUrl: string, ingredientsJson: string, stepsJson: string, nutritionJson: string, englishKeywords: string[], searchText: string, existingData?: Record<string, any>) {
  const title = String(formData.get('title') ?? '').trim();
  const category = String(formData.get('category') ?? '').trim();
  const description = String(formData.get('description') ?? '').trim();
  const difficulty = String(formData.get('difficulty') ?? 'easy').trim().toLowerCase();
  const isPremium = String(formData.get('isPremium') ?? 'false') === 'true';
  const videoUrl = String(formData.get('videoUrl') ?? '').trim();

  const base = {
    title,
    category,
    description,
    image_url: imageUrl || null,
    video_url: videoUrl || null,
    prep_time_minutes: toPositiveInt(formData.get('prepTimeMinutes'), 15, 0),
    cook_time_minutes: toPositiveInt(formData.get('cookTimeMinutes'), 30, 0),
    servings: toPositiveInt(formData.get('servings'), 2, 1),
    difficulty,
    is_premium: isPremium,
    ingredients: null,
    steps: null,
    nutrition: null,
    ingredients_json: ingredientsJson,
    steps_json: stepsJson,
    nutrition_json: nutritionJson,
    english_keywords: englishKeywords,
    search_text: searchText,
    average_rating: existingData ? Number(existingData.average_rating ?? 0) : 0,
    total_ratings: existingData ? Number(existingData.total_ratings ?? 0) : 0,
    created_at: existingData
      ? (String(existingData.created_at ?? '').trim() || String(existingData.$createdAt ?? '').trim() || new Date().toISOString())
      : new Date().toISOString()
  };

  return Object.fromEntries(Object.entries(base).filter(([, value]) => value !== undefined));
}
