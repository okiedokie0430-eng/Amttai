/**
 * Amttai — Multi-Source Ingestion Dashboard Backend
 *
 * Supported pipelines (selectable per job):
 *   mealdb-translate  — TheMealDB + Google Translate (fast, free)
 *   mealdb-gemini     — TheMealDB + Gemini 2.5 Flash (higher quality)
 *   wikibooks-gemini  — Wikibooks Cookbook + Gemini 2.5 Flash (CC BY-SA 3.0)
 *
 * API surface:
 *   POST /api/start          — { source?, recipesPerRun? } → start job
 *   POST /api/stop           — cancel running job
 *   GET  /api/status         — current state JSON
 *   GET  /api/logs           — SSE stream
 *   GET  /api/history        — session history
 *   POST /api/logs/clear     — wipe log buffer
 *   GET  /api/config         — read config
 *   POST /api/config         — update config (blocked while running)
 */

import 'dotenv/config';
import express         from 'express';
import cors            from 'cors';
import { EventEmitter } from 'events';
import translate       from 'google-translate-api-x';
import { GoogleGenerativeAI } from '@google/generative-ai';
import wtf             from 'wtf_wikipedia';

// ─── Env ───────────────────────────────────────────────────────────────────────
const {
    APPWRITE_ENDPOINT,
    APPWRITE_PROJECT_ID,
    APPWRITE_API_KEY,
    APPWRITE_DATABASE_ID,
    APPWRITE_RECIPES_COLLECTION_ID,
    GEMINI_API_KEY,
    OPENROUTER_API_KEY,
    NVIDIA_API_KEY
} = process.env;

const MEALDB_URL  = 'https://www.themealdb.com/api/json/v1/1/random.php';
const WIKI_API    = 'https://en.wikibooks.org/w/api.php';
const USER_AGENT  = 'Amttai-Recipe-Bot/1.0 (mongolian-recipe-app; https://amttai.mn)';

const INGREDIENT_SECTIONS = ['Ingredients', 'Ingredient'];
const STEPS_SECTIONS      = ['Directions', 'Procedure', 'Instructions', 'Method', 'Steps', 'Preparation'];

// ─── Gemini Client ─────────────────────────────────────────────────────────────
let geminiModel = null;
if (GEMINI_API_KEY) {
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
    geminiModel = genAI.getGenerativeModel({
        model: 'gemini-2.5-flash',
        generationConfig: { responseMimeType: 'application/json' },
        systemInstruction:
            'You are an expert culinary translator. Translate the provided human-written English recipe ' +
            'into professional Mongolian Cyrillic. Do NOT alter measurements or add original content. ' +
            'Return ONLY JSON: { "title": "string", "ingredients": ["array"], "steps": ["array"] }',
    });
}

// ─── Runtime Config ────────────────────────────────────────────────────────────
let config = {
    source:          'dummyjson-gemini',   // 'mealdb-translate' | 'mealdb-gemini' | 'dummyjson-gemini'
    recipesPerRun:   parseInt(process.env.RECIPES_PER_RUN || '5', 10),
    delayMs:         3000,
    difficulty:      'Дунд',
    isPremium:       false,
    prepTimeMinutes: 15,
    cookTimeMinutes: 30,
    servings:        4,
};

// ─── Global State ──────────────────────────────────────────────────────────────
const jobEvents  = new EventEmitter();
jobEvents.setMaxListeners(50);

let isRunning    = false;
let shouldCancel = false;
let stats        = { success:0, failed:0, skipped:0, total:0, source:'', startedAt:null, finishedAt:null };
let logs         = [];
let history      = [];
const MAX_LOGS   = 1000;

// ─── Broadcast ─────────────────────────────────────────────────────────────────
function broadcastLog(message, type = 'info') {
    const entry = { id: `${Date.now()}-${Math.random()}`, timestamp: new Date().toISOString(), message, type };
    logs.push(entry);
    if (logs.length > MAX_LOGS) logs.shift();
    jobEvents.emit('log', entry);
    const p = `[${new Date().toLocaleTimeString()}]`;
    if (type === 'error') console.error(p, message);
    else if (type === 'warn') console.warn(p, message);
    else console.log(p, message);
}
function broadcastStats() { jobEvents.emit('stats', stats); }
function broadcastRecipe(recipe) { history.unshift(recipe); jobEvents.emit('recipe', recipe); }

const delay = (ms) => new Promise(r => setTimeout(r, ms));

function mapCategory(source, rawCategory, cuisine) {
    if (source === 'dummyjson') {
        const cuisineMap = {
            'Italian': 'Итали', 'Mexican': 'Мексик', 'Indian': 'Энэтхэг',
            'Chinese': 'Хятад', 'Japanese': 'Япон', 'French': 'Франц',
            'American': 'Америк', 'Thai': 'Тай', 'Greek': 'Грек',
            'Spanish': 'Испани', 'Mediterranean': 'Газрын дундад тэнгисийн',
            'Korean': 'Солонгос', 'Vietnamese': 'Вьетнам', 'British': 'Британи',
            'Irish': 'Ирланд', 'German': 'Герман', 'Turkish': 'Турк',
            'Moroccan': 'Морокко', 'Pakistani': 'Пакистан', 'Brazilian': 'Бразил',
            'Russian': 'Орос', 'Lebanese': 'Ливан', 'Peruvian': 'Перу',
            'Australian': 'Австрали', 'Filipino': 'Филиппин', 'Polish': 'Польш',
            'Kenyan': 'Кени', 'Tunisian': 'Тунис', 'Malaysian': 'Малайз',
            'Indonesian': 'Индонез', 'Canadian': 'Канад', 'Argentine': 'Аргентин',
            'Nepalese': 'Балба', 'Croatian': 'Хорват', 'Dutch': 'Голланд',
            'Danish': 'Дани', 'Swedish': 'Швед', 'Norwegian': 'Норвеги',
            'Finnish': 'Финланд', 'Portuguese': 'Португал', 'Cuban': 'Куба',
            'Hawaiian': 'Хавай', 'Hungarian': 'Унгар', 'South African': 'Өмнөд Африк',
            'Egyptian': 'Египет', 'Ethiopian': 'Этиоп', 'Persian': 'Перс',
            'Sri Lankan': 'Шри-Ланк', 'Bangladeshi': 'Бангладеш', 'Afghan': 'Афган',
            'Ukrainian': 'Украйн', 'Cajun': 'Кежун', 'Caribbean': 'Карибын',
            'Barbecue': 'Барбекью', 'Soul Food': 'Африк-Америк хоол',
            'Fusion': 'Холимог', 'Jewish': 'Еврей',
        };
        const c = rawCategory || cuisine;
        return cuisineMap[c] || c || 'Бусад';
    }
    if (source === 'mealdb') {
        const map = {
            'Beef': 'Үхрийн мах', 'Chicken': 'Тахиа', 'Dessert': 'Амттан',
            'Lamb': 'Хонины мах', 'Miscellaneous': 'Бусад', 'Pasta': 'Гоймон',
            'Pork': 'Гахайн мах', 'Seafood': 'Далайн хоол', 'Side': 'Дагалдах хоол',
            'Starter': 'Ундаа', 'Vegan': 'Веган', 'Vegetarian': 'Вегетариан',
            'Breakfast': 'Өглөөний цай', 'Goat': 'Ямаа', 'Soup': 'Шөл',
            'Salad': 'Салат', 'Curry': 'Карри', 'Pie': 'Балайсан',
        };
        return map[rawCategory] || rawCategory || 'Бусад';
    }
    return rawCategory || cuisine || 'Бусад';
}

function extractNutrition(item, llmNutrition = null) {
    // DummyJSON only provides caloriesPerServing; macros must come from LLM estimate.
    const parseVal = (v) => {
        if (v == null) return 0;
        if (typeof v === 'number') return v;
        const m = String(v).match(/^([0-9.]+)/);
        return m ? parseFloat(m[1]) : 0;
    };
    return {
        calories: parseVal(llmNutrition?.calories ?? item.caloriesPerServing ?? item.calories),
        protein:  parseVal(llmNutrition?.protein  ?? item.protein),
        carbs:    parseVal(llmNutrition?.carbs    ?? item.carbs ?? item.carbohydrates),
        fat:      parseVal(llmNutrition?.fat      ?? item.fat),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE A — TheMealDB + Google Translate
// ═══════════════════════════════════════════════════════════════════════════════
async function fetchMealDB() {
    const res  = await fetch(MEALDB_URL);
    if (!res.ok) throw new Error(`TheMealDB HTTP ${res.status}`);
    const json = await res.json();
    const meal = json?.meals?.[0];
    if (!meal) throw new Error('TheMealDB returned empty meal');
    return meal;
}

function mealIngredients(meal) {
    const out = [];
    for (let i = 1; i <= 20; i++) {
        const ing = (meal[`strIngredient${i}`] || '').trim();
        const msr = (meal[`strMeasure${i}`]    || '').trim();
        if (ing) out.push(msr ? `${msr} ${ing}` : ing);
    }
    return out;
}

function mealSteps(meal) {
    return (meal.strInstructions || '').trim()
        .split(/\r?\n/)
        .map(l => l.replace(/^\d+\.\s*/, '').trim())
        .filter(l => l.length > 5);
}

async function batchTranslate(arr) {
    if (!arr.length) return [];
    const res  = await translate(arr, { to: 'mn' });
    const norm = Array.isArray(res) ? res : [res];
    return norm.map((r, i) => r?.text || arr[i]);
}

async function runMealDBTranslate(i) {
    broadcastLog('Fetching from TheMealDB...', 'info');
    const meal = await fetchMealDB();
    broadcastLog(`Fetched: "${meal.strMeal}" (ID ${meal.idMeal})`, 'info');

    const rawIng   = mealIngredients(meal);
    const rawSteps = mealSteps(meal);
    broadcastLog(`Parsed: ${rawIng.length} ingredients · ${rawSteps.length} steps`, 'info');

    if (!rawSteps.length) { broadcastLog('No steps — skipping.', 'warn'); return null; }

    broadcastLog('Translating title...', 'info');
    const titleRes      = await translate(meal.strMeal, { to: 'mn' }).catch(e => { throw new Error(`Title: ${e.message}`); });
    const translatedTitle = titleRes?.text || meal.strMeal;
    broadcastLog(`"${meal.strMeal}" → "${translatedTitle}"`, 'success');

    broadcastLog(`Translating ${rawIng.length} ingredients...`, 'info');
    let tIng = rawIng;
    try { tIng = await batchTranslate(rawIng); } catch (e) { broadcastLog(`Ingredient fallback: ${e.message}`, 'warn'); }

    broadcastLog(`Translating ${rawSteps.length} steps...`, 'info');
    let tSteps = rawSteps;
    try { tSteps = await batchTranslate(rawSteps); } catch (e) { broadcastLog(`Steps fallback: ${e.message}`, 'warn'); }

    return {
        translatedTitle, tIng, tSteps,
        meta: { originalTitle: meal.strMeal, category: mapCategory('mealdb', meal.strCategory), imageUrl: meal.strMealThumb || null, source: 'mealdb-translate' },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE B — TheMealDB + Gemini
// ═══════════════════════════════════════════════════════════════════════════════
async function geminiTranslate(title, ingredients, steps) {
    if (!geminiModel) throw new Error('GEMINI_API_KEY is not configured.');
    const prompt =
        `Title: ${title}\n\nIngredients:\n${ingredients.map((g,i)=>`${i+1}. ${g}`).join('\n')}\n\nSteps:\n${steps.map((s,i)=>`${i+1}. ${s}`).join('\n')}`;
    const result  = await geminiModel.generateContent(prompt);
    const cleaned = result.response.text().trim()
        .replace(/^```(?:json)?\s*/im, '').replace(/\s*```$/m, '').trim();
    const parsed  = JSON.parse(cleaned);
    if (!parsed.title || !Array.isArray(parsed.ingredients) || !Array.isArray(parsed.steps))
        throw new Error('Gemini response missing required fields.');
    return parsed;
}

async function runMealDBGemini(i) {
    broadcastLog('Fetching from TheMealDB...', 'info');
    const meal = await fetchMealDB();
    broadcastLog(`Fetched: "${meal.strMeal}" (ID ${meal.idMeal})`, 'info');

    const rawIng   = mealIngredients(meal);
    const rawSteps = mealSteps(meal);
    broadcastLog(`Parsed: ${rawIng.length} ingredients · ${rawSteps.length} steps`, 'info');
    if (!rawSteps.length) { broadcastLog('No steps — skipping.', 'warn'); return null; }

    broadcastLog('Sending to Gemini for culinary translation...', 'info');
    const translated = await geminiTranslate(meal.strMeal, rawIng, rawSteps);
    broadcastLog(`"${meal.strMeal}" → "${translated.title}"`, 'success');

    return {
        translatedTitle: translated.title,
        tIng:            translated.ingredients,
        tSteps:          translated.steps,
        meta: { originalTitle: meal.strMeal, category: mapCategory('mealdb', meal.strCategory), imageUrl: meal.strMealThumb || null, source: 'mealdb-gemini' },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE C — Wikibooks + Gemini
// ═══════════════════════════════════════════════════════════════════════════════
function wikiGet(params) {
    const url = `${WIKI_API}?${new URLSearchParams({ format:'json', formatversion:'2', ...params })}`;
    return fetch(url, { headers: { 'User-Agent': USER_AGENT } }).then(r => r.json());
}

let dummyJsonCache = null;

async function fetchDummyJsonRecipe() {
    if (!dummyJsonCache) {
        dummyJsonCache = await fetchAllDummyJsonRecipes();
    }

    if (dummyJsonCache.length === 0) throw new Error("No DummyJSON recipes available in cache.");

    const item = dummyJsonCache.pop(); // Take one from the cache
    return item;
}

async function runDummyJsonGemini(i) {
    const item = await fetchDummyJsonRecipe();
    broadcastLog(`Fetched from DummyJSON: "${item.name}" (cuisine: ${item.cuisine || 'unknown'})`, 'info');

    broadcastLog('Sending to Gemini for culinary Mongolian translation...', 'info');

    const prompt = `Translate the following recipe into Mongolian Cyrillic.
For each ingredient, translate ONLY the ingredient name; KEEP the original numeric amount and measurement unit exactly as given (e.g., "1 cup flour" -> "1 аяга гурил", "2 tbsp sugar" -> "2 хоолны халбага элсэн чихэр", "1/2 tsp salt" -> "1/2 цайны халбага давс"). Do not invent amounts.
Also provide a "category" field in Mongolian based on the cuisine.
Estimate nutrition per serving based on the ingredients and return: "nutrition": { "calories": number, "protein": number, "carbs": number, "fat": number }.
Return ONLY JSON: { "title": "...", "category": "...", "nutrition": { "calories": ..., "protein": ..., "carbs": ..., "fat": ... }, "ingredients": [...], "steps": [...] }

Title: ${item.name}
Cuisine: ${item.cuisine || 'Unknown'}
Prep time: ${item.prepTimeMinutes} min
Cook time: ${item.cookTimeMinutes} min
Servings: ${item.servings}
Difficulty: ${item.difficulty}
Ingredients: ${JSON.stringify(item.ingredients)}
Instructions: ${JSON.stringify(item.instructions)}`;

    const response = await geminiModel.generateContent(prompt);
    const translated = JSON.parse(response.response.text());

    broadcastLog(`"${item.name}" → "${translated.title}"`, 'success');

    const category = translated.category || mapCategory('dummyjson', null, item.cuisine);

    return {
        translatedTitle: translated.title,
        tIng:            translated.ingredients,
        tSteps:          translated.steps,
        meta: {
            originalTitle: item.name,
            category,
            imageUrl: item.image,
            source: 'dummyjson-gemini',
            prepTimeMinutes: item.prepTimeMinutes,
            cookTimeMinutes: item.cookTimeMinutes,
            servings: item.servings,
            difficulty: item.difficulty,
            nutrition: extractNutrition(item, translated.nutrition),
        },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Appwrite Push (shared across all pipelines)
// ═══════════════════════════════════════════════════════════════════════════════
async function pushToAppwrite({ translatedTitle, tIng, tSteps, meta }) {
    const stepsJson = JSON.stringify(tSteps.map((description, idx) => ({ order: idx+1, description })));
    const url = `${APPWRITE_ENDPOINT}/databases/${APPWRITE_DATABASE_ID}/collections/${APPWRITE_RECIPES_COLLECTION_ID}/documents`;

    let diff = config.difficulty;
    const d = String(meta.difficulty || '').toLowerCase().trim();
    if (d === 'easy'   || d === 'хялбар') diff = 'Хялбар';
    if (d === 'medium' || d === 'дунд')   diff = 'Дунд';
    if (d === 'hard'   || d === 'хүнд')    diff = 'Хүнд';

    const res = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type':       'application/json',
            'X-Appwrite-Project': APPWRITE_PROJECT_ID,
            'X-Appwrite-Key':     APPWRITE_API_KEY,
        },
        body: JSON.stringify({
            documentId: 'unique()',
            data: {
                title:             translatedTitle,
                description:       tSteps[0] ?? translatedTitle,
                category:          meta.category,
                prep_time_minutes: meta.prepTimeMinutes || config.prepTimeMinutes,
                cook_time_minutes: meta.cookTimeMinutes || config.cookTimeMinutes,
                servings:          meta.servings || config.servings,
                difficulty:        diff,
                created_at:        new Date().toISOString(),
                image_url:         meta.imageUrl || null,
                is_premium:        config.isPremium,
                steps:             stepsJson,
                steps_json:        stepsJson,
                ingredients:       JSON.stringify(tIng),
                audio_step_urls:   [],
                nutrition_json:    meta.nutrition ? JSON.stringify(meta.nutrition) : null,
            },
        }),
    });

    if (!res.ok) { const b = await res.text(); throw new Error(`Appwrite POST ${res.status}: ${b}`); }
    return res.json();
}

// ─── Dispatcher ────────────────────────────────────────────────────────────────
const PIPELINE = {
    'mealdb-translate': runMealDBTranslate,
    'mealdb-gemini':    runMealDBGemini,
    'dummyjson-gemini': runDummyJsonGemini,
};

const SOURCE_LABELS = {
    'mealdb-translate':      'TheMealDB + Google Translate',
    'mealdb-gemini':          'TheMealDB + Gemini',
    'dummyjson-gemini':       'DummyJSON + Gemini',
    'dummyjson-openrouter':   'DummyJSON + NVIDIA (Batch)',
    'dummyjson-gemini-batch': 'DummyJSON + Gemini 2.5 Flash (Batch)',
};

// ─── NVIDIA Batch Ingestion (was OpenRouter) ────────────────────────────────────
const OR_BATCH_SIZE   = 5;   // recipes per request
const OR_BATCH_DELAY  = 45000; // ms between batches (NVIDIA free tier ~1 RPM guard)
const OR_MAX_RETRIES  = 4;
const OR_MODEL        = 'meta/llama-3.3-70b-instruct'; // NVIDIA-hosted, high-quality free tier

async function openRouterTranslateBatch(chunk) {
    const systemPrompt = `You are a professional culinary translator. Translate the following English recipes into Mongolian Cyrillic.
For each ingredient, translate ONLY the ingredient name; KEEP the original numeric amount and measurement unit exactly as given (e.g., "1 cup flour" -> "1 аяга гурил", "2 tbsp sugar" -> "2 хоолны халбага элсэн чихэр", "1/2 tsp salt" -> "1/2 цайны халбага давс"). Do not invent amounts.
You MUST return ONLY a valid JSON object containing a single key "recipes", which is an array of objects.
Each object must have exactly: "id" (original id), "title" (translated string), "category" (Mongolian category based on cuisine), "prepTimeMinutes" (number), "cookTimeMinutes" (number), "servings" (number), "difficulty" (string), "nutrition" ({ "calories": number, "protein": number, "carbs": number, "fat": number }), "ingredients" (array of strings), "steps" (array of strings).
Do not include any extra text or markdown outside the JSON.`;

    const promptData = chunk.map((r) => ({
        id: r.id, title: r.name, cuisine: r.cuisine,
        prepTimeMinutes: r.prepTimeMinutes, cookTimeMinutes: r.cookTimeMinutes,
        servings: r.servings, difficulty: r.difficulty,
        calories: r.caloriesPerServing ?? r.calories,
        protein: r.protein, carbs: r.carbs ?? r.carbohydrates, fat: r.fat,
        ingredients: r.ingredients, steps: r.instructions
    }));

    for (let attempt = 1; attempt <= OR_MAX_RETRIES; attempt++) {
        try {
            const reqRes = await fetch('https://integrate.api.nvidia.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${NVIDIA_API_KEY}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    model: OR_MODEL,
                    response_format: { type: 'json_object' },
                    messages: [
                        { role: 'system', content: systemPrompt },
                        { role: 'user', content: JSON.stringify(promptData) }
                    ],
                }),
            });

            if (reqRes.status === 429) {
                const retryAfter = parseInt(reqRes.headers.get('Retry-After') || '0', 10);
                const waitMs = retryAfter > 0 ? retryAfter * 1000 : Math.min(30000 * attempt, 120000);
                broadcastLog(`⏳ Rate limited (429). Waiting ${waitMs / 1000}s before retry ${attempt}/${OR_MAX_RETRIES}...`, 'warn');
                await delay(waitMs);
                continue;
            }

            if (!reqRes.ok) throw new Error(`OpenRouter API Error: ${reqRes.status} ${reqRes.statusText}`);

            const orData = await reqRes.json();
            const rawContent = orData.choices?.[0]?.message?.content || '';
            const cleaned = aggressiveJsonClean(rawContent);

            let parsed;
            try {
                parsed = JSON.parse(cleaned);
            } catch (parseErr) {
                const objectMatch = cleaned.match(/\{[\s\S]*\}/);
                if (objectMatch) {
                    parsed = JSON.parse(objectMatch[0]);
                } else {
                    throw parseErr;
                }
            }
            return parsed.recipes || [];
        } catch (err) {
            broadcastLog(`⚠️ NVIDIA batch parse failed (attempt ${attempt}/${OR_MAX_RETRIES}): ${err.message}`, 'warn');
            if (attempt < OR_MAX_RETRIES) {
                const waitMs = 3000 * attempt;
                broadcastLog(`Retrying in ${waitMs}ms...`, 'info');
                await delay(waitMs);
            }
        }
    }

    // Fallback: one-by-one via Gemini (if available) or return untranslated stubs
    broadcastLog('NVIDIA batch consistently failed. Falling back to Gemini one-by-one...', 'warn');
    const results = [];
    for (const item of chunk) {
        try {
            const single = await geminiSingleTranslate(item);
            results.push(single);
            broadcastLog(`✅ Fallback succeeded for "${item.name}"`, 'info');
        } catch (e) {
            broadcastLog(`❌ Fallback failed for "${item.name}": ${e.message}`, 'error');
            results.push({
                id: item.id,
                title: item.name,
                category: mapCategory('dummyjson', null, item.cuisine),
                prepTimeMinutes: item.prepTimeMinutes,
                cookTimeMinutes: item.cookTimeMinutes,
                servings: item.servings,
                difficulty: item.difficulty,
                nutrition: { calories: item.caloriesPerServing || 0, protein: 0, carbs: 0, fat: 0 },
                ingredients: item.ingredients,
                steps: item.instructions,
            });
        }
        await delay(500);
    }
    return results;
}

async function fetchAllDummyJsonRecipes() {
    broadcastLog('Fetching all recipes from DummyJSON (paginating until dry)...', 'info');

    const allRecipes = [];
    const pageSize = 100;
    let skip = 0;
    let page = 1;

    while (true) {
        if (shouldCancel) {
            broadcastLog('Fetch cancelled by user.', 'warn');
            break;
        }

        const res = await fetch(`https://dummyjson.com/recipes?limit=${pageSize}&skip=${skip}`);
        if (!res.ok) throw new Error(`DummyJSON HTTP ${res.status} (skip=${skip})`);
        const data = await res.json();
        const recipes = data.recipes || [];

        if (recipes.length === 0) {
            broadcastLog(`Page ${page} returned empty — reached end of dataset.`, 'info');
            break;
        }

        allRecipes.push(...recipes);
        broadcastLog(`Page ${page}: +${recipes.length} recipes (running total: ${allRecipes.length})`, 'info');

        if (recipes.length < pageSize) break; // last partial page
        skip += recipes.length;
        page++;
    }

    broadcastLog(`✅ Fetched ${allRecipes.length} recipes total from DummyJSON.`, 'success');
    return allRecipes;
}

async function runOpenRouterBatchIngestion() {
    stats = { success:0, failed:0, skipped:0, total: 0, source: 'dummyjson-openrouter', startedAt: new Date().toISOString(), finishedAt: null };
    broadcastStats();

    broadcastLog(`🚀 Starting "DummyJSON + NVIDIA (Batch)" — fetching all recipes`, 'system');
    broadcastLog(`Target: ${APPWRITE_ENDPOINT} / ${APPWRITE_DATABASE_ID} / ${APPWRITE_RECIPES_COLLECTION_ID}`, 'system');
    broadcastLog(`Model: ${OR_MODEL} · Batch size: ${OR_BATCH_SIZE} · Inter-batch delay: ${OR_BATCH_DELAY/1000}s · Max retries per batch: ${OR_MAX_RETRIES}`, 'system');

    try {
        const allRecipes = await fetchAllDummyJsonRecipes();
        stats.total = allRecipes.length;
        broadcastStats();
        broadcastLog(`✅ Fetched ${allRecipes.length} recipes. Splitting into batches of ${OR_BATCH_SIZE}...`, 'success');

        const chunks = [];
        for (let i = 0; i < allRecipes.length; i += OR_BATCH_SIZE) chunks.push(allRecipes.slice(i, i + OR_BATCH_SIZE));

        for (let i = 0; i < chunks.length; i++) {
            if (shouldCancel) break;
            const chunk = chunks[i];
            broadcastLog(`--- Batch ${i + 1}/${chunks.length} (${chunk.length} recipes) ---`, 'system');

            try {
                const translatedBatch = await openRouterTranslateBatch(chunk);

                for (const t of translatedBatch) {
                    if (shouldCancel) break;
                    const orig = chunk.find(c => c.id === t.id) || chunk[0];
                    const category = t.category || mapCategory('dummyjson', null, orig.cuisine);
                    const result = {
                        translatedTitle: t.title,
                        tIng: t.ingredients,
                        tSteps: t.steps,
                        meta: {
                            originalTitle: orig.name,
                            category,
                            imageUrl: orig.image,
                            source: 'dummyjson-openrouter',
                            prepTimeMinutes: t.prepTimeMinutes ?? orig.prepTimeMinutes,
                            cookTimeMinutes: t.cookTimeMinutes ?? orig.cookTimeMinutes,
                            servings: t.servings ?? orig.servings,
                            difficulty: t.difficulty ?? orig.difficulty,
                            nutrition: extractNutrition(orig, t.nutrition),
                        }
                    };

                    try {
                        const doc = await pushToAppwrite(result);
                        stats.success++;
                        broadcastRecipe({
                            id: doc.$id, title: result.translatedTitle, originalTitle: result.meta.originalTitle,
                            category: result.meta.category, steps: result.tSteps.length, ingredients: result.tIng.length,
                            imageUrl: result.meta.imageUrl, createdAt: new Date().toISOString(), status: 'success', source: 'dummyjson-openrouter',
                        });
                        broadcastLog(`✅ "${orig.name}" → "${result.translatedTitle}"`, 'success');
                    } catch (e) {
                        stats.failed++;
                        broadcastLog(`❌ Failed pushing "${orig.name}": ${e.message}`, 'error');
                    }
                }
            } catch (err) {
                stats.failed += chunk.length;
                broadcastLog(`❌ Batch ${i+1} failed: ${err.message}`, 'error');
            }

            broadcastStats();
            if (i < chunks.length - 1 && !shouldCancel) {
                broadcastLog(`⏱ Waiting ${OR_BATCH_DELAY/1000}s before next batch...`, 'info');
                await delay(OR_BATCH_DELAY);
            }
        }
    } catch (e) {
        broadcastLog(`❌ Ingestion failed: ${e.message}`, 'error');
    }

    stats.finishedAt = new Date().toISOString();
    broadcastStats();
    broadcastLog(`🏁 Ingestion ${shouldCancel ? 'cancelled' : 'complete'}! ✅ ${stats.success} succeeded · ❌ ${stats.failed} failed`, shouldCancel ? 'warn' : 'system');
    isRunning = false;
    shouldCancel = false;
}

// ─── Gemini Batch Ingestion ───────────────────────────────────────────────────
const GEMINI_BATCH_SIZE  = 5;   // recipes per Gemini request
const GEMINI_BATCH_DELAY = 8000; // ms between batches (keeps us well under 10 RPM free limit)

function aggressiveJsonClean(raw) {
    let s = raw.trim()
        .replace(/^```(?:json)?\s*/im, '')
        .replace(/\s*```$/m, '')
        .trim();
    // Remove trailing commas before ] or }
    s = s.replace(/,(\s*[}\]])/g, '$1');
    // Remove BOM and control chars
    s = s.replace(/\uFEFF/g, '');
    return s;
}

async function geminiSingleTranslate(item) {
    if (!geminiModel) throw new Error('GEMINI_API_KEY is not configured.');
    const prompt = `Translate the following recipe into Mongolian Cyrillic.
For each ingredient, translate ONLY the ingredient name; KEEP the original numeric amount and measurement unit exactly as given. Do not invent amounts.
Also provide a "category" field in Mongolian based on the cuisine.
Estimate nutrition per serving based on the ingredients and return: "nutrition": { "calories": number, "protein": number, "carbs": number, "fat": number }.
Return ONLY JSON: { "id": ${item.id}, "title": "...", "category": "...", "prepTimeMinutes": ${item.prepTimeMinutes}, "cookTimeMinutes": ${item.cookTimeMinutes}, "servings": ${item.servings}, "difficulty": "${item.difficulty}", "nutrition": { "calories": ..., "protein": ..., "carbs": ..., "fat": ... }, "ingredients": [...], "steps": [...] }

Title: ${item.name}
Cuisine: ${item.cuisine || 'Unknown'}
Ingredients: ${JSON.stringify(item.ingredients)}
Instructions: ${JSON.stringify(item.instructions)}`;

    const response = await geminiModel.generateContent(prompt);
    const cleaned = aggressiveJsonClean(response.response.text());
    const parsed = JSON.parse(cleaned);
    return parsed;
}

async function geminiBatchTranslate(chunk) {
    if (!geminiModel) throw new Error('GEMINI_API_KEY is not configured.');
    const promptData = chunk.map((r) => ({
        id: r.id, title: r.name, cuisine: r.cuisine,
        prepTimeMinutes: r.prepTimeMinutes, cookTimeMinutes: r.cookTimeMinutes,
        servings: r.servings, difficulty: r.difficulty,
        calories: r.caloriesPerServing ?? r.calories,
        protein: r.protein, carbs: r.carbs ?? r.carbohydrates, fat: r.fat,
        ingredients: r.ingredients, steps: r.instructions
    }));
    const prompt = `Translate the following ${chunk.length} English recipes into Mongolian Cyrillic.
For each ingredient, translate ONLY the ingredient name; KEEP the original numeric amount and measurement unit exactly as given (e.g., "1 cup flour" -> "1 аяга гурил", "2 tbsp sugar" -> "2 хоолны халбага элсэн чихэр"). Do not invent amounts.
For each recipe, also provide a "category" field in Mongolian based on its cuisine.
Estimate nutrition per serving for each recipe based on ingredients and include: "nutrition": { "calories": number, "protein": number, "carbs": number, "fat": number }.
Return ONLY valid JSON: { "recipes": [ { "id": <original id>, "title": "...", "category": "...", "prepTimeMinutes": number, "cookTimeMinutes": number, "servings": number, "difficulty": "...", "nutrition": { "calories": ..., "protein": ..., "carbs": ..., "fat": ... }, "ingredients": [...], "steps": [...] } ] }
Do NOT include markdown or any text outside the JSON.

Recipes:
${JSON.stringify(promptData)}`;

    for (let attempt = 1; attempt <= 3; attempt++) {
        try {
            const result = await geminiModel.generateContent(prompt);
            const raw = result.response.text();
            const cleaned = aggressiveJsonClean(raw);

            let parsed;
            try {
                parsed = JSON.parse(cleaned);
            } catch (parseErr) {
                // Try to extract JSON object from surrounding text
                const objectMatch = cleaned.match(/\{[\s\S]*\}/);
                if (objectMatch) {
                    parsed = JSON.parse(objectMatch[0]);
                } else {
                    throw parseErr;
                }
            }

            if (!Array.isArray(parsed.recipes)) {
                throw new Error('Gemini batch response missing "recipes" array.');
            }
            return parsed.recipes;
        } catch (err) {
            broadcastLog(`⚠️ Batch parse failed (attempt ${attempt}/3): ${err.message}`, 'warn');
            if (attempt < 3) {
                const waitMs = 2000 * attempt;
                broadcastLog(`Retrying batch in ${waitMs}ms...`, 'info');
                await delay(waitMs);
            }
        }
    }

    // Fallback: translate one-by-one
    broadcastLog('Batch consistently malformed. Falling back to one-by-one translation...', 'warn');
    const results = [];
    for (const item of chunk) {
        try {
            const single = await geminiSingleTranslate(item);
            results.push(single);
            broadcastLog(`✅ Individual fallback succeeded for "${item.name}"`, 'info');
        } catch (e) {
            broadcastLog(`❌ Individual fallback failed for "${item.name}": ${e.message}`, 'error');
            // Return a minimal translation so the batch can continue
            results.push({
                id: item.id,
                title: item.name,
                category: mapCategory('dummyjson', null, item.cuisine),
                prepTimeMinutes: item.prepTimeMinutes,
                cookTimeMinutes: item.cookTimeMinutes,
                servings: item.servings,
                difficulty: item.difficulty,
                nutrition: { calories: item.caloriesPerServing || 0, protein: 0, carbs: 0, fat: 0 },
                ingredients: item.ingredients,
                steps: item.instructions,
            });
        }
        await delay(500);
    }
    return results;
}

async function runGeminiBatchIngestion() {
    stats = { success:0, failed:0, skipped:0, total: 0, source: 'dummyjson-gemini-batch', startedAt: new Date().toISOString(), finishedAt: null };
    broadcastStats();

    broadcastLog(`🚀 Starting "DummyJSON + Gemini 2.5 Flash (Batch)" — fetching all recipes`, 'system');
    broadcastLog(`Target: ${APPWRITE_ENDPOINT} / ${APPWRITE_DATABASE_ID} / ${APPWRITE_RECIPES_COLLECTION_ID}`, 'system');
    broadcastLog(`Batch size: ${GEMINI_BATCH_SIZE} · Inter-batch delay: ${GEMINI_BATCH_DELAY/1000}s (10 RPM free tier guard)`, 'system');

    try {
        const allRecipes = await fetchAllDummyJsonRecipes();
        stats.total = allRecipes.length;
        broadcastStats();
        broadcastLog(`✅ Fetched ${allRecipes.length} recipes. Splitting into batches of ${GEMINI_BATCH_SIZE}...`, 'success');

        const chunks = [];
        for (let i = 0; i < allRecipes.length; i += GEMINI_BATCH_SIZE) chunks.push(allRecipes.slice(i, i + GEMINI_BATCH_SIZE));

        for (let i = 0; i < chunks.length; i++) {
            if (shouldCancel) break;
            const chunk = chunks[i];
            broadcastLog(`--- Batch ${i + 1}/${chunks.length} (${chunk.length} recipes) ---`, 'system');

            try {
                const translatedBatch = await geminiBatchTranslate(chunk);

                for (const t of translatedBatch) {
                    if (shouldCancel) break;
                    const orig = chunk.find(c => c.id === t.id) || chunk[0];
                    const category = t.category || mapCategory('dummyjson', null, orig.cuisine);
                    const result = {
                        translatedTitle: t.title,
                        tIng: t.ingredients,
                        tSteps: t.steps,
                        meta: {
                            originalTitle: orig.name,
                            category,
                            imageUrl: orig.image,
                            source: 'dummyjson-gemini-batch',
                            prepTimeMinutes: t.prepTimeMinutes ?? orig.prepTimeMinutes,
                            cookTimeMinutes: t.cookTimeMinutes ?? orig.cookTimeMinutes,
                            servings: t.servings ?? orig.servings,
                            difficulty: t.difficulty ?? orig.difficulty,
                            nutrition: extractNutrition(orig, t.nutrition),
                        }
                    };

                    try {
                        const doc = await pushToAppwrite(result);
                        stats.success++;
                        broadcastRecipe({
                            id: doc.$id, title: result.translatedTitle, originalTitle: result.meta.originalTitle,
                            category: result.meta.category, steps: result.tSteps.length, ingredients: result.tIng.length,
                            imageUrl: result.meta.imageUrl, createdAt: new Date().toISOString(), status: 'success', source: 'dummyjson-gemini-batch',
                        });
                        broadcastLog(`✅ "${orig.name}" → "${result.translatedTitle}"`, 'success');
                    } catch (e) {
                        stats.failed++;
                        broadcastLog(`❌ Failed pushing "${orig.name}": ${e.message}`, 'error');
                    }
                }
            } catch (err) {
                stats.failed += chunk.length;
                broadcastLog(`❌ Batch ${i+1} failed: ${err.message}`, 'error');
            }

            broadcastStats();
            if (i < chunks.length - 1 && !shouldCancel) {
                broadcastLog(`⏱ Waiting ${GEMINI_BATCH_DELAY/1000}s before next batch...`, 'info');
                await delay(GEMINI_BATCH_DELAY);
            }
        }
    } catch (e) {
        broadcastLog(`❌ Ingestion failed: ${e.message}`, 'error');
    }

    stats.finishedAt = new Date().toISOString();
    broadcastStats();
    broadcastLog(`🏁 Ingestion ${shouldCancel ? 'cancelled' : 'complete'}! ✅ ${stats.success} succeeded · ❌ ${stats.failed} failed`, shouldCancel ? 'warn' : 'system');
    isRunning = false;
    shouldCancel = false;
}

// ─── Main Job ──────────────────────────────────────────────────────────────────
async function runIngestion() {
    if (isRunning) return;
    isRunning    = true;
    shouldCancel = false;

    const src = config.source || 'mealdb-translate';
    
    if (src === 'dummyjson-openrouter') {
        await runOpenRouterBatchIngestion();
        return;
    }

    if (src === 'dummyjson-gemini-batch') {
        await runGeminiBatchIngestion();
        return;
    }

    stats = { success:0, failed:0, skipped:0, total: config.recipesPerRun, source: src, startedAt: new Date().toISOString(), finishedAt: null };
    broadcastStats();

    const useGemini  = src.includes('gemini');
    const iterDelay  = useGemini ? Math.max(config.delayMs, 4500) : config.delayMs;

    broadcastLog(`🚀 Starting "${SOURCE_LABELS[src]}" — ${config.recipesPerRun} recipes`, 'system');
    broadcastLog(`Target: ${APPWRITE_ENDPOINT} / ${APPWRITE_DATABASE_ID} / ${APPWRITE_RECIPES_COLLECTION_ID}`, 'system');
    if (useGemini) broadcastLog(`Delay locked to ${iterDelay}ms (Gemini 15 RPM guard)`, 'system');

    const runPipeline = PIPELINE[src];

    for (let i = 0; i < config.recipesPerRun; i++) {
        if (shouldCancel) { broadcastLog('⛔ Job cancelled by user.', 'warn'); break; }
        broadcastLog(`── Recipe ${i+1} / ${config.recipesPerRun} ──────────────────────`, 'step');

        try {
            const result = await runPipeline(i);

            if (!result) {
                stats.skipped++;
                stats.failed++;
                broadcastStats();
                broadcastRecipe({ id:null, title:`Recipe ${i+1}`, originalTitle:'—', category:'—', steps:0, ingredients:0, imageUrl:null, createdAt:new Date().toISOString(), status:'failed', source: src, error:'Missing sections — skipped' });
                continue;
            }

            broadcastLog('Pushing to Appwrite...', 'info');
            const doc = await pushToAppwrite(result);
            broadcastLog(`✅ Created [${doc.$id}]: "${result.translatedTitle}"`, 'success');
            stats.success++;

            broadcastRecipe({
                id:            doc.$id,
                title:         result.translatedTitle,
                originalTitle: result.meta.originalTitle,
                category:      result.meta.category,
                steps:         result.tSteps.length,
                ingredients:   result.tIng.length,
                imageUrl:      result.meta.imageUrl,
                createdAt:     new Date().toISOString(),
                status:        'success',
                source:        src,
            });

        } catch (e) {
            broadcastLog(`❌ Recipe ${i+1} failed: ${e.message}`, 'error');
            stats.failed++;
            broadcastRecipe({ id:null, title:`Recipe ${i+1}`, originalTitle:'—', category:'—', steps:0, ingredients:0, imageUrl:null, createdAt:new Date().toISOString(), status:'failed', source: src, error: e.message });
        }

        broadcastStats();

        if (i < config.recipesPerRun - 1 && !shouldCancel) {
            broadcastLog(`Waiting ${iterDelay/1000}s...`, 'info');
            await delay(iterDelay);
        }
    }

    stats.finishedAt = new Date().toISOString();
    broadcastStats();
    const label = shouldCancel ? 'cancelled' : 'complete';
    broadcastLog(`🏁 Ingestion ${label}! ✅ ${stats.success} succeeded · ❌ ${stats.failed} failed`, shouldCancel ? 'warn' : 'system');
    isRunning = false;
    shouldCancel = false;
}

// ─── Express App ───────────────────────────────────────────────────────────────
const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/logs', (req, res) => {
    res.setHeader('Content-Type',  'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection',    'keep-alive');
    res.flushHeaders();
    res.write(`data: ${JSON.stringify({ type:'init', logs, stats, history, config })}\n\n`);
    const onLog = e  => res.write(`data: ${JSON.stringify({ type:'log',    data:e })}\n\n`);
    const onSt  = s  => res.write(`data: ${JSON.stringify({ type:'stats',  data:s })}\n\n`);
    const onRec = r  => res.write(`data: ${JSON.stringify({ type:'recipe', data:r })}\n\n`);
    jobEvents.on('log', onLog); jobEvents.on('stats', onSt); jobEvents.on('recipe', onRec);
    req.on('close', () => { jobEvents.off('log',onLog); jobEvents.off('stats',onSt); jobEvents.off('recipe',onRec); });
});

app.post('/api/start', (req, res) => {
    if (isRunning) return res.status(409).json({ error: 'Job already running' });
    if (req.body?.source)         config.source         = req.body.source;
    if (req.body?.recipesPerRun)  config.recipesPerRun  = parseInt(req.body.recipesPerRun, 10);
    runIngestion();
    res.json({ message: 'Job started', config });
});

app.post('/api/stop',       (req, res) => { if (!isRunning) return res.status(400).json({ error:'No job running' }); shouldCancel=true; res.json({ message:'Cancellation requested' }); });
app.get ('/api/status',     (req, res) => res.json({ isRunning, stats, config }));
app.get ('/api/history',    (req, res) => res.json(history));
app.post('/api/logs/clear', (req, res) => { logs=[]; jobEvents.emit('log',{type:'clear'}); res.json({ message:'Logs cleared' }); });
app.get ('/api/config',     (req, res) => res.json(config));
app.post('/api/config',     (req, res) => { if (isRunning) return res.status(409).json({ error:'Cannot update config while running' }); config={...config,...req.body}; res.json(config); });

app.listen(3002, () => console.log('🌐 Amttai Ingestion Backend running on http://localhost:3002'));
