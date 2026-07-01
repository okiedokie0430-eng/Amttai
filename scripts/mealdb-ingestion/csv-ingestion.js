/**
 * Amttai — Large-Scale CSV Recipe Ingestion
 * Streams a Food.com-style CSV, translates batches via NVIDIA, pushes to Appwrite.
 * Usage: node csv-ingestion.js [path/to/RAW_recipes.csv]
 *        npm install csv-parser   (one-time)
 */

import 'dotenv/config';
import fs from 'fs';
import csvParser from 'csv-parser';

const {
  APPWRITE_ENDPOINT,
  APPWRITE_PROJECT_ID,
  APPWRITE_API_KEY,
  APPWRITE_DATABASE_ID,
  APPWRITE_RECIPES_COLLECTION_ID,
  NVIDIA_API_KEY
} = process.env;

const CSV_PATH        = process.argv[2] || 'recipes.csv';
const CHECKPOINT_FILE = 'csv-ingestion-checkpoint.json';
const BATCH_SIZE      = 1;     // one recipe at a time = max reliability, full output
const API_DELAY_MS    = 45000;
const MAX_RETRIES     = 4;
const NVIDIA_URL      = 'https://integrate.api.nvidia.com/v1/chat/completions';
const NVIDIA_MODEL    = 'meta/llama-4-maverick-17b-128e-instruct';      // Confirmed on NVIDIA free tier, good multilingual
const TOTAL_ESTIMATE  = 522517;

const delay = (ms) => new Promise(r => setTimeout(r, ms));
const ts    = () => `[${new Date().toLocaleTimeString()}]`;
const log   = (...a) => console.log(ts(), ...a);
const err   = (...a) => console.error(ts(), '✖', ...a);

/* ─── Checkpoint ───────────────────────────────────────────────────────────── */
function loadCheckpoint() {
  try { return JSON.parse(fs.readFileSync(CHECKPOINT_FILE, 'utf8')).lastIndex || 0; }
  catch { return 0; }
}
function saveCheckpoint(idx) {
  fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify({ lastIndex: idx, at: new Date().toISOString() }, null, 2));
}

/* ─── Clean marketing fluff from recipe titles ───────────────────────────── */
const MARKETING_WORDS = [
  'low-fat', 'low fat', 'low-protein', 'low protein', 'low-carb', 'low carb',
  'low-cholesterol', 'low cholesterol', 'low-sodium', 'low sodium',
  'fat-free', 'fat free', 'sugar-free', 'sugar free', 'gluten-free', 'gluten free',
  'dairy-free', 'dairy free', 'vegan', 'vegetarian', 'keto', 'paleo',
  'make and share this', 'recipe from food.com', 'recipe from', 'recipe',
  'easy', 'simple', 'quick', 'best', 'better than', 'ultimate', 'perfect',
  'amazing', 'delicious', 'tasty', 'yummy', 'healthy', 'homemade',
  'all in the', 'a bit different', 'a little different', 'backyard style',
  'beat this', 'berry good', 'boat house', 'calm your nerves',
];
function cleanTitle(title) {
  if (!title) return '';
  let t = title.toLowerCase();
  for (const w of MARKETING_WORDS) {
    const re = new RegExp(`\\b${w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'gi');
    t = t.replace(re, '');
  }
  // Remove extra punctuation and whitespace
  t = t.replace(/[^\w\s'-]/g, ' ').replace(/\s+/g, ' ').trim();
  // Capitalize first letter of each word
  return t.replace(/\b\w/g, c => c.toUpperCase()).trim() || title;
}

/* ─── List parser (handles c("a","b") and ["a","b"]) ─────────────────────── */
function parsePyList(str) {
  if (!str || str === 'NA' || str === 'nan') return [];
  let s = str.trim();
  // Strip outer quotes if present
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) s = s.slice(1, -1);
  s = s.trim();

  // Handle c("a","b") format
  if (s.startsWith('c(') && s.endsWith(')')) s = s.slice(2, -1).trim();

  // Handle ["a","b"] format
  if (s.startsWith('[') && s.endsWith(']')) s = s.slice(1, -1).trim();

  const items = [];
  let cur = '', inQ = false, qCh = null;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (!inQ && (c === "'" || c === '"')) { inQ = true; qCh = c; continue; }
    if (inQ && c === qCh) { inQ = false; qCh = null; continue; }
    if (!inQ && c === ',') { if (cur.trim()) items.push(cur.trim()); cur = ''; continue; }
    if (!inQ && /\s/.test(c)) { /* skip whitespace outside quotes */ }
    else { cur += c; }
  }
  if (cur.trim()) items.push(cur.trim());
  return items;
}

/* ─── ISO 8601 duration parser ───────────────────────────────────────────── */
function parseIsoDuration(dur) {
  if (!dur || typeof dur !== 'string') return 0;
  dur = dur.trim();
  if (!dur.startsWith('PT')) return 0;
  let m = dur.match(/(\d+)H/);  const hours = m ? parseInt(m[1]) : 0;
  m = dur.match(/(\d+)M/); const mins  = m ? parseInt(m[1]) : 0;
  return hours * 60 + mins || 30;
}

/* ─── Combine quantities + ingredient parts ──────────────────────────────── */
function combineIngredients(qtyStr, partStr) {
  const q = parsePyList(qtyStr);
  const p = parsePyList(partStr);
  const combined = [];
  for (let i = 0; i < Math.max(q.length, p.length); i++) {
    const qty = q[i] || '';
    const part = p[i] || '';
    if (qty && part) combined.push(`${qty} ${part}`);
    else if (part) combined.push(part);
  }
  return combined;
}

/* ─── Validate & extract first working image URL ────────────────────────── */
function isValidUrl(str) {
  try {
    const u = new URL(str);
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch { return false; }
}

async function checkImageAlive(url) {
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 5000);
    const res = await fetch(url, {
      method: 'HEAD',
      signal: controller.signal,
      redirect: 'follow',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'image/webp,image/apng,image/*,*/*',
      }
    });
    clearTimeout(t);
    return res.ok;
  } catch { return false; }
}

async function extractFirstImage(str) {
  const urls = parsePyList(str);
  for (const raw of urls) {
    if (!isValidUrl(raw)) continue;
    // Appwrite string fields often max at 256 chars by default; be safe
    if (raw.length > 2000) continue;
    if (await checkImageAlive(raw)) return raw;
  }
  return null;
}

/* ─── Nutrition from CSV fields ──────────────────────────────────────────── */
function extractCsvNutrition(row) {
  const n = (v) => {
    const f = parseFloat(v);
    return isNaN(f) ? 0 : f;
  };
  return {
    calories: n(row.Calories),
    fat:      n(row.FatContent),
    protein:  n(row.ProteinContent),
    carbs:    n(row.CarbohydrateContent),
  };
}

/* ─── Category / Difficulty from keywords ──────────────────────────────── */
const CUISINE_MAP = {
  mexican:'Мексик', italian:'Итали', american:'Америк', chinese:'Хятад',
  indian:'Энэтхэг', japanese:'Япон', french:'Франц', thai:'Тай',
  mediterranean:'Газрын дундад тэнгис', greek:'Грек', spanish:'Испани',
  german:'Герман', korean:'Солонгос', vietnamese:'Вьетнам', moroccan:'Марокко',
  british:'Британи', irish:'Ирланд', cajun:'Кажун', creole:'Креол',
  african:'Африк', 'middle-eastern':'Ойрхи Дорнод', caribbean:'Карибийн',
  brazilian:'Бразил', filipino:'Филиппин', russian:'Орос', hungarian:'Унгар',
  polish:'Польш', turkish:'Турк', lebanese:'Ливан', ethiopian:'Этиоп',
  portuguese:'Португал', cuban:'Куба', hawaiian:'Гавай', asian:'Ази',
  european:'Европ', 'north-american':'Хойд Америк', 'south-american':'Өмнөд Америк'
};
const COURSE_MAP = {
  'main-dish':'Үндсэн хоол', 'side-dishes':'Дагалдах хоол', appetizers:'Ундаа',
  desserts:'Амттан', breakfast:'Өглөөний цай', beverages:'Ундаа', soups:'Шөл',
  salads:'Салат', breads:'Талх', snacks:'Бөглөөх хоол', lunch:'Өдрийн хоол',
  'condiments-etc':'Амтлагч'
};

function categoryFromKeywords(keywords) {
  for (const t of keywords) { const m = CUISINE_MAP[t.toLowerCase()]; if (m) return m; }
  for (const t of keywords) { const m = COURSE_MAP[t.toLowerCase()]; if (m) return m; }
  return 'Бусад';
}
function difficultyFromKeywords(keywords) {
  const low = keywords.map(t => t.toLowerCase());
  if (low.includes('easy') || low.includes('simple')) return 'Хялбар';
  if (low.includes('hard') || low.includes('difficult')) return 'Хүнд';
  return 'Дунд';
}

/* ─── Aggressive JSON cleaning ───────────────────────────────────────────── */
function cleanJson(raw) {
  let s = raw.trim().replace(/^```(?:json)?\s*/im, '').replace(/\s*```$/m, '').trim();
  s = s.replace(/,(\s*[}\]])/g, '$1');
  s = s.replace(/\uFEFF/g, '');
  return s;
}

/* ─── NVIDIA Single Recipe Translation ───────────────────────────────────── */
async function nvidiaTranslate(row) {
  const keywords = parsePyList(row.Keywords);
  const ingredients = combineIngredients(row.RecipeIngredientQuantities, row.RecipeIngredientParts);
  const steps = parsePyList(row.RecipeInstructions);
  const promptData = {
    id: row.RecipeId,
    title: cleanTitle(row.Name),
    minutes: parseIsoDuration(row.TotalTime),
    prepMinutes: parseIsoDuration(row.PrepTime),
    cookMinutes: parseIsoDuration(row.CookTime),
    servings: parseInt(row.RecipeServings) || 4,
    category: row.RecipeCategory || categoryFromKeywords(keywords),
    keywords: keywords.slice(0, 8),
    ingredients,
    steps,
  };

  const systemPrompt = `You are a professional culinary translator. Translate this English recipe into Mongolian Cyrillic.

CRITICAL RULES:
1. KEEP all numeric amounts and measurement units exactly as given. Do NOT invent amounts.
2. Translate these English cooking units into Mongolian:
   - tsp / teaspoon → "цайны халбага"
   - tbsp / tablespoon → "хоолны халбага"
   - cup → "аяга"
   - oz / ounce → "унци"
   - lb / pound → "фунт"
   - g / gram → "гр"
   - kg / kilogram → "кг"
   - ml / milliliter → "мл"
   - l / liter → "л"
   - pinch → "хумс"
   - dash → "унадас"
   - pkg / package → "багц"
   - can → "lata"
   - bottle → "шил"
   - slice → "зүсэм"
   - clove → "хумс" (garlic)
3. Keep step descriptions in their FULL form. Do NOT shorten or summarize steps.
4. Return ONLY a single flat JSON object (NOT wrapped in a "recipes" array). Fields:
   "id", "title", "category", "prepTimeMinutes" (number), "cookTimeMinutes" (number), "servings" (number), "difficulty" ("Хялбар" / "Дунд" / "Хүнд"), "nutrition" {"calories":number,"protein":number,"carbs":number,"fat":number}, "ingredients" (array of strings), "steps" (array of objects: {"description": string, "durationMinutes": number}).
5. Estimate durationMinutes for each step. If unclear, use 0.
6. No markdown, no extra text outside the JSON.`;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    const controller = new AbortController();
    let timeoutId;
    try {
      timeoutId = setTimeout(() => controller.abort(), 180000); // 3 min — free-tier inference is slow
      const res = await fetch(NVIDIA_URL, {
        method: 'POST',
        signal: controller.signal,
        headers: { 'Authorization': `Bearer ${NVIDIA_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: NVIDIA_MODEL,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user',   content: JSON.stringify(promptData) }
          ]
        }),
      });
      clearTimeout(timeoutId);
      timeoutId = null;

      if (res.status === 429) {
        const w = 30000 * attempt;
        log(`Rate limited. Waiting ${w/1000}s...`); await delay(w); continue;
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      const data = await res.json();
      const rawText = data.choices?.[0]?.message?.content || '';
      const cleaned = cleanJson(rawText);

      let parsed;
      try { parsed = JSON.parse(cleaned); }
      catch (e) {
        // Try to extract any valid JSON object from the mess
        const m = cleaned.match(/\{[\s\S]*\}/);
        if (m) {
          try { parsed = JSON.parse(m[0]); }
          catch {
            // Last resort: try to close truncated JSON
            const lastBrace = cleaned.lastIndexOf('}');
            if (lastBrace > 0) {
              const fixed = cleaned.slice(0, lastBrace + 1);
              try { parsed = JSON.parse(fixed); }
              catch { throw e; }
            } else { throw e; }
          }
        } else { throw e; }
      }
      // Single recipe mode: return the object directly
      if (typeof parsed !== 'object' || parsed === null) throw new Error('Invalid JSON response');
      return parsed;
    } catch (e) {
      if (timeoutId) clearTimeout(timeoutId);
      if (e.name === 'AbortError') {
        err(`Batch attempt ${attempt}/${MAX_RETRIES}: Request timed out (60s)`);
      } else {
        err(`Batch attempt ${attempt}/${MAX_RETRIES}: ${e.message}`);
      }
      if (attempt < MAX_RETRIES) await delay(2000 * attempt);
    }
  }
  throw new Error('All retries exhausted');
}

/* ─── Appwrite Push ──────────────────────────────────────────────────────── */
async function pushToAppwrite(t, orig) {
  // Handle steps that may be strings (old format) or objects with durationMinutes
  const normalizedSteps = t.steps.map((step, i) => {
    if (typeof step === 'string') {
      return { order: i + 1, description: step, duration_minutes: 0 };
    }
    return {
      order: i + 1,
      description: step.description || step,
      duration_minutes: step.durationMinutes || 0,
    };
  });

  // Build steps JSON — try FULL form first. Truncation is a fallback on Appwrite 400.
  function buildStepsJson(stepsArray, maxDesc = null) {
    const arr = stepsArray.map(s => maxDesc ? { ...s, description: s.description.slice(0, maxDesc) } : s);
    return JSON.stringify(arr);
  }
  let stepsJson = buildStepsJson(normalizedSteps);
  let stepsWereTruncated = false;

  let diff = 'Дунд';
  const d = String(t.difficulty || '').toLowerCase().trim();
  if (d === 'easy' || d === 'хялбар') diff = 'Хялбар';
  if (d === 'hard' || d === 'хүнд')    diff = 'Хүнд';

  // Use original CSV nutrition if LLM didn't provide better
  const llmNutrition = t.nutrition || {};
  const origNutrition = extractCsvNutrition(orig);
  const nutrition = {
    calories: llmNutrition.calories || origNutrition.calories,
    protein:  llmNutrition.protein  || origNutrition.protein,
    carbs:    llmNutrition.carbs    || origNutrition.carbs,
    fat:      llmNutrition.fat      || origNutrition.fat,
  };
  const prepMin = t.prepTimeMinutes || parseIsoDuration(orig.PrepTime);
  const cookMin = t.cookTimeMinutes || parseIsoDuration(orig.CookTime);
  const keywords = parsePyList(orig.Keywords);
  const imageUrl = await extractFirstImage(orig.Images);

  const payload = {
    documentId: 'unique()',
    data: {
      title:             t.title,
      description:       '',
      category:          t.category || categoryFromKeywords(keywords),
      prep_time_minutes: prepMin || Math.floor(parseIsoDuration(orig.TotalTime) * 0.3),
      cook_time_minutes: cookMin || Math.ceil(parseIsoDuration(orig.TotalTime) * 0.7),
      servings:          t.servings || parseInt(orig.RecipeServings) || 4,
      difficulty:        diff,
      created_at:        new Date().toISOString(),
      is_premium:        false,
      steps:             stepsJson,
      steps_json:        stepsJson,
      ingredients:       JSON.stringify(t.ingredients),
      audio_step_urls:   [],
      image_url:         imageUrl,
      nutrition_json:    JSON.stringify(nutrition),
    }
  };

  const url = `${APPWRITE_ENDPOINT}/databases/${APPWRITE_DATABASE_ID}/collections/${APPWRITE_RECIPES_COLLECTION_ID}/documents`;
  let res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Appwrite-Project': APPWRITE_PROJECT_ID,
      'X-Appwrite-Key': APPWRITE_API_KEY,
    },
    body: JSON.stringify(payload),
  });

  // Fallback: if steps too long for Appwrite, truncate and retry
  if (!res.ok && res.status === 400) {
    const txt = await res.text();
    if (txt.includes('4000') || txt.includes('no longer than')) {
      err(`Steps too long (${stepsJson.length} chars). Truncating and retrying...`);
      stepsJson = buildStepsJson(normalizedSteps, 120);
      if (stepsJson.length > 3950) stepsJson = buildStepsJson(normalizedSteps, 60);
      payload.data.steps = stepsJson;
      payload.data.steps_json = stepsJson;
      stepsWereTruncated = true;
      res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Appwrite-Project': APPWRITE_PROJECT_ID,
          'X-Appwrite-Key': APPWRITE_API_KEY,
        },
        body: JSON.stringify(payload),
      });
    }
    if (!res.ok) { const txt2 = await res.text(); throw new Error(`Appwrite ${res.status}: ${txt2}`); }
  } else if (!res.ok) {
    const txt = await res.text(); throw new Error(`Appwrite ${res.status}: ${txt}`);
  }
  return { json: await res.json(), truncated: stepsWereTruncated };
}

/* ─── Main Loop ──────────────────────────────────────────────────────────── */
async function main() {
  if (!NVIDIA_API_KEY || !APPWRITE_API_KEY) {
    err('Missing NVIDIA_API_KEY or APPWRITE_API_KEY in .env'); process.exit(1);
  }
  if (!fs.existsSync(CSV_PATH)) { err(`CSV not found: ${CSV_PATH}`); process.exit(1); }

  const skipIndex = loadCheckpoint();
  log(`Resuming from row ${skipIndex.toLocaleString()}`);

  let rowIndex = 0, processed = skipIndex, success = 0, failed = 0, truncatedCount = 0;
  const t0 = Date.now();

  process.on('SIGINT', () => { log('Interrupted. Saving checkpoint...'); saveCheckpoint(processed); process.exit(0); });

  const stream = fs.createReadStream(CSV_PATH).pipe(csvParser());

  for await (const row of stream) {
    rowIndex++;
    if (rowIndex <= skipIndex) continue;

    const r0 = Date.now();
    log(`─ Recipe ${rowIndex}: "${cleanTitle(row.Name).slice(0, 50)}"`);

    try {
      const translated = await nvidiaTranslate(row);
      const result = await pushToAppwrite(translated, row);
      if (result.truncated) truncatedCount++;
      if (!result.json?.image_url) log(`⚠️ Recipe ${rowIndex}: no valid image`);
      success++;
      processed = rowIndex;
      saveCheckpoint(processed);
    } catch (e) {
      err(`Recipe ${rowIndex} failed: ${e.message}`);
      failed++;
    }

    const elapsedMin = (Date.now() - t0) / 60000;
    const rate = processed / elapsedMin;
    const remaining = TOTAL_ESTIMATE - processed;
    const etaHr = remaining / (rate || 1) / 60;
    log(`✅ ${processed.toLocaleString()} | Succ ${success} | Fail ${failed} | Trunc ${truncatedCount} | ${rate.toFixed(2)}/min | ETA ${etaHr.toFixed(1)}h`);

    const spent = Date.now() - r0;
    const wait = Math.max(0, API_DELAY_MS - spent);
    if (wait > 0) { log(`⏳ Rate guard ${(wait/1000).toFixed(1)}s...`); await delay(wait); }
  }

  log('🏁 Ingestion complete.');
}

main().catch(e => { err(e.message); process.exit(1); });
