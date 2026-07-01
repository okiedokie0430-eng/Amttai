import { Client, Databases, Storage, ID } from 'node-appwrite';
import dotenv from 'dotenv';

dotenv.config();

const {
    APPWRITE_ENDPOINT,
    APPWRITE_PROJECT_ID,
    APPWRITE_API_KEY,
    APPWRITE_DATABASE_ID,
    APPWRITE_RECIPES_COLLECTION_ID,
    APPWRITE_BUCKET_ID
} = process.env;

const client = new Client()
    .setEndpoint(APPWRITE_ENDPOINT)
    .setProject(APPWRITE_PROJECT_ID)
    .setKey(APPWRITE_API_KEY);

const databases = new Databases(client);
const storage = new Storage(client);

async function initializeAppwrite() {
    console.log("🚀 Initializing Appwrite Configuration...");

    // 1. Create Database
    try {
        await databases.get(APPWRITE_DATABASE_ID);
        console.log(`✅ Database '${APPWRITE_DATABASE_ID}' already exists.`);
    } catch (e) {
        if (e.code === 404) {
            await databases.create(APPWRITE_DATABASE_ID, 'Amttai DB');
            console.log(`✅ Database '${APPWRITE_DATABASE_ID}' created.`);
        } else {
            console.error("Error creating database:", e.message);
            throw e;
        }
    }

    // 2. Create Collection
    try {
        await databases.getCollection(APPWRITE_DATABASE_ID, APPWRITE_RECIPES_COLLECTION_ID);
        console.log(`✅ Collection '${APPWRITE_RECIPES_COLLECTION_ID}' already exists.`);
    } catch (e) {
        if (e.code === 404) {
            await databases.createCollection(APPWRITE_DATABASE_ID, APPWRITE_RECIPES_COLLECTION_ID, 'Recipes');
            console.log(`✅ Collection '${APPWRITE_RECIPES_COLLECTION_ID}' created.`);
        } else {
            console.error("Error creating collection:", e.message);
            throw e;
        }
    }

    // 3. Create Attributes
    // We add a short delay between attribute creations because Appwrite processes them asynchronously
    const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

    const attributesToCreate = [
        { key: 'title', type: 'string', size: 255, required: false, array: false },
        { key: 'steps', type: 'string', size: 65535, required: false, array: true },
        { key: 'audio_step_urls', type: 'string', size: 65535, required: false, array: true }
    ];

    for (const attr of attributesToCreate) {
        try {
            await databases.createStringAttribute(
                APPWRITE_DATABASE_ID,
                APPWRITE_RECIPES_COLLECTION_ID,
                attr.key,
                attr.size,
                attr.required,
                undefined, // default
                attr.array
            );
            console.log(`✅ Attribute '${attr.key}' created. Waiting for Appwrite to process...`);
            await delay(2000); // Wait for attribute to be 'available'
        } catch (e) {
            if (e.code === 409) {
                console.log(`✅ Attribute '${attr.key}' already exists or is processing.`);
            } else {
                console.error(`❌ Error creating attribute '${attr.key}':`, e.message);
            }
        }
    }

    // 4. Create Storage Bucket
    try {
        await storage.getBucket(APPWRITE_BUCKET_ID);
        console.log(`✅ Bucket '${APPWRITE_BUCKET_ID}' already exists.`);
    } catch (e) {
        if (e.code === 404) {
            // true, false, false for fileSecurity, enabled, etc. We use defaults.
            await storage.createBucket(APPWRITE_BUCKET_ID, 'TTS Voices');
            console.log(`✅ Bucket '${APPWRITE_BUCKET_ID}' created.`);
        } else {
            console.error("Error creating bucket:", e.message);
            throw e;
        }
    }

    console.log("🎉 Appwrite Configuration Complete! The database schema and storage buckets are ready.");
}

initializeAppwrite().catch(err => {
    console.error("Initialization failed:", err);
});
