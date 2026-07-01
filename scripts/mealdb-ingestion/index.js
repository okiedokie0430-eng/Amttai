/**
 * Amttai — MealDB Automated Ingestion & Translation Tool
 *
 * Workflow per recipe:
 *  1. Fetch a random recipe from TheMealDB (free, open-source API)
 *  2. Parse title, ingredients, and instruction steps
 *  3. Batch-translate everything to Mongolian via google-translate-api-x
 *  4. Push the translated document to the Appwrite `recipes` collection
 *     via direct REST POST (bypasses node-appwrite 1.6.0 serialisation bug)
 *
 * Usage: node index.js
 * Env:   see .env — RECIPES_PER_RUN controls how many recipes are fetched per invocation.
 */

import 'dotenv/config';
import translate from 'google-translate-api-x';

// ─── Config ────────────────────────────────────────────────────────────────────

const {
    APPWRITE_ENDPOINT,
    APPWRITE_PROJECT_ID,
    APPWRITE_API_KEY,
    APPWRITE_DATABASE_ID,
    APPWRITE_RECIPES_COLLECTION_ID,
} = process.env;

const RECIPES_PER_RUN   = parseInt(process.env.RECIPES_PER_RUN || '5', 10);
const MEALDB_RANDOM_URL = 'https://www.themealdb.com/api/json/v1/1/random.php';
const INTER_RECIPE_DELAY_MS = 3_000;   // Respect rate limits on both APIs

// ─── Utilities ─────────────────────────────────────────────────────────────────

/** Promise-based delay. */
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Pretty console prefix with timestamp. */
const log  = (msg) => console.log(`[${new Date().toLocaleTimeString()}] ${msg}`);
const warn = (msg) => console.warn(`[${new Date().toLocaleTimeString()}] ⚠️  ${msg}`);
const err  = (msg) => console.error(`[${new Date().toLocaleTimeString()}] ❌ ${msg}`);

// ─── Step 1: Fetch from TheMealDB ──────────────────────────────────────────────

async function fetchRandomMeal() {
    const res = await fetch(MEALDB_RANDOM_URL);
    if (!res.ok) throw new Error(`TheMealDB responded with HTTP ${res.status}`);
    const json = await res.json();
    const meal = json?.meals?.[0];
    if (!meal) throw new Error('TheMealDB returned an empty meal object.');
    return meal;
}

// ─── Step 2: Parse & Format ────────────────────────────────────────────────────

/**
 * Extracts ingredients from the MealDB flat key structure
 * (strIngredient1..20 + strMeasure1..20) into a clean string array.
 * Ignores blank/null pairs.
 */
function extractIngredients(meal) {
    const ingredients = [];
    for (let i = 1; i <= 20; i++) {
        const ingredient = (meal[`strIngredient${i}`] || '').trim();
        const measure    = (meal[`strMeasure${i}`]    || '').trim();
        if (ingredient) {
            ingredients.push(measure ? `${measure} ${ingredient}` : ingredient);
        }
    }
    return ingredients;
}

/**
 * Splits the flat strInstructions blob into individual, non-empty step strings.
 * Handles both Unix (\n) and Windows (\r\n) line endings as well as
 * numbered-list patterns like "1. Do this\n2. Do that".
 */
function extractSteps(meal) {
    const raw = (meal.strInstructions || '').trim();
    if (!raw) return [];

    return raw
        .split(/\r?\n/)                          // Split on newlines
        .map((line) => line.replace(/^\d+\.\s*/, '').trim()) // Strip leading "1. "
        .filter((line) => line.length > 5);     // Drop blank or trivially short lines
}

// ─── Step 3: Translate ─────────────────────────────────────────────────────────

/**
 * Translates an array of strings to Mongolian in a single batch API call.
 * Returns an equal-length array of translated strings.
 * Falls back to the original text if an individual item fails extraction.
 */
async function translateBatch(textArray) {
    if (textArray.length === 0) return [];

    // google-translate-api-x accepts an array and returns an array of result objects
    const results = await translate(textArray, { to: 'mn' });

    // Normalise: result may be a single object (when array has 1 item) or an array
    const normalized = Array.isArray(results) ? results : [results];

    return normalized.map((result, idx) => {
        const translated = result?.text;
        if (!translated) {
            warn(`Translation missing for item ${idx}: "${textArray[idx]}" — keeping original.`);
            return textArray[idx];
        }
        return translated;
    });
}

// ─── Step 4: Push to Appwrite ──────────────────────────────────────────────────

/**
 * Creates a new recipe document in the Appwrite `recipes` collection.
 *
 * Required fields (from the collection schema):
 *   title, description, category, prep_time_minutes, cook_time_minutes,
 *   servings, difficulty, created_at
 *
 * Optional rich fields stored as JSON strings (the collection's native pattern):
 *   steps, ingredients, steps_json, ingredients_json, audio_step_urls
 */
async function pushToAppwrite({ title, description, category, ingredients, steps, imageUrl }) {
    const url = `${APPWRITE_ENDPOINT}/databases/${APPWRITE_DATABASE_ID}/collections/${APPWRITE_RECIPES_COLLECTION_ID}/documents`;

    // Format steps as the JSON-stringified object array the TTS automation expects
    const stepsJson = JSON.stringify(
        steps.map((text, idx) => ({ order: idx + 1, description: text }))
    );

    const payload = {
        documentId: 'unique()',
        data: {
            // ── Required fields ────────────────────────────────────────────────
            title,
            description,            // Short summary (first step or auto-generated)
            category,               // MealDB strCategory
            prep_time_minutes: 15,  // MealDB does not provide these — sensible defaults
            cook_time_minutes: 30,
            servings:          4,
            difficulty:        'Дунд',   // Mongolian: "Medium"
            created_at:        new Date().toISOString(),

            // ── Optional enrichment fields ─────────────────────────────────────
            image_url:    imageUrl || null,
            is_premium:   false,
            steps:        stepsJson,           // TTS automation reads this field
            steps_json:   stepsJson,           // Redundant alias used by the Flutter app
            ingredients:  JSON.stringify(ingredients),
            audio_step_urls: [],
        },
    };

    const res = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type':       'application/json',
            'X-Appwrite-Project': APPWRITE_PROJECT_ID,
            'X-Appwrite-Key':     APPWRITE_API_KEY,
        },
        body: JSON.stringify(payload),
    });

    if (!res.ok) {
        const body = await res.text();
        throw new Error(`Appwrite POST failed (HTTP ${res.status}): ${body}`);
    }

    return await res.json();
}

// ─── Main Loop ─────────────────────────────────────────────────────────────────

async function run() {
    log(`🚀 Starting MealDB Ingestion — fetching ${RECIPES_PER_RUN} recipes...`);
    log(`   Target: ${APPWRITE_ENDPOINT} / DB: ${APPWRITE_DATABASE_ID} / Collection: ${APPWRITE_RECIPES_COLLECTION_ID}`);

    let successCount = 0;
    let failCount    = 0;

    for (let i = 0; i < RECIPES_PER_RUN; i++) {
        log(`\n── Recipe ${i + 1} / ${RECIPES_PER_RUN} ──────────────────────────────`);

        try {
            // ── 1. Fetch ──────────────────────────────────────────────────────
            log('Fetching random meal from TheMealDB...');
            const meal = await fetchRandomMeal();
            log(`Fetched: "${meal.strMeal}" (ID: ${meal.idMeal})`);

            // ── 2. Parse ──────────────────────────────────────────────────────
            const rawIngredients = extractIngredients(meal);
            const rawSteps       = extractSteps(meal);

            log(`Parsed ${rawIngredients.length} ingredients, ${rawSteps.length} steps.`);

            if (rawSteps.length === 0) {
                warn('No instruction steps found — skipping this recipe.');
                failCount++;
                continue;
            }

            // ── 3. Translate ──────────────────────────────────────────────────
            log('Translating title...');
            const [translatedTitleResult] = await translate(meal.strMeal, { to: 'mn' })
                .then(r => [r])
                .catch(e => { throw new Error(`Title translation failed: ${e.message}`); });
            const translatedTitle = translatedTitleResult?.text || meal.strMeal;
            log(`Title: "${meal.strMeal}" → "${translatedTitle}"`);

            log(`Batch-translating ${rawIngredients.length} ingredients...`);
            let translatedIngredients;
            try {
                translatedIngredients = await translateBatch(rawIngredients);
            } catch (e) {
                err(`Ingredient translation failed: ${e.message}. Keeping originals.`);
                translatedIngredients = rawIngredients;
            }

            log(`Batch-translating ${rawSteps.length} steps...`);
            let translatedSteps;
            try {
                translatedSteps = await translateBatch(rawSteps);
            } catch (e) {
                err(`Step translation failed: ${e.message}. Keeping originals.`);
                translatedSteps = rawSteps;
            }

            // ── 4. Push ───────────────────────────────────────────────────────
            log(`Pushing to Appwrite...`);
            const doc = await pushToAppwrite({
                title:       translatedTitle,
                description: translatedSteps[0] || translatedTitle, // First step as the recipe summary
                category:    meal.strCategory || 'Бусад',           // MealDB category (e.g. "Chicken")
                ingredients: translatedIngredients,
                steps:       translatedSteps,
                imageUrl:    meal.strMealThumb || null,
            });
            log(`✅ Created document [${doc.$id}]: "${translatedTitle}"`);
            successCount++;

        } catch (e) {
            err(`Recipe ${i + 1} failed: ${e.message}`);
            failCount++;
            // Continue gracefully — do not let one failure crash the whole batch
        }

        // Rate-limit guard — wait before next iteration (except after the last one)
        if (i < RECIPES_PER_RUN - 1) {
            log(`Waiting ${INTER_RECIPE_DELAY_MS / 1000}s before next recipe...`);
            await delay(INTER_RECIPE_DELAY_MS);
        }
    }

    log(`\n═══════════════════════════════════════════════`);
    log(`🏁 Ingestion complete!`);
    log(`   ✅ Success: ${successCount} / ${RECIPES_PER_RUN}`);
    if (failCount > 0) {
        log(`   ❌ Failed:  ${failCount} / ${RECIPES_PER_RUN}`);
    }
    log(`═══════════════════════════════════════════════`);
}

run().catch((fatalError) => {
    err(`Fatal error: ${fatalError.message}`);
    process.exit(1);
});
