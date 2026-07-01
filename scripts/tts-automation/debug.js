import { Client, Databases } from 'node-appwrite';
import dotenv from 'dotenv';
dotenv.config();

const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);

databases.getDocument(process.env.APPWRITE_DATABASE_ID, process.env.APPWRITE_RECIPES_COLLECTION_ID, '69e3b563c6a7d30dd011')
    .then(doc => {
        console.log(JSON.stringify(doc, null, 2));
    })
    .catch(console.error);
