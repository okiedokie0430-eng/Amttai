import { Client, Databases } from 'node-appwrite';
import dotenv from 'dotenv';
dotenv.config();

const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);

async function run() {
    const res = await databases.listDocuments(process.env.APPWRITE_DATABASE_ID, process.env.APPWRITE_RECIPES_COLLECTION_ID);
    for (const d of res.documents) {
        if (d.steps) {
            console.log(`\nRecipe: ${d.title}`);
            console.log(d.steps);
        }
    }
}
run().catch(console.error);
