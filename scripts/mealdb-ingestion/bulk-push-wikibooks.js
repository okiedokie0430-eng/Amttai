import { cog } from 'dotenv';
import path from 'path';
import fs from 'fs';
import https from 'https';
import http from 'http';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
config({ path: path.resolve(__dirname, '.env') });

const {
  APPWRITE_ENDPOINT,
  APPWRITE_PROJECT_ID,
  APPWRITE_API_KEY,
  APPWRITE_DATABASE_ID,
  APPWRITE_RECIPES_COLLECTION_ID,
} = process.env;

// ─── Paths ────────────────────────────────────────────────────────────────────
const JSON_PATH = path.resolve(__dirname, 'recipes_parsed.json');
const CHECKPOINT_FILE = path.resolve(__dirname, 'wikibooks-checkpoint.json');
const IMAGE_CACHE_FILE = path.resolve(__dirname, 'wikibooks-image-cache.json');

// ─── Tunables ─────────────────────────────────────────────────────────────────
const MAX_RETRIES = Number(process.env.BULK_MAX_RETRIES || 4);
const REQUEST_TIMEOUT_MS = Number(process.env.BULK_REQUEST_TIMEOUT_MS || 20000);
const MIN_INGREDIENTS = Number(process.env.BULK_MIN_INGREDIENTS || 3);
const MIN_STEPS = Number(process.env.BULK_MIN_STEPS || 1);
const APPWRITE_STEPS_LIMIT = Number(process.env.BULK_STEPS_LIMIT || 3800);
const DELAY_BETWEEN_RECIPES_MS = Number(process.env.BULK_DELAY_BETWEEN_RECIPES_MS || 1000);
const COMMONS_DELAY_MS = Number(process.env.BULK_COMMONS_DELAY_MS || 200);

// ─── Helpers ─────────────────────────────────────────────────────────────────
const delay = (ms) => new Promise((r) => setTimeout(r, ms));
const ts = () => `[${new Date().toLocaleTimeString()}]`;
const log = (...a) => console.log(ts(), ...a);
const err = (...a) => console.error(ts(), '✖', ...a);
const warn = (...a) => console.warn(ts(), '⚠', ...a);

let isShuttingDown = false;

function setupGracefulShutdown() {
  const shutdown = (signal) => {
    if (isShuttingDown) return;
    isShuttingDown = true;
    warn(`Received ${signal} — finishing current recipe then exiting...`);
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

// ─── Checkpoint ───────────────────────────────────────────────────────────────
function loadCheckpoint() {
  try {
    const raw = fs.readFileSync(CHECKPOINT_FILE, 'utf8');
    const data = JSON.parse(raw);
    return {
      lastIndex: Number(data.lastIndex || 0),
      success: Number(data.success || 0),
      failed: Number(data.failed || 0),
      skippedNoIngredients: Number(data.skippedNoIngredients || 0),
      skippedNoSteps: Number(data.skippedNoSteps || 0),
      skippedNoImage: Number(data.skippedNoImage || 0),
      skippedOther: Number(data.skippedOther || 0),
    };
  } catch {
    return { lastIndex: 0, success: 0, failed: 0, skippedNoIngredients: 0, skippedNoSteps: 0, skippedNoImage: 0, skippedOther: 0 };
  }
}

function saveCheckpoint(state) {
  const tmp = CHECKPOINT_FILE + '.tmp';
  const payload = JSON.stringify(
    {
      lastIndex: state.currentIndex,
      success: state.success,
      failed: state.failed,
      skippedNoIngredients: state.skippedNoIngredients,
      skippedNoSteps: state.skippedNoSteps,
      skippedNoImage: state.skippedNoImage,
      skippedOther: state.skippedOther,
      updatedAt: new Date().toISOString(),
    },
    null,
    2
  );
  fs.writeFileSync(tmp, payload, 'utf8');
  fs.renameSync(tmp, CHECKPOINT_FILE);
}

// ─── Image Cache ──────────────────────────────────────────────────────────────
function loadImageCache() {
  try {
    const raw = fs.readFileSync(IMAGE_CACHE_FILE, 'utf8');
    return new Map(Object.entries(JSON.parse(raw)));
  } catch {
    return new Map();
  }
}

function saveImageCache(cache) {
  const tmp = IMAGE_CACHE_FILE + '.tmp';
  const payload = JSON.stringify(Object.fromEntries(cache), null, 2);
  fs.writeFileSync(tmp, payload, 'utf8');
  fs.renameSync(tmp, IMAGE_CACHE_FILE);
}

// ─── Env Validation ───────────────────────────────────────────────────────────
function assertEnv() {
  const missing = [];
  if (!APPWRITE_ENDPOINT) missing.push('APPWRITE_ENDPOINT');
  if (!APPWRITE_PROJECT_ID) missing.push('APPWRITE_PROJECT_ID');
  if (!APPWRITE_API_KEY) missing.push('APPWRITE_API_KEY');
  if (!APPWRITE_DATABASE_ID) missing.push('APPWRITE_DATABASE_ID');
  if (!APPWRITE_RECIPES_COLLECTION_ID) missing.push('APPWRITE_RECIPES_COLLECTION_ID');
  if (missing.length) {
    err('Missing env:', missing.join(', '));
    process.exit(1);
  }
}

// ─── Time Parsing ─────────────────────────────────────────────────────────────
function parseTimeToMinutes(text) {
  if (!text || typeof text !== 'string') return 0;
  let total = 0;
  // Normalize unicode fractions: ½ → .5, ¼ → .25, ¾ → .75
  const normalized = text
    .replace(/½/g, '.5')
    .replace(/¼/g, '.25')
    .replace(/¾/g, '.75')
    .replace(/³⁄₄/g, '.75')
    .replace(/²⁄₃/g, '.67');
  // Split on uppercase boundaries to handle "Prep: 20 minutesBaking: 60 minutes"
  const segments = normalized.split(/(?=[A-Z])/);
  for (const seg of segments) {
    let segTotal = 0;
    const hourMatch = seg.match(/(\d+(?:\.\d+)?)\s*h(our)?s?/i);
    if (hourMatch) segTotal += parseFloat(hourMatch[1]) * 60;
    const minMatch = seg.match(/(\d+(?:\.\d+)?)\s*m(in)?(ute)?s?/i);
    if (minMatch) segTotal += parseFloat(minMatch[1]);
    if (segTotal === 0) {
      const firstNum = seg.match(/(\d+(?:\.\d+)?)/);
      if (firstNum) segTotal = parseFloat(firstNum[1]);
    }
    total += segTotal;
  }
  return Math.round(total);
}

function parseServings(text) {
  if (!text || typeof text !== 'string') return 4;
  // "8–10" → take first, "About 6" → extract number, "12" → direct
  const match = String(text).match(/(\d+)/);
  return match ? Math.max(1, Number(match[1])) : 4;
}

// ─── Category Cleaning ────────────────────────────────────────────────────────
function cleanCategory(raw) {
  if (!raw || typeof raw !== 'string') return 'General';
  return raw
    .replace('/wiki/Category:', '')
    .replace(/_recipes?/gi, '')
    .replace(/_/g, ' ')
    .trim() || 'General';
}

// ─── Difficulty Mapping ───────────────────────────────────────────────────────
function mapDifficulty(value) {
  const map = { '1': 'Easy', '2': 'Medium', '3': 'Hard', '4': 'Expert' };
  return map[String(value)] || 'Medium';
}

// ─── Ingredient / Step Extraction ─────────────────────────────────────────────
// Normalize section name to a canonical key
const SECTION_ALIASES = {
  'Ingredients': 'Ingredients',
  'Ingredients:': 'Ingredients',
  'Ingredient': 'Ingredients',
  'Ingredients for 4 people': 'Ingredients',
  'Ingredients[2]': 'Ingredients',
  'Ingredients[2][3]': 'Ingredients',
};

const STEP_SECTIONS = new Set([
  'Procedure', 'Procedures', 'Instructions', 'Preparation', 'Preparation[3]',
  'Process', 'Recipe', 'Recipe overview', 'Recipe Video',
]);

function isStepSection(section) {
  if (!section) return false;
  if (STEP_SECTIONS.has(section)) return true;
  // Catch-all: any section containing "procedure", "instruction", "preparation", "recipe" (but not "variation" or "note")
  const lower = section.toLowerCase();
  return /^(procedure|instruction|preparation|recipe|process)/.test(lower) &&
    !/variation|note|tip|warning|reference|external|see\s|history|equipment|storage|troubleshoot|gallery|ingredient|conversion|tool|help/i.test(lower);
}

function isIngredientSection(section) {
  if (!section) return false;
  const canonical = SECTION_ALIASES[section] || section;
  return canonical === 'Ingredients';
}

function extractIngredients(recipeData) {
  return (recipeData.text_lines || [])
    .filter((t) => isIngredientSection(t.section) && t.line_type === 'ul')
    .map((t) => String(t.text || '').trim())
    .filter((t) => t.length > 0);
}

function extractSteps(recipeData) {
  return (recipeData.text_lines || [])
    .filter((t) => isStepSection(t.section) && t.line_type === 'ol')
    .map((t) => String(t.text || '').trim())
    .filter((t) => t.length > 0);
}

// ─── URL Validation ───────────────────────────────────────────────────────────
function isValidImageUrl(str) {
  if (!str || typeof str !== 'string') return false;
  const trimmed = str.trim();
  if (trimmed !== str) return false;
  if (!/^https?:\/\//i.test(trimmed)) return false;
  try {
    const u = new URL(trimmed);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') return false;
    if (/[\x00-\x1f\x7f]/.test(trimmed)) return false;
    if (/\s/.test(u.pathname + u.search + u.hash)) return false;
    return true;
  } catch {
    return false;
  }
}

// ─── Image Liveness Check ─────────────────────────────────────────────────────
// Wikimedia CDN supports HEAD but often hangs, so we use GET with a short timeout.
// If it doesn't respond in 3s, treat as dead and try next result.
async function isImageAlive(url, timeoutMs = 3000) {
  return new Promise((resolve) => {
    const parsed = new URL(url);
    const lib = parsed.protocol === 'https:' ? https : http;
    const req = lib.get(url, { headers: COMMONS_HEADERS }, (res) => {
      res.resume(); // drain socket
      resolve(res.statusCode >= 200 && res.statusCode < 400);
    });
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
    setTimeout(() => { if (!req.destroyed) { req.destroy(); resolve(false); } }, timeoutMs);
  });
}

// ─── Wikimedia Commons Image Search ────────────────────────────────────────
const COMMONS_HEADERS = {
  'User-Agent': 'AmttaiRecipeApp/1.0 (Mongolian Recipe App; contact@amttai.com)',
};

function commonsApi(query) {
  return new Promise((resolve) => {
    const url = 'https://commons.wikimedia.org/w/api.php?' + query;
    https
      .get(url, { headers: COMMONS_HEADERS }, (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            // Log API errors from Wikimedia
            if (parsed.error) {
              log(`  [commons] API ERROR: ${parsed.error.code} - ${parsed.error.info}`);
            }
            resolve(parsed);
          }
          catch { resolve(null); }
        });
      })
      .on('error', (e) => {
        log(`  [commons] network error: ${e.message}`);
        resolve(null);
      });
  });
}

async function searchCommonsImage(query) {
  // Search File namespace (ns=6) for images matching the query
  const json = await commonsApi(
    'action=query&list=search&srsearch=' +
      encodeURIComponent(query) +
      '&format=json&srnamespace=6&srlimit=5'
  );
  const results = json?.query?.search || [];
  log(`  [commons] query="${query}" results=${results.length}`);
  if (results.length === 0) return null;

  // Try each result until we find a valid live image (skip PDFs, SVGs, and dead links)
  for (const result of results) {
    const filename = result.title.replace(/^File:/, '');
    const ext = filename.split('.').pop()?.toLowerCase() || '';
    if (['pdf', 'svg'].includes(ext)) {
      log(`  [commons] skip "${filename}" (${ext} file)`);
      continue;
    }

    const fileJson = await commonsApi(
      'action=query&titles=File:' +
        encodeURIComponent(filename) +
        '&prop=imageinfo&iiprop=url&iiwmdefault=1&format=json'
    );
    const pages = fileJson?.query?.pages || {};
    const page = Object.values(pages)[0];
    const url = page?.imageinfo?.[0]?.url || null;
    log(`  [commons] filename="${filename}" url=${url ? url.slice(0,80) : 'NULL'}`);

    if (!url) continue;

    // Verify the image is actually alive before using it
    const alive = await isImageAlive(url);
    log(`  [commons] alive=${alive}`);
    if (alive) return url;
  }
  return null;
}

// ─── Image Acquisition ────────────────────────────────────────────────────────
async function acquireImage(recipeTitle, category, imageCache) {
  const cacheKey = `${recipeTitle}|${category}`;
  if (imageCache.has(cacheKey)) {
    const cached = imageCache.get(cacheKey);
    if (cached && isValidImageUrl(cached)) return cached;
  }

  const query = `${recipeTitle} ${category}`.slice(0, 100);
  const imageUrl = await searchCommonsImage(query);
  log(`  [image] query="${query}" result=${imageUrl ? 'URL_FOUND' : 'NULL'}`);

  if (imageUrl && isValidImageUrl(imageUrl)) {
    // Wikimedia returns only valid URLs — trust it directly
    log(`  [image] URL valid, using: ${imageUrl.slice(0, 80)}`);
    imageCache.set(cacheKey, imageUrl);
    return imageUrl;
  }

  imageCache.set(cacheKey, null);
  return null;
}

// ─── Quality Checks ───────────────────────────────────────────────────────────
function buildQualityFlags(recipeData) {
  const flags = [];
  const ingredients = extractIngredients(recipeData);
  const steps = extractSteps(recipeData);
  const title = String(recipeData.title || '').trim();

  if (!title || title.length < 3) flags.push('missing_title');
  if (ingredients.length < MIN_INGREDIENTS) flags.push('few_ingredients');
  if (steps.length < MIN_STEPS) flags.push('few_steps');
  if (!recipeData.infobox?.category) flags.push('missing_category');
  return flags;
}

function shouldSkipByQuality(flags) {
  return flags.includes('missing_title') || flags.includes('few_ingredients') || flags.includes('few_steps');
}

// ─── Payload Building ─────────────────────────────────────────────────────────
function sanitizeText(raw) {
  const text = String(raw || '')
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '')
    .replace(/\t/g, ' ')
    .trim();
  return text;
}

function buildStableStringifiedSteps(steps) {
  const normalized = steps.map((description, index) => ({
    order: index + 1,
    description: sanitizeText(description),
    duration_minutes: 0,
    imageUrl: null,
    ingredients: [],
  }));

  let payload = JSON.stringify(normalized);
  if (payload.length <= APPWRITE_STEPS_LIMIT) return payload;

  const limits = [120, 60, 30, 10];
  let current = normalized;
  for (const limit of limits) {
    const candidate = current.map(({ description, ...rest }) => ({
      ...rest,
      description: description.slice(0, limit),
    }));
    const json = JSON.stringify(candidate);
    if (json.length <= APPWRITE_STEPS_LIMIT) return json;
    current = candidate;
  }
  const reduced = current.slice(0, Math.max(1, Math.floor(current.length / 2)));
  const reducedJson = JSON.stringify(reduced);
  if (reducedJson.length <= APPWRITE_STEPS_LIMIT) return reducedJson;
  return reducedJson.slice(0, APPWRITE_STEPS_LIMIT);
}

function mapRecipe(recipeData, imageUrl) {
  const ingredients = extractIngredients(recipeData);
  const steps = extractSteps(recipeData);
  const title = String(recipeData.title || '').trim();
  const category = cleanCategory(recipeData.infobox?.category);
  const timeText = recipeData.infobox?.time || '';
  const totalMin = parseTimeToMinutes(timeText);
  const prepMin = Math.max(1, Math.floor((totalMin || 30) * 0.35));
  const cookMin = Math.max(1, Math.ceil((totalMin || 30) * 0.65));
  const servings = parseServings(recipeData.infobox?.servings);
  const difficulty = mapDifficulty(recipeData.infobox?.difficulty);

  // Build ingredient objects — raw text as name, no quantity splitting
  const ingredientObjects = ingredients.map((name) => ({
    name: sanitizeText(name),
    amount: '',
    unit: '',
  }));

  return {
    title: sanitizeText(title) || 'Untitled Recipe',
    description: `${category} recipe`,
    category,
    english_keywords: [],
    source_url: recipeData.url || null,
    image_url: imageUrl,
    video_url: null,
    audio_step_urls: [],
    prep_time_minutes: prepMin,
    cook_time_minutes: cookMin,
    servings,
    difficulty,
    is_premium: false,
    ingredients: ingredientObjects,
    steps: steps.map((description, index) => ({
      order: index + 1,
      description: sanitizeText(description),
      duration_minutes: 0,
      imageUrl: null,
      ingredients: [],
    })),
    nutrition: { calories: 0, protein: 0, carbs: 0, fat: 0 },
  };
}

function validatePayload(mapped) {
  const errors = [];
  if (!mapped.title || mapped.title === 'Untitled Recipe') errors.push('invalid_title');
  if (!mapped.ingredients || mapped.ingredients.length === 0) errors.push('no_ingredients');
  if (!mapped.steps || mapped.steps.length === 0) errors.push('no_steps');
  // Only reject if a non-null image_url is present but invalid (null is ok — image not yet acquired)
  if (mapped.image_url && !isValidImageUrl(mapped.image_url)) errors.push('invalid_image_url');
  if (!mapped.category) errors.push('no_category');
  if (mapped.title && mapped.title.length > 200) errors.push('title_too_long');
  return errors;
}

function buildAppwritePayload(mapped) {
  const ingredientsString = JSON.stringify(mapped.ingredients);
  // Pass raw step description strings so buildStableStringifiedSteps can sanitize them
  const rawSteps = mapped.steps.map((s) => s.description || String(s));
  const stepsString = buildStableStringifiedSteps(rawSteps);
  const nutritionString = JSON.stringify(mapped.nutrition);

  let safeImageUrl = null;
  if (mapped.image_url) {
    try {
      const u = new URL(mapped.image_url);
      safeImageUrl = u.toString();
    } catch {
      safeImageUrl = null;
    }
  }

  return {
    documentId: 'unique()',
    data: {
      title: mapped.title,
      description: mapped.description,
      category: mapped.category,
      english_keywords: mapped.english_keywords,
      image_url: safeImageUrl,
      video_url: null,
      audio_step_urls: [],
      prep_time_minutes: mapped.prep_time_minutes,
      cook_time_minutes: mapped.cook_time_minutes,
      servings: mapped.servings,
      difficulty: mapped.difficulty,
      is_premium: mapped.is_premium,
      ingredients: ingredientsString,
      ingredients_json: ingredientsString,
      steps: stepsString,
      steps_json: stepsString,
      nutrition_json: nutritionString,
      created_at: new Date().toISOString(),
    },
  };
}

// ─── Appwrite Push ────────────────────────────────────────────────────────────
async function createDocumentWithRetry(payload, attempt = 1) {
  const url = [
    APPWRITE_ENDPOINT,
    'databases',
    APPWRITE_DATABASE_ID,
    'collections',
    APPWRITE_RECIPES_COLLECTION_ID,
    'documents',
  ].join('/');

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const res = await fetch(url, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        'X-Appwrite-Project': APPWRITE_PROJECT_ID,
        'X-Appwrite-Key': APPWRITE_API_KEY,
      },
      body: JSON.stringify(payload),
    });

    clearTimeout(timer);
    if (res.ok) return { ok: true, status: res.status };

    const text = await res.text();
    if (res.status === 429 && attempt < MAX_RETRIES) throw new Error(`rate_limited:${text}`);
    return { ok: false, status: res.status, body: text };
  } catch (e) {
    clearTimeout(timer);
    if (attempt < MAX_RETRIES) throw new Error(`retryable:${e.message}`);
    throw e;
  }
}

// ─── Per-Recipe Processing ────────────────────────────────────────────────────
async function processRecipe(recipe, state, imageCache) {
  if (isShuttingDown) return 'interrupted';

  const recipeData = recipe.recipe_data;
  if (!recipeData) {
    state.skippedOther++;
    warn('Skip malformed recipe: no recipe_data');
    saveCheckpoint(state);
    return 'skipped';
  }

  const flags = buildQualityFlags(recipeData);
  if (shouldSkipByQuality(flags)) {
    if (flags.includes('few_ingredients')) state.skippedNoIngredients++;
    else if (flags.includes('few_steps')) state.skippedNoSteps++;
    else state.skippedOther++;
    warn(`Skip low-quality recipe: ${recipeData.title} — ${flags.join(', ')}`);
    saveCheckpoint(state);
    return 'skipped';
  }

  const mapped = mapRecipe(recipeData, null);
  const validationErrors = validatePayload(mapped);
  if (validationErrors.length > 0) {
    state.skippedOther++;
    warn(`Skip validation failed: ${recipeData.title} — ${validationErrors.join(', ')}`);
    saveCheckpoint(state);
    return 'skipped';
  }

  // Try to acquire image
  const imageUrl = await acquireImage(mapped.title, mapped.category, imageCache);
  if (!imageUrl) {
    state.skippedNoImage++;
    warn(`Skip no-image recipe: ${mapped.title}`);
    saveCheckpoint(state);
    return 'skipped_no_image';
  }

  // Update mapped recipe with valid image
  mapped.image_url = imageUrl;
  const payload = buildAppwritePayload(mapped);

  let lastError = null;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    if (isShuttingDown) return 'interrupted';

    const result = await createDocumentWithRetry(payload, attempt);
    if (result.ok) {
      state.success++;
      saveCheckpoint(state);
      saveImageCache(imageCache);
      await delay(DELAY_BETWEEN_RECIPES_MS);
      return 'success';
    }

    const message = result.body || `HTTP ${result.status}`;
    lastError = message;

    if (result.status === 429 || String(message).includes('rate_limited') || String(message).includes('retryable')) {
      const waitMs = Math.min(30000, 2000 * attempt);
      warn(`Retry ${attempt}/${MAX_RETRIES} after ${message}. Waiting ${waitMs}ms...`);
      await delay(waitMs);
      continue;
    }

    state.failed++;
    err(`Appwrite ${result.status}: ${message}`);
    saveCheckpoint(state);
    await delay(DELAY_BETWEEN_RECIPES_MS);
    return 'failed';
  }

  state.failed++;
  err(`All ${MAX_RETRIES} retries failed. Last error: ${lastError}`);
  saveCheckpoint(state);
  await delay(DELAY_BETWEEN_RECIPES_MS);
  return 'failed';
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  assertEnv();
  setupGracefulShutdown();

  if (!fs.existsSync(JSON_PATH)) {
    err('recipes_parsed.json not found:', JSON_PATH);
    process.exit(1);
  }

  const checkpoint = loadCheckpoint();
  const imageCache = loadImageCache();
  log(`Checkpoint: index=${checkpoint.lastIndex}, success=${checkpoint.success}, failed=${checkpoint.failed}`);
  log(`Image cache: ${imageCache.size} entries`);

  const recipes = JSON.parse(fs.readFileSync(JSON_PATH, 'utf8'));
  log(`Loaded ${recipes.length} recipes from JSON`);
  const pending = recipes.slice(checkpoint.lastIndex);
  log(`Processing ${pending.length} recipes starting from index ${checkpoint.lastIndex}`);

  const state = {
    currentIndex: checkpoint.lastIndex,
    success: checkpoint.success,
    failed: checkpoint.failed,
    skippedNoIngredients: checkpoint.skippedNoIngredients,
    skippedNoSteps: checkpoint.skippedNoSteps,
    skippedNoImage: checkpoint.skippedNoImage,
    skippedOther: checkpoint.skippedOther,
  };

  for (const recipe of pending) {
    if (isShuttingDown) {
      warn('Shutdown requested — stopping early.');
      break;
    }
    state.currentIndex++;
    await processRecipe(recipe, state, imageCache);

    if (state.currentIndex % 20 === 0) {
      log(
        `Progress: ${state.currentIndex}/${recipes.length} | ` +
          `ok=${state.success} fail=${state.failed} ` +
          `no_ing=${state.skippedNoIngredients} no_steps=${state.skippedNoSteps} ` +
          `no_img=${state.skippedNoImage} other=${state.skippedOther}`
      );
    }
  }

  saveCheckpoint(state);
  saveImageCache(imageCache);
  console.log('\n' + '═'.repeat(60));
  log(
    `Done — ✅ ${state.success} | ❌ ${state.failed} | ` +
      `⚠ no_ing=${state.skippedNoIngredients} no_steps=${state.skippedNoSteps} ` +
      `no_img=${state.skippedNoImage} other=${state.skippedOther}`
  );
  console.log('═'.repeat(60));
}

main().catch((fatal) => {
  err(fatal.message);
  process.exit(1);
});