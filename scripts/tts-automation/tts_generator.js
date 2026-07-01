import { Client, Databases, Storage, Query, ID, InputFile } from 'node-appwrite';
import { MsEdgeTTS, OUTPUT_FORMAT } from 'msedge-tts';
import axios from 'axios';
import dotenv from 'dotenv';
import fs from 'fs/promises';
import path from 'path';

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

async function main() {
    try {
        const tts = new MsEdgeTTS();
        await tts.setMetadata('mn-MN-YesuiNeural', OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);

        console.log('Fetching recipes...');
        
        let hasMore = true;
        let lastId = null;
        const limit = 100;
        
        while (hasMore) {
            const queries = [Query.limit(limit)];
            if (lastId) {
                queries.push(Query.cursorAfter(lastId));
            }

            const response = await databases.listDocuments(
                APPWRITE_DATABASE_ID,
                APPWRITE_RECIPES_COLLECTION_ID,
                queries
            );

            const recipes = response.documents;
            if (recipes.length === 0) {
                hasMore = false;
                break;
            }
            
            lastId = recipes[recipes.length - 1].$id;

            const recipesToProcess = recipes.filter(doc => 
                !doc.audio_step_urls || doc.audio_step_urls.length === 0
            );

            for (const recipe of recipesToProcess) {
                console.log(`Processing recipe: ${recipe.$id}`);
                const stepFileIds = [];
                
                if (!recipe.steps || !Array.isArray(recipe.steps) || recipe.steps.length === 0) {
                    console.log(`No steps found for recipe ${recipe.$id}, skipping...`);
                    continue;
                }

                let stepFailed = false;

                for (let stepIndex = 0; stepIndex < recipe.steps.length; stepIndex++) {
                    const stepText = recipe.steps[stepIndex];
                    if (!stepText || typeof stepText !== 'string' || stepText.trim() === '') {
                        console.log(`  Skipping empty step ${stepIndex}`);
                        continue;
                    }

                    const fileName = `${recipe.$id}_step_${stepIndex}.mp3`;

                    try {
                        console.log(`  Generating audio for step ${stepIndex}...`);
                        
                        const audioBuffer = await new Promise((resolve, reject) => {
                            const { audioStream } = tts.toStream(stepText);
                            const chunks = [];
                            audioStream.on('data', chunk => chunks.push(chunk));
                            audioStream.on('end', () => resolve(Buffer.concat(chunks)));
                            audioStream.on('error', reject);
                        });

                        console.log(`  Uploading ${fileName} to Appwrite Storage...`);
                        const uploadedFile = await storage.createFile(
                            APPWRITE_BUCKET_ID,
                            ID.unique(),
                            InputFile.fromBuffer(audioBuffer, fileName)
                        );

                        stepFileIds.push(uploadedFile.$id);

                    } catch (error) {
                        console.error(`  Failed to process step ${stepIndex} for recipe ${recipe.$id}:`, error.message);
                        stepFailed = true;
                        break; // Stop processing steps for this recipe
                    }
                }

                if (stepFailed) {
                    console.error(`Aborting update for recipe ${recipe.$id} due to step generation failure.`);
                    continue;
                }

                // 4. Appwrite 1.6.0 Bug Bypass Injection (Document Update)
                if (stepFileIds.length > 0) {
                    try {
                        console.log(`  Updating document ${recipe.$id} via REST API Bypass...`);
                        
                        const patchUrl = `${APPWRITE_ENDPOINT}/databases/${APPWRITE_DATABASE_ID}/collections/${APPWRITE_RECIPES_COLLECTION_ID}/documents/${recipe.$id}`;
                        
                        await axios.patch(patchUrl, {
                            data: {
                                audio_step_urls: stepFileIds
                            }
                        }, {
                            headers: {
                                'X-Appwrite-Project': APPWRITE_PROJECT_ID,
                                'X-Appwrite-Key': APPWRITE_API_KEY,
                                'Content-Type': 'application/json'
                            }
                        });

                        console.log(`  Successfully updated recipe ${recipe.$id}.`);
                    } catch (error) {
                        console.error(`  Failed to update recipe ${recipe.$id} via REST API:`, error?.response?.data || error.message);
                    }
                } else {
                    console.log(`  No audio generated for recipe ${recipe.$id}, skipping update.`);
                }
            }

            if (recipes.length < limit) {
                hasMore = false;
            }
        }
        
        console.log('All done processing.');
    } catch (error) {
        console.error('Fatal error in TTS generation:', error);
    }
}

main();
