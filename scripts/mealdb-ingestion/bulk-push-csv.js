import 'dotenv/config';
import fs from 'fs';
import path from 'path';
import csvParser from 'csv-parser';

const {
  APPWRITE_ENDPOINT,
  APPWRITE_PROJECT_ID,
  APPWRITE_API_KEY,
  APPWRITE_DATABASE_ID,
  APPWRITE_RECIPES_COLLECTION_ID,
} = process.env;

const CSV_PATH = path.resolve('recipes.csv');
const CHECKPOINT_FILE = path.resolve('csv-ingestion-checkpoint.json');
const BATCH_SIZE = Number(process.env.BULK_BATCH_SIZE || 10);
const MAX_RETRIES = Number(process.env.BULK_MAX_RETRIES || 4);
const REQUEST_TIMEOUT_MS = Number(process.env.BULK_REQUEST_TIMEOUT_MS || 20000);
const MAX_IMAGES = Number(process.env.BULK_MAX_IMAGES || 3);
const MIN_INGREDIENTS = Number(process.env.BULK_MIN_INGREDIENTS || 3);
const MIN_STEPS = Number(process.env.BULK_MIN_STEPS || 3);
const APPWRITE_STEPS_LIMIT = Number(process.env.BULK_STEPS_LIMIT || 3800);
const DELAY_BETWEEN_RECIPES_MS = Number(process.env.BULK_DELAY_BETWEEN_RECIPES_MS || 1000);

const delay = (ms) => new Promise((r) => setTimeout(r, ms));
const ts = () => `[${new Date().toLocaleTimeString()}]`;
const log = (...a) => console.log(ts(), ...a);
const err = (...a) => console.error(ts(), '✖', ...a);
const warn = (...a) => console.warn(ts(), '⚠', ...a);

// Graceful shutdown flag
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

function loadCheckpoint() {
  try {
    const raw = fs.readFileSync(CHECKPOINT_FILE, 'utf8');
    const data = JSON.parse(raw);
    return {
      lastIndex: Number(data.lastIndex || 0),
      success: Number(data.success || 0),
      failed: Number(data.failed || 0),
      skippedBadImages: Number(data.skippedBadImages || 0),
      skippedInvalid: Number(data.skippedInvalid || 0),
    };
  } catch {
    return { lastIndex: 0, success: 0, failed: 0, skippedBadImages: 0, skippedInvalid: 0 };
  }
}

function saveCheckpoint(state) {
  const tmp = CHECKPOINT_FILE + '.tmp';
  const payload = JSON.stringify(
    {
      lastIndex: state.currentIndex,
      success: state.success,
      failed: state.failed,
      skippedBadImages: state.skippedBadImages,
      skippedInvalid: state.skippedInvalid,
      updatedAt: new Date().toISOString(),
    },
    null,
    2
  );
  fs.writeFileSync(tmp, payload, 'utf8');
  fs.renameSync(tmp, CHECKPOINT_FILE);
}

function parsePyList(value) {
  if (!value || value === 'NA' || value === 'nan') return [];
  let s = String(value).trim();
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    s = s.slice(1, -1).trim();
  }
  if (s.startsWith('c(') && s.endsWith(')')) s = s.slice(2, -1).trim();
  if (s.startsWith('[') && s.endsWith(']')) s = s.slice(1, -1).trim();

  const items = [];
  let cur = '';
  let inQuote = false;
  let quoteChar = null;

  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (!inQuote && (ch === "'" || ch === '"')) {
      inQuote = true;
      quoteChar = ch;
      continue;
    }
    if (inQuote && ch === quoteChar) {
      inQuote = false;
      quoteChar = null;
      continue;
    }
    if (!inQuote && ch === ',') {
      if (cur.trim()) items.push(cur.trim());
      cur = '';
      continue;
    }
    if (!inQuote && /\s/.test(ch)) {
      if (cur.trim()) items.push(cur.trim());
      cur = '';
      continue;
    }
    cur += ch;
  }

  if (cur.trim()) items.push(cur.trim());
  return items;
}

function parseImageUrls(raw) {
  if (!raw || raw === 'NA' || raw === 'nan') return [];
  const urls = parsePyList(raw);
  const valid = [];
  const seen = new Set();
  for (const url of urls) {
    const trimmed = String(url).trim();
    if (!trimmed) continue;
    if (!/^https?:\/\//i.test(trimmed)) continue;
    if (seen.has(trimmed)) continue;
    seen.add(trimmed);
    valid.push(trimmed);
  }
  return valid.slice(0, MAX_IMAGES);
}

function isValidUrl(str) {
  try {
    const u = new URL(str);
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch {
    return false;
  }
}

function isValidImageUrl(str) {
  if (!str || typeof str !== 'string') return false;
  const trimmed = str.trim();
  if (!trimmed || trimmed !== str) return false;
  if (!/^https?:\/\//i.test(trimmed)) return false;
  try {
    const u = new URL(trimmed);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') return false;
    // Reject URLs with newlines, tabs, or other control characters
    if (/[\x00-\x1f\x7f]/.test(trimmed)) return false;
    // Reject URLs with spaces (even encoded ones in wrong places)
    if (/\s/.test(u.pathname + u.search + u.hash)) return false;
    return true;
  } catch {
    return false;
  }
}

function looksLikeImageUrl(url) {
  if (!isValidUrl(url)) return false;
  const lower = url.toLowerCase();
  return (
    lower.includes('.jpg') ||
    lower.includes('.jpeg') ||
    lower.includes('.png') ||
    lower.includes('.webp') ||
    lower.includes('.gif') ||
    lower.includes('.bmp') ||
    lower.includes('/image') ||
    /https?:\/\/\w+\.(food\.com|s3\.amazonaws\.com|cdn\.)/.test(lower) ||
    lower.includes('assets') ||
    lower.includes('uploads') ||
    lower.includes('image')
  );
}

async function isImageAlive(url) {
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), Math.max(5000, REQUEST_TIMEOUT_MS));
    const res = await fetch(url, {
      method: 'HEAD',
      signal: controller.signal,
      redirect: 'follow',
      headers: {
        'User-Agent': 'Mozilla/5.0',
        Accept: 'image/webp,image/apng,image/*,*/*',
      },
    });
    clearTimeout(timer);
    return res.ok;
  } catch {
    return false;
  }
}

function parseDuration(value) {
  if (!value || value === 'NA') return 0;
  const text = String(value).trim();
  if (!text.startsWith('PT')) return 0;
  const hours = text.match(/(\d+)H/);
  const mins = text.match(/(\d+)M/);
  return ((hours ? Number(hours[1]) : 0) * 60) + (mins ? Number(mins[1]) : 0) || 0;
}

function parseInstructions(raw) {
  const parts = parsePyList(raw);
  return parts
    .map((item) => String(item || '').trim())
    .filter((text) => text.length > 5);
}

function buildQualityFlags(recipe) {
  const flags = [];
  const ingredients = parsePyList(recipe.RecipeIngredientParts);
  const steps = parseInstructions(recipe.RecipeInstructions);
  if (!recipe.Name || String(recipe.Name).trim().length < 3) flags.push('missing_title');
  if (!ingredients.length) flags.push('missing_ingredients');
  if (ingredients.length < MIN_INGREDIENTS) flags.push('few_ingredients');
  if (!steps.length) flags.push('missing_steps');
  if (steps.length < MIN_STEPS) flags.push('few_steps');
  if (!parseDuration(recipe.TotalTime) && !parseDuration(recipe.CookTime) && !parseDuration(recipe.PrepTime)) {
    flags.push('missing_time');
  }
  if (!recipe.RecipeCategory || String(recipe.RecipeCategory).trim() === '') flags.push('missing_category');
  if (!recipe.Images || String(recipe.Images).trim() === '' || String(recipe.Images).trim() === 'NA' || String(recipe.Images).trim() === 'nan') flags.push('broken_image');
  return flags;
}

function cleanTitle(raw) {
  const text = String(raw || '')
    .replace(/[{}()\[\]"]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  return text || 'Untitled Recipe';
}

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
  const normalized = steps
    .map((step) => {
      const description = sanitizeText(typeof step === 'string' ? step : step.description || '');
      const duration = typeof step === 'string' ? 0 : Number(step.duration_minutes || step.durationMinutes || 0) || 0;
      return { order: typeof step === 'string' ? 0 : Number(step.order || 0) || 0, description, duration_minutes: duration };
    })
    .filter((step) => step.description.length > 0);

  let payload = JSON.stringify(normalized);
  if (payload.length <= APPWRITE_STEPS_LIMIT) return payload;

  const limits = [120, 60, 30, 10];
  let current = normalized;

  for (const limit of limits) {
    const candidate = current.map(({ description, ...rest }) => ({ ...rest, description: description.slice(0, limit) }));
    const candidateJson = JSON.stringify(candidate);
    if (candidateJson.length <= APPWRITE_STEPS_LIMIT) return candidateJson;
    current = candidate;
  }

  const stepCountReduced = current.slice(0, Math.max(1, Math.floor(current.length / 2)));
  const reducedJson = JSON.stringify(stepCountReduced);
  if (reducedJson.length <= APPWRITE_STEPS_LIMIT) return reducedJson;

  return reducedJson.slice(0, APPWRITE_STEPS_LIMIT);
}

function splitQuantity(raw) {
  const text = String(raw || '').trim();
  if (!text) return { amount: '', unit: '' };

  const normalized = text.replace(/[–—]/g, '-').replace(/\s*\/\s*/g, '/').trim();
  const fractionMap = { '1/4': '0.25', '1/3': '0.33', '1/2': '0.5', '2/3': '0.67', '3/4': '0.75' };
  let numeric = normalized;

  for (const [fraction, decimal] of Object.entries(fractionMap)) {
    numeric = numeric.replace(new RegExp(`\\b${fraction.replace('/', '\\/')}\\b`, 'g'), decimal);
  }

  const rangeMatch = numeric.match(/^(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)(.*)$/);
  if (rangeMatch) {
    return {
      amount: `${rangeMatch[1]} - ${rangeMatch[2]}`,
      unit: rangeMatch[3] ? rangeMatch[3].trim() : '',
    };
  }

  const exactMatch = numeric.match(/^(\d+(?:\.\d+)?)(.*)$/);
  if (exactMatch) {
    return {
      amount: exactMatch[1],
      unit: exactMatch[2] ? exactMatch[2].trim() : '',
    };
  }

  return { amount: text, unit: '' };
}

function mapRecipe(row) {
  const ingredients = parsePyList(row.RecipeIngredientParts);
  const quantities = parsePyList(row.RecipeIngredientQuantities);
  const combined = [];
  for (let i = 0; i < Math.max(ingredients.length, quantities.length); i++) {
    const qty = quantities[i] ? String(quantities[i]).trim() : '';
    const part = ingredients[i] ? String(ingredients[i]).trim() : '';
    const value = qty && part ? `${qty} ${part}` : part || qty;
    if (!value) continue;
    const { amount, unit } = splitQuantity(qty);
    combined.push({
      name: part,
      amount,
      unit,
    });
  }

  const steps = parseInstructions(row.RecipeInstructions);
  const imageUrls = parseImageUrls(row.Images);
  const prepMin = parseDuration(row.PrepTime);
  const cookMin = parseDuration(row.CookTime);
  const totalMin = parseDuration(row.TotalTime);
  const category = String(row.RecipeCategory || 'General').trim();
  const normalizedTitle = cleanTitle(row.Name);

  const keywords = [];
  if (row.Keywords && String(row.Keywords).trim() !== 'NA' && String(row.Keywords).trim() !== 'nan') {
    const rawKeywords = parsePyList(row.Keywords);
    for (const keyword of rawKeywords) {
      const text = String(keyword || '').trim();
      if (text) keywords.push(text);
    }
  }

  return {
    recipeId: String(row.RecipeId || ''),
    title: normalizedTitle,
    description: category || normalizedTitle || 'Homemade recipe',
    category,
    englishKeywords: keywords,
    imageUrl: imageUrls[0] || null,
    imageUrls,
    prep_time_minutes: prepMin || Math.max(1, Math.floor((totalMin || 30) * 0.35)),
    cook_time_minutes: cookMin || Math.max(1, Math.ceil((totalMin || 30) * 0.65)),
    servings: Number(row.RecipeServings) || 4,
    difficulty: 'Medium',
    isPremium: false,
    ingredients: combined,
    steps: steps.map((description, index) => ({
      order: index + 1,
      description,
      duration_minutes: 0,
      imageUrl: null,
      ingredients: [],
    })),
    nutrition: {
      calories: Number(row.Calories) || 0,
      protein: Number(row.ProteinContent) || 0,
      carbs: Number(row.CarbohydrateContent) || 0,
      fat: Number(row.FatContent) || 0,
    },
    audioStepUrls: [],
  };
}

function validatePayload(mapped) {
  const errors = [];
  if (!mapped.title || mapped.title === 'Untitled Recipe') errors.push('invalid_title');
  if (!mapped.ingredients || mapped.ingredients.length === 0) errors.push('no_ingredients');
  if (!mapped.steps || mapped.steps.length === 0) errors.push('no_steps');
  if (!isValidImageUrl(mapped.imageUrl)) errors.push('invalid_image_url');
  if (!mapped.category) errors.push('no_category');
  if (mapped.title && mapped.title.length > 200) errors.push('title_too_long');
  return errors;
}

function buildAppwritePayload(mapped) {
  const ingredientsString = JSON.stringify(mapped.ingredients);
  const stepsString = buildStableStringifiedSteps(mapped.steps);
  const nutritionString = JSON.stringify(mapped.nutrition);

  // Final sanitization: encode spaces, strip control chars
  let safeImageUrl = null;
  if (mapped.imageUrl) {
    try {
      const u = new URL(mapped.imageUrl);
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
      english_keywords: mapped.englishKeywords,
      image_url: safeImageUrl,
      video_url: null,
      audio_step_urls: mapped.audioStepUrls,
      prep_time_minutes: mapped.prep_time_minutes,
      cook_time_minutes: mapped.cook_time_minutes,
      servings: mapped.servings,
      difficulty: mapped.difficulty,
      is_premium: mapped.isPremium,
      ingredients: ingredientsString,
      ingredients_json: ingredientsString,
      steps: stepsString,
      steps_json: stepsString,
      nutrition_json: nutritionString,
      created_at: new Date().toISOString(),
    },
  };
}

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
    if (res.status === 429 && attempt < MAX_RETRIES) {
      throw new Error(`rate_limited:${text}`);
    }
    return { ok: false, status: res.status, body: text };
  } catch (e) {
    clearTimeout(timer);
    if (attempt < MAX_RETRIES) {
      throw new Error(`retryable:${e.message}`);
    }
    throw e;
  }
}

async function pickImageUrl(imageUrls) {
  const strict = [];
  const heuristic = [];
  const seen = new Set();
  for (const url of imageUrls) {
    const trimmed = String(url).trim();
    if (!trimmed || seen.has(trimmed)) continue;
    seen.add(trimmed);
    if (isValidImageUrl(trimmed)) strict.push(trimmed);
    if (/^https?:\/\//i.test(trimmed) && /[a-z]/i.test(trimmed)) heuristic.push(trimmed);
  }

  const candidates = strict.length ? strict : heuristic;
  for (const url of candidates) {
    try {
      const alive = await isImageAlive(url);
      if (alive) return url;
    } catch (_) {
      continue;
    }
  }
  return null;
}

function shouldSkipByQuality(flags) {
  return flags.includes('missing_steps') || flags.includes('missing_ingredients') || flags.includes('missing_title') || flags.includes('broken_image');
}

async function processRow(row, state) {
  if (isShuttingDown) return 'interrupted';

  const flags = buildQualityFlags(row);
  if (shouldSkipByQuality(flags)) {
    state.skippedInvalid++;
    warn(`Skip invalid recipe ${row.RecipeId}: ${flags.join(', ')}`);
    saveCheckpoint(state);
    return 'skipped_invalid';
  }

  const mapped = mapRecipe(row);
  const validationErrors = validatePayload(mapped);
  if (validationErrors.length > 0) {
    state.skippedInvalid++;
    warn(`Skip validation failed recipe ${row.RecipeId}: ${validationErrors.join(', ')}`);
    saveCheckpoint(state);
    return 'skipped_invalid';
  }

  const imageUrl = await pickImageUrl(mapped.imageUrls);
  if (!imageUrl) {
    state.skippedBadImages++;
    warn(`Skip bad image recipe ${mapped.recipeId}: ${mapped.title}`);
    saveCheckpoint(state);
    return 'skipped_bad_image';
  }

  mapped.imageUrl = imageUrl;
  const payload = buildAppwritePayload(mapped);

  let lastError = null;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    if (isShuttingDown) return 'interrupted';

    const result = await createDocumentWithRetry(payload, attempt);
    if (result.ok) {
      state.success++;
      saveCheckpoint(state);
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

    // Non-retryable error — fail immediately
    state.failed++;
    err(`Appwrite ${result.status}: ${message}`);
    saveCheckpoint(state);
    await delay(DELAY_BETWEEN_RECIPES_MS);
    return 'failed';
  }

  // All retries exhausted
  state.failed++;
  err(`All ${MAX_RETRIES} retries failed. Last error: ${lastError}`);
  saveCheckpoint(state);
  await delay(DELAY_BETWEEN_RECIPES_MS);
  return 'failed';
}

async function main() {
  assertEnv();
  setupGracefulShutdown();

  if (!fs.existsSync(CSV_PATH)) {
    err('CSV not found:', CSV_PATH);
    process.exit(1);
  }

  const checkpoint = loadCheckpoint();
  log(`Resume checkpoint: index=${checkpoint.lastIndex}, success=${checkpoint.success}, failed=${checkpoint.failed}`);

  const state = {
    currentIndex: checkpoint.lastIndex,
    success: checkpoint.success,
    failed: checkpoint.failed,
    skippedBadImages: checkpoint.skippedBadImages,
    skippedInvalid: checkpoint.skippedInvalid,
  };

  const records = [];
  fs.createReadStream(CSV_PATH)
    .pipe(csvParser())
    .on('data', (row) => records.push(row))
    .on('end', async () => {
      log(`Loaded ${records.length} recipes from CSV`);
      const start = Math.min(state.currentIndex, records.length - 1);
      const pending = records.slice(start);
      log(`Processing ${pending.length} recipes starting from index ${start}`);

      for (const row of pending) {
        if (isShuttingDown) {
          warn('Shutdown requested — stopping early.');
          break;
        }
        state.currentIndex++;
        const status = await processRow(row, state);

        if (state.currentIndex % 20 === 0) {
          log(
            `Progress: ${state.currentIndex}/${records.length} | ` +
              `ok=${state.success} fail=${state.failed} bad_image=${state.skippedBadImages} invalid=${state.skippedInvalid}`
          );
        }
      }

      saveCheckpoint(state);
      console.log('\n' + '═'.repeat(60));
      log(
        `Bulk push complete — ` +
          `✅ ${state.success} | ❌ ${state.failed} | ` +
          `🚫 bad_image ${state.skippedBadImages} | ⚠ invalid ${state.skippedInvalid}`
      );
      console.log('═'.repeat(60));
    })
    .on('error', (e) => {
      err('CSV stream error:', e.message);
      process.exit(1);
    });
}

main().catch((fatal) => {
  err(fatal.message);
  process.exit(1);
});
