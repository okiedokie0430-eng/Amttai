/**
 * Amttai — Fully Automated Remote Dataset Ingestion Pipeline
 * Fetches structured recipe JSON from the web, translates via Gemini Pro Structured Outputs,
 * and handles Appwrite REST insertion safely.
 */

import 'dotenv/config';
import { GoogleGenerativeAI, SchemaType } from '@google/generative-ai';

// ─── Environment Guards ────────────────────────────────────────────────────────
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const APPWRITE_ENDPOINT = process.env.APPWRITE_ENDPOINT;
const APPWRITE_PROJECT_ID = process.env.APPWRITE_PROJECT_ID;
const APPWRITE_API_KEY = process.env.APPWRITE_API_KEY;
const APPWRITE_DATABASE_ID = process.env.APPWRITE_DATABASE_ID;
const APPWRITE_RECIPES_COLLECTION_ID = process.env.APPWRITE_RECIPES_COLLECTION_ID;

for (const [k, v] of Object.entries({ GEMINI_API_KEY, APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_API_KEY, APPWRITE_DATABASE_ID, APPWRITE_RECIPES_COLLECTION_ID })) {
    if (!v) { console.error(`Missing required env var: ${k}`); process.exit(1); }
}

const RECIPES_PER_RUN = parseInt(process.env.RECIPES_PER_RUN || '5', 10);
const RATE_LIMIT_DELAY = 4500;

// ─── Gemini Pro Native Structured Outputs Setup ───────────────────────────────
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

// We mathematically constrain the AI to ONLY output this exact JSON shape.
const recipeSchema = {
    type: SchemaType.OBJECT,
    properties: {
        title: {
            type: SchemaType.STRING,
            description: "The translated name of the dish in Mongolian Cyrillic."
        },
        category: {
            type: SchemaType.STRING,
            description: "The cuisine category translated to Mongolian (e.g., Italian -> Итали, Mexican -> Мексик)."
        },
        nutrition: {
            type: SchemaType.OBJECT,
            description: "Estimated nutrition per serving based on ingredients.",
            properties: {
                calories: { type: SchemaType.NUMBER, description: "Estimated calories per serving." },
                protein:  { type: SchemaType.NUMBER, description: "Estimated protein in grams per serving." },
                carbs:    { type: SchemaType.NUMBER, description: "Estimated carbs in grams per serving." },
                fat:      { type: SchemaType.NUMBER, description: "Estimated fat in grams per serving." },
            },
            required: ["calories", "protein", "carbs", "fat"]
        },
        ingredients: {
            type: SchemaType.ARRAY,
            description: "List of ingredients translated to Mongolian with proper localized measurements.",
            items: { type: SchemaType.STRING }
        },
        steps: {
            type: SchemaType.ARRAY,
            description: "Sequential cooking instructions translated to Mongolian Cyrillic.",
            items: { type: SchemaType.STRING }
        }
    },
    required: ["title", "category", "nutrition", "ingredients", "steps"]
};

const model = genAI.getGenerativeModel({
    model: 'gemini-2.5-flash',
    generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: recipeSchema,
        temperature: 0.1
    },
    systemInstruction: `You are an elite culinary translator localizing international recipes for a commercial Mongolian application.
Translate the provided English recipe into professional, natural-sounding Mongolian Cyrillic.
For each ingredient, translate ONLY the ingredient name; KEEP the original numeric amount and measurement unit exactly as given (e.g., "1 cup flour" -> "1 аяга гурил", "2 tbsp sugar" -> "2 хоолны халбага элсэн чихэр"). Do not invent or alter amounts.
Do not alter temperatures or cooking times.
Translate measurement units into standard Mongolian terms (e.g., "cup" -> "аяга", "tbsp" -> "хоолны халбага").
Also translate the cuisine/category into Mongolian (e.g., "Italian" -> "Итали", "Mexican" -> "Мексик").
Estimate nutrition per serving based on the ingredients and return calories, protein (g), carbs (g), and fat (g).`
});

// ─── Utilities ─────────────────────────────────────────────────────────────────
const delay = (ms) => new Promise((r) => setTimeout(r, ms));
const ts = () => `[${new Date().toLocaleTimeString()}]`;
const log = (...a) => console.log(ts(), ...a);
const err = (...a) => console.error(ts(), '✖ ', ...a);

// ─── Appwrite Push (Direct REST API) ──────────────────────────────────────────
function extractNutrition(item) {
    const parseVal = (v) => {
        if (v == null) return 0;
        if (typeof v === 'number') return v;
        const m = String(v).match(/^([0-9.]+)/);
        return m ? parseFloat(m[1]) : 0;
    };
    return {
        calories: parseVal(item.caloriesPerServing ?? item.calories),
        protein:  parseVal(item.protein),
        carbs:    parseVal(item.carbs ?? item.carbohydrates),
        fat:      parseVal(item.fat),
    };
}

async function pushToAppwrite(translated, rawItem) {
    const stepsJson = JSON.stringify(translated.steps.map((description, idx) => ({ order: idx + 1, description })));

    let difficultyMongolian = 'Дунд';
    if (rawItem.difficulty === 'Easy') difficultyMongolian = 'Хялбар';
    if (rawItem.difficulty === 'Hard') difficultyMongolian = 'Хүнд';

    const category = translated.category || rawItem.cuisine || 'Бусад';
    const nutrition = extractNutrition(rawItem, translated.nutrition);
    const payload = {
        documentId: 'unique()',
        data: {
            title: translated.title,
            description: translated.steps[0] ?? translated.title,
            category,
            prep_time_minutes: rawItem.prepTimeMinutes || 15,
            cook_time_minutes: rawItem.cookTimeMinutes || 30,
            servings: rawItem.servings || 4,
            difficulty: difficultyMongolian,
            created_at: new Date().toISOString(),
            is_premium: false,
            steps: stepsJson,
            steps_json: stepsJson,
            ingredients: JSON.stringify(translated.ingredients),
            audio_step_urls: [],
            image_url: rawItem.image,
            nutrition_json: JSON.stringify(nutrition),
        },
    };

    const url = `${APPWRITE_ENDPOINT}/databases/${APPWRITE_DATABASE_ID}/collections/${APPWRITE_RECIPES_COLLECTION_ID}/documents`;

    const res = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-Appwrite-Project': APPWRITE_PROJECT_ID,
            'X-Appwrite-Key': APPWRITE_API_KEY,
        },
        body: JSON.stringify(payload),
    });

    if (!res.ok) throw new Error(`Appwrite POST ${res.status}: ${await res.text()}`);
    return res.json();
}

// ─── Main Orchestrator Loop ───────────────────────────────────────────────────
async function main() {
    log(`🚀 Amttai Fully Automated Pipeline Starting...`);

    // 1. Fetch the data directly from the internet into RAM
    let rawData = [];
    try {
        log('Fetching open-source recipe dataset from DummyJSON API...');
        // Grabbing 30 recipes at a time. This provides perfect JSON + Images
        const response = await fetch('https://dummyjson.com/recipes?limit=30');
        const data = await response.json();
        rawData = data.recipes;
        log(`✅ Successfully downloaded ${rawData.length} recipes into memory.`);
    } catch (fetchErr) {
        err(`Failed to download remote dataset: ${fetchErr.message}`);
        process.exit(1);
    }

    let success = 0;
    const runs = Math.min(RECIPES_PER_RUN, rawData.length);

    // 2. Loop through the downloaded data
    for (let i = 0; i < runs; i++) {
        const item = rawData[i];
        log(`── Recipe ${i + 1} / ${runs} [${item.name}] ──`);

        try {
            log('Translating via Gemini Pro...');
            const prompt = `Translate the following recipe:
            Title: ${item.name}
            Cuisine: ${item.cuisine || 'Unknown'}
            Prep time: ${item.prepTimeMinutes} min
            Cook time: ${item.cookTimeMinutes} min
            Servings: ${item.servings}
            Difficulty: ${item.difficulty}
            Calories per serving: ${item.caloriesPerServing ?? 'unknown'}
            Ingredients: ${JSON.stringify(item.ingredients)}
            Instructions: ${JSON.stringify(item.instructions)}`;

            const response = await model.generateContent(prompt);

            // Native structured outputs mean we don't have to clean or regex the string. 
            // It is mathematically guaranteed to be raw JSON.
            const translated = JSON.parse(response.response.text());

            log('Pushing directly to Appwrite console...');
            const doc = await pushToAppwrite(translated, item);
            log(`✅ Success! Saved [${doc.$id}]: "${translated.title}"`);
            success++;

        } catch (loopErr) {
            err(`Failed to process "${item.name}": ${loopErr.message}`);
        }

        if (i < runs - 1) {
            log(`Cooling down for ${RATE_LIMIT_DELAY}ms...`);
            await delay(RATE_LIMIT_DELAY);
        }
    }

    log(`🏁 Automation Run Complete! Successfully injected ${success} documents.`);
}

main().catch(console.error);
