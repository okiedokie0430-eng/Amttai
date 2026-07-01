import 'dotenv/config';
import { GoogleGenerativeAI } from '@google/generative-ai';

// ─── Environment ───────────────────────────────────────────────────────────────
const GEMINI_API_KEY               = process.env.GEMINI_API_KEY;
const APPWRITE_ENDPOINT            = process.env.APPWRITE_ENDPOINT;
const APPWRITE_PROJECT_ID          = process.env.APPWRITE_PROJECT_ID;
const APPWRITE_API_KEY             = process.env.APPWRITE_API_KEY;
const APPWRITE_DATABASE_ID         = process.env.APPWRITE_DATABASE_ID;
const APPWRITE_RECIPES_COLLECTION_ID = process.env.APPWRITE_RECIPES_COLLECTION_ID;

if (!GEMINI_API_KEY) { console.error('GEMINI_API_KEY is not set in .env'); process.exit(1); }

// ─── Constants ─────────────────────────────────────────────────────────────────
const RECIPES_PER_RUN    = parseInt(process.env.RECIPES_PER_RUN || '5', 10);
const MEALDB_URL         = 'https://www.themealdb.com/api/json/v1/1/random.php';
const RATE_LIMIT_DELAY   = 4_500;   // 4.5 s — keeps us safely under 15 RPM on Gemini Free

// ─── Gemini Client ─────────────────────────────────────────────────────────────
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

// ─── Utilities ─────────────────────────────────────────────────────────────────
const delay = (ms) => new Promise((r) => setTimeout(r, ms));
const ts    = ()   => `[${new Date().toLocaleTimeString()}]`;
const log   = (...a) => console.log(ts(), ...a);
const warn  = (...a) => console.warn(ts(), '⚠ ', ...a);
const err   = (...a) => console.error(ts(), '✖ ', ...a);

// ─── Step 1 — Fetch from TheMealDB ────────────────────────────────────────────
async function fetchMeal() {
    const res = await fetch(MEALDB_URL);
    if (!res.ok) throw new Error(`TheMealDB HTTP ${res.status}`);
    const { meals } = await res.json();
    if (!meals?.[0]) throw new Error('TheMealDB returned empty payload');
    return meals[0];
}

// ─── Step 2 — Parse raw MealDB fields ─────────────────────────────────────────
function extractIngredients(meal) {
    const out = [];
    for (let i = 1; i <= 20; i++) {
        const ing = (meal[`strIngredient${i}`] || '').trim();
        const msr = (meal[`strMeasure${i}`]    || '').trim();
        if (ing) out.push(msr ? `${msr} ${ing}` : ing);
    }
    return out;
}

function extractSteps(meal) {
    return (meal.strInstructions || '')
        .split(/\r?\n/)
        .map((l) => l.replace(/^\d+\.\s*/, '').trim())
        .filter((l) => l.length > 5);
}

// ─── Step 3 — Gemini LLM Translation ──────────────────────────────────────────
const TRANSLATION_SCHEMA = `{
  "title": "<translated title as a single string>",
  "ingredients": ["<translated ingredient 1>", "..."],
  "steps": ["<translated step 1>", "..."]
}`;

async function translateWithGemini(title, ingredients, steps) {
    const prompt = `You are an expert culinary translator specialising in Mongolian cuisine and food culture.

Your task is to translate the following recipe data from English into natural, fluent Mongolian Cyrillic.
Use proper culinary terminology as it would appear in a Mongolian recipe book.
Translate all ingredient names and cooking units into their Mongolian equivalents where they exist.

---
TITLE: ${title}

INGREDIENTS:
${ingredients.map((g, i) => `${i + 1}. ${g}`).join('\n')}

STEPS:
${steps.map((s, i) => `${i + 1}. ${s}`).join('\n')}
---

Respond with ONLY a raw JSON object. Do NOT wrap it in markdown code fences (\`\`\`json).
Do NOT include any explanation, commentary, or extra text outside of the JSON.
The JSON MUST strictly follow this schema:
${TRANSLATION_SCHEMA}`;

    const result   = await model.generateContent(prompt);
    const rawText  = result.response.text().trim();

    // Strip markdown fences if the model disobeys instructions
    const cleaned = rawText
        .replace(/^```(?:json)?\s*/i, '')
        .replace(/\s*```$/,           '')
        .trim();

    return JSON.parse(cleaned);   // Throws if still invalid — caught by caller
}

// ─── Step 4 — Push to Appwrite (direct REST, bypassing SDK 1.6.0 bug) ─────────
async function pushToAppwrite(translated, meal) {
    const stepsJson = JSON.stringify(
        translated.steps.map((description, idx) => ({ order: idx + 1, description }))
    );

    const payload = {
        documentId: 'unique()',
        data: {
            // ── Required collection attributes ─────────────────────────────────
            title:             translated.title,
            description:       translated.steps[0] ?? translated.title,
            category:          meal.strCategory ?? 'Бусад',
            prep_time_minutes: 15,
            cook_time_minutes: 30,
            servings:          4,
            difficulty:        'Дунд',
            created_at:        new Date().toISOString(),

            // ── Optional enrichment attributes ─────────────────────────────────
            image_url:         meal.strMealThumb ?? null,
            is_premium:        false,
            steps:             stepsJson,
            steps_json:        stepsJson,
            ingredients:       JSON.stringify(translated.ingredients),
            audio_step_urls:   [],           // Placeholder — filled by TTS automation later
        },
    };

    const url = [
        APPWRITE_ENDPOINT,
        'databases', APPWRITE_DATABASE_ID,
        'collections', APPWRITE_RECIPES_COLLECTION_ID,
        'documents',
    ].join('/');

    const res = await fetch(url, {
        method:  'POST',
        headers: {
            'Content-Type':       'application/json',
            'X-Appwrite-Project': APPWRITE_PROJECT_ID,
            'X-Appwrite-Key':     APPWRITE_API_KEY,
        },
        body: JSON.stringify(payload),
    });

    if (!res.ok) {
        const body = await res.text();
        throw new Error(`Appwrite POST ${res.status}: ${body}`);
    }

    return res.json();
}

// ─── Main Loop ─────────────────────────────────────────────────────────────────
async function main() {
    log(`🚀 Gemini Ingestion Pipeline — ${RECIPES_PER_RUN} recipes`);
    log(`   Model  : gemini-1.5-flash`);
    log(`   Target : ${APPWRITE_ENDPOINT} / ${APPWRITE_DATABASE_ID} / ${APPWRITE_RECIPES_COLLECTION_ID}`);
    log(`   Delay  : ${RATE_LIMIT_DELAY}ms per recipe (Gemini 15 RPM guard)\n`);

    let success = 0;
    let failed  = 0;

    for (let i = 0; i < RECIPES_PER_RUN; i++) {
        log(`── Recipe ${i + 1} / ${RECIPES_PER_RUN} ${'─'.repeat(44)}`);

        try {
            // 1. Fetch
            log('Fetching from TheMealDB...');
            const meal        = await fetchMeal();
            log(`Fetched: "${meal.strMeal}" (ID ${meal.idMeal})`);

            // 2. Parse
            const ingredients = extractIngredients(meal);
            const steps       = extractSteps(meal);
            log(`Parsed: ${ingredients.length} ingredients · ${steps.length} steps`);

            if (steps.length === 0) {
                warn('No instruction steps found — skipping.');
                failed++;
                continue;
            }

            // 3. Translate via Gemini
            log('Sending to Gemini for culinary translation...');
            let translated;
            try {
                translated = await translateWithGemini(meal.strMeal, ingredients, steps);
            } catch (translationError) {
                err(`Gemini translation failed: ${translationError.message}`);
                err('The model may have returned malformed JSON. Skipping this recipe.');
                failed++;
                continue;
            }

            log(`Translated title: "${meal.strMeal}" → "${translated.title}"`);
            log(`Translated ${translated.ingredients.length} ingredients · ${translated.steps.length} steps`);

            // Validate schema completeness before pushing
            if (!translated.title || !Array.isArray(translated.ingredients) || !Array.isArray(translated.steps)) {
                err('Gemini response is missing required fields (title / ingredients / steps). Skipping.');
                failed++;
                continue;
            }

            // 4. Push to Appwrite
            log('Pushing document to Appwrite...');
            const doc = await pushToAppwrite(translated, meal);
            log(`✅ Created [${doc.$id}]: "${translated.title}"`);
            success++;

        } catch (recipeError) {
            err(`Recipe ${i + 1} failed: ${recipeError.message}`);
            failed++;
        }

        // Rate-limit guard: wait between every iteration, including the last
        if (i < RECIPES_PER_RUN - 1) {
            log(`Waiting ${RATE_LIMIT_DELAY}ms (Gemini RPM guard)...\n`);
            await delay(RATE_LIMIT_DELAY);
        }
    }

    console.log('\n' + '═'.repeat(52));
    log(`🏁 Pipeline complete — ✅ ${success} succeeded · ❌ ${failed} failed`);
    console.log('═'.repeat(52));
}

main().catch((fatal) => {
    console.error('\n[FATAL]', fatal.message);
    process.exit(1);
});
