import 'dotenv/config';

const {
  OPENROUTER_API_KEY,
  APPWRITE_ENDPOINT,
  APPWRITE_PROJECT_ID,
  APPWRITE_API_KEY,
  APPWRITE_DATABASE_ID,
  APPWRITE_RECIPES_COLLECTION_ID,
} = process.env;

if (
  !OPENROUTER_API_KEY ||
  !APPWRITE_ENDPOINT ||
  !APPWRITE_PROJECT_ID ||
  !APPWRITE_API_KEY ||
  !APPWRITE_DATABASE_ID ||
  !APPWRITE_RECIPES_COLLECTION_ID
) {
  console.error('[ERROR] Missing one or more required environment variables. Exiting.');
  process.exit(1);
}

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const chunkArray = (array, size) => {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
};

const fetchDummyJsonRecipes = async () => {
  try {
    console.log(`[${new Date().toISOString()}] Fetching recipes from DummyJSON...`);
    const res = await fetch('https://dummyjson.com/recipes?limit=50');
    if (!res.ok) throw new Error(`DummyJSON API Error: ${res.statusText}`);
    const data = await res.json();
    return data.recipes || [];
  } catch (error) {
    console.error(`[${new Date().toISOString()}] [ERROR] fetching DummyJSON recipes:`, error);
    process.exit(1);
  }
};

const translateRecipesBatch = async (recipesChunk) => {
  try {
    console.log(`[${new Date().toISOString()}] Translating chunk of ${recipesChunk.length} recipes...`);
    const promptData = recipesChunk.map((r) => ({
      id: r.id,
      title: r.name,
      ingredients: r.ingredients,
      steps: r.instructions,
    }));

    const systemPrompt = `You are a professional culinary translator. Translate the following English recipes into Mongolian Cyrillic. 
Localize measurements correctly (e.g., cup -> аяга, tbsp -> хоолны халбага). 
You MUST return ONLY a valid JSON object containing a single key "recipes", which is an array of objects. 
Each object in the array must have exactly these keys: "id" (keeping the original id), "title" (translated string), "ingredients" (array of translated strings), and "steps" (array of translated strings).
Do not include any extra text or markdown outside the JSON.`;

    const body = {
      model: 'google/gemma-4-31b-it:free',
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: JSON.stringify(promptData) }
      ],
    };

    const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      console.error(`[${new Date().toISOString()}] [ERROR] OpenRouter API Error: ${res.statusText}`);
      const errText = await res.text();
      console.error(errText);
      return [];
    }

    const data = await res.json();
    const content = data.choices[0].message.content;
    const parsed = JSON.parse(content);
    return parsed.recipes || [];
  } catch (error) {
    console.error(`[${new Date().toISOString()}] [ERROR] translating batch:`, error);
    return [];
  }
};

const pushToAppwrite = async (recipe) => {
  try {
    const formattedSteps = recipe.steps.map((step, index) => ({
      order: index + 1,
      description: step
    }));
    const stepsStringified = JSON.stringify(formattedSteps);
    
    const payload = {
      documentId: 'unique()',
      data: {
        title: recipe.title,
        description: recipe.steps[0] || recipe.title,
        category: 'Бусад',
        prep_time_minutes: 15,
        cook_time_minutes: 30,
        servings: 4,
        difficulty: 'Дунд',
        created_at: new Date().toISOString(),
        is_premium: false,
        steps: stepsStringified,
        steps_json: stepsStringified,
        ingredients: JSON.stringify(recipe.ingredients),
        audio_step_urls: [],
        is_published: true
      }
    };

    const res = await fetch(`${APPWRITE_ENDPOINT}/databases/${APPWRITE_DATABASE_ID}/collections/${APPWRITE_RECIPES_COLLECTION_ID}/documents`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Appwrite-Project': APPWRITE_PROJECT_ID,
        'X-Appwrite-Key': APPWRITE_API_KEY
      },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      console.error(`[${new Date().toISOString()}] [ERROR] Appwrite insertion failed for "${recipe.title}": ${res.statusText}`);
      const errText = await res.text();
      console.error(errText);
    } else {
      console.log(`[${new Date().toISOString()}] Successfully ingested: "${recipe.title}"`);
    }
  } catch (error) {
    console.error(`[${new Date().toISOString()}] [ERROR] pushing to Appwrite for "${recipe.title}":`, error);
  }
};

const main = async () => {
  console.log(`[${new Date().toISOString()}] Starting dataset ingestion script...`);
  const allRecipes = await fetchDummyJsonRecipes();
  console.log(`[${new Date().toISOString()}] Fetched ${allRecipes.length} recipes from DummyJSON.`);

  const chunks = chunkArray(allRecipes, 10);
  console.log(`[${new Date().toISOString()}] Split into ${chunks.length} batches of up to 10 recipes.`);

  for (let i = 0; i < chunks.length; i++) {
    console.log(`\n[${new Date().toISOString()}] --- Processing Batch ${i + 1}/${chunks.length} ---`);
    const translatedBatch = await translateRecipesBatch(chunks[i]);
    
    for (const translatedRecipe of translatedBatch) {
      await pushToAppwrite(translatedRecipe);
    }

    if (i < chunks.length - 1) {
      console.log(`[${new Date().toISOString()}] Waiting 5000ms before next batch...`);
      await delay(5000);
    }
  }

  console.log(`\n[${new Date().toISOString()}] Ingestion script completed successfully.`);
};

main();
