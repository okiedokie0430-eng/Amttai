import { Client, Databases } from 'node-appwrite';
import dotenv from 'dotenv';
dotenv.config();

const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);

databases.listDocuments(process.env.APPWRITE_DATABASE_ID, process.env.APPWRITE_RECIPES_COLLECTION_ID)
    .then(res => {
        const withSteps = res.documents.filter(d => d.steps && d.steps.length > 0);
        console.log(`Found ${withSteps.length} recipes with steps out of ${res.documents.length} total recipes.`);
        if (withSteps.length > 0) {
            console.log("Example:", withSteps[0].title);
            console.log("Steps:", withSteps[0].steps);
        } else {
            // Check steps_json
            const withStepsJson = res.documents.filter(d => d.steps_json);
            console.log(`Found ${withStepsJson.length} recipes with steps_json.`);
            if (withStepsJson.length > 0) {
                 console.log("Example:", withStepsJson[0].title);
                 console.log("Steps JSON:", withStepsJson[0].steps_json);
            }
        }
    })
    .catch(console.error);
