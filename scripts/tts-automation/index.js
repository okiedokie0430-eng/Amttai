import { Client, Databases, Storage, Query, ID, InputFile } from 'node-appwrite';
import axios from 'axios';
import dotenv from 'dotenv';
import { MsEdgeTTS, OUTPUT_FORMAT } from 'msedge-tts';
import fs from 'fs/promises';
import path from 'path';
import express from 'express';
import cors from 'cors';
import { EventEmitter } from 'events';

// Load environment variables from .env file
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

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function updateRecipeDocumentREST(documentId, audioUrls) {
    const url = `${APPWRITE_ENDPOINT}/databases/${APPWRITE_DATABASE_ID}/collections/${APPWRITE_RECIPES_COLLECTION_ID}/documents/${documentId}`;
    const headers = {
        'Content-Type': 'application/json',
        'X-Appwrite-Project': APPWRITE_PROJECT_ID,
        'X-Appwrite-Key': APPWRITE_API_KEY
    };
    const payload = { data: { audio_step_urls: audioUrls } };
    const response = await axios.patch(url, payload, { headers });
    return response.data;
}

// Global state for SSE and Job Management
const app = express();
app.use(cors());
app.use(express.json());

const jobEvents = new EventEmitter();

let isRunning = false;
let currentProgress = { processed: 0, total: 0, status: 'idle', currentRecipe: '' };
let logs = []; 
let shouldCancel = false;

function broadcastLog(message, type = 'info') {
    const logEntry = { id: Date.now() + Math.random(), timestamp: new Date().toISOString(), message, type };
    logs.push(logEntry);
    if (logs.length > 500) logs.shift();
    jobEvents.emit('log', logEntry);
    
    if (type === 'error') console.error(`[${logEntry.timestamp}] ${message}`);
    else console.log(`[${logEntry.timestamp}] ${message}`);
}

function updateProgress(updates) {
    currentProgress = { ...currentProgress, ...updates };
    jobEvents.emit('progress', currentProgress);
}

async function mapConcurrent(items, limit, asyncFn) {
    const results = new Array(items.length);
    let index = 0;
    const workers = new Array(limit).fill(0).map(async () => {
        while (index < items.length) {
            if (shouldCancel) break;
            const i = index++;
            results[i] = await asyncFn(items[i], i);
        }
    });
    await Promise.all(workers);
    return results;
}

async function processRecipes() {
    if (isRunning) return;
    isRunning = true;
    shouldCancel = false;
    logs = []; // Clear logs for new run
    updateProgress({ processed: 0, total: 0, status: 'running', currentRecipe: '' });
    
    const tts = new MsEdgeTTS();
    try {
        await tts.setMetadata("mn-MN-YesuiNeural", OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
        broadcastLog("Initialized msedge-tts client with mn-MN-YesuiNeural", "success");
    } catch (err) {
        broadcastLog(`Failed to initialize Edge TTS client: ${err.message}`, "error");
        isRunning = false;
        updateProgress({ status: 'error' });
        return;
    }

    try {
        broadcastLog("Starting Edge TTS Pre-Fetch Admin Automation...", "info");
        
        // Fetch all valid file IDs from storage to ensure bulletproof detection
        broadcastLog("Cross-referencing database with Storage Bucket...", "info");
        const validFileIds = new Set();
        let fHasMore = true;
        let fCursor = null;
        while (fHasMore) {
            const fQueries = [Query.limit(100)];
            if (fCursor) fQueries.push(Query.cursorAfter(fCursor));
            const fRes = await storage.listFiles(APPWRITE_BUCKET_ID, fQueries);
            fRes.files.forEach(f => validFileIds.add(f.$id));
            if (fRes.files.length < 100) fHasMore = false;
            else fCursor = fRes.files[fRes.files.length - 1].$id;
        }
        broadcastLog(`Indexed ${validFileIds.size} valid audio files from storage.`, "info");

        // First, count total missing recipes for the progress bar
        broadcastLog("Calculating total remaining recipes...", "info");
        let totalCount = 0;
        let cHasMore = true;
        let cCursor = null;
        while(cHasMore) {
            const queries = [Query.limit(100)];
            if (cCursor) queries.push(Query.cursorAfter(cCursor));
            const cRes = await databases.listDocuments(APPWRITE_DATABASE_ID, APPWRITE_RECIPES_COLLECTION_ID, queries);
            let d = cRes.documents.filter(r => {
                let sLen = 0;
                if (r.steps) {
                    if (typeof r.steps === 'string') {
                        try { sLen = JSON.parse(r.steps).length; } catch(e) { sLen = 1; }
                    } else if (Array.isArray(r.steps)) {
                        sLen = r.steps.length;
                    }
                }
                const aLen = r.audio_step_urls ? r.audio_step_urls.length : 0;
                
                if (sLen === 0) return false;
                if (aLen < sLen) return true;
                
                // Bulletproof check: Ensure all IDs actually exist in the storage bucket
                if (r.audio_step_urls) {
                    for (const id of r.audio_step_urls) {
                        if (!validFileIds.has(id)) return true;
                    }
                }
                return false;
            });
            totalCount += d.length;
            if (cRes.documents.length < 100) cHasMore = false;
            else cCursor = cRes.documents[cRes.documents.length - 1].$id;
        }
        
        updateProgress({ total: totalCount });
        broadcastLog(`Found ${totalCount} recipes needing TTS generation.`, "info");
        
        if (totalCount === 0) {
            broadcastLog("No pending recipes found. Automation complete!", "success");
            isRunning = false;
            updateProgress({ status: 'idle' });
            return;
        }
        
        let hasMore = true;
        let cursor = null;
        let processedCount = 0;
        
        while(hasMore) {
            if (shouldCancel) break;
            
            broadcastLog(`Fetching batch of recipes${cursor ? ` after cursor ${cursor}` : ''}...`, "info");
            const queries = [Query.limit(100)];
            if (cursor) queries.push(Query.cursorAfter(cursor));
            
            const response = await databases.listDocuments(APPWRITE_DATABASE_ID, APPWRITE_RECIPES_COLLECTION_ID, queries);
            let recipes = response.documents.filter(r => {
                let sLen = 0;
                if (r.steps) {
                    if (typeof r.steps === 'string') {
                        try { sLen = JSON.parse(r.steps).length; } catch(e) { sLen = 1; }
                    } else if (Array.isArray(r.steps)) {
                        sLen = r.steps.length;
                    }
                }
                const aLen = r.audio_step_urls ? r.audio_step_urls.length : 0;
                
                if (sLen === 0) return false;
                if (aLen < sLen) return true;
                
                if (r.audio_step_urls) {
                    for (const id of r.audio_step_urls) {
                        if (!validFileIds.has(id)) return true;
                    }
                }
                return false;
            });
            
            if (recipes.length === 0) {
                broadcastLog("No pending recipes found in this batch.", "info");
            }
            
            // Process recipes SEQUENTIALLY as requested by user to avoid rate-limiting
            for (const recipe of recipes) {
                if (shouldCancel) break;
                
                updateProgress({ currentRecipe: recipe.title || recipe.$id });
                broadcastLog(`Processing recipe [${recipe.$id}]: ${recipe.title || 'Untitled'}`, "info");
                
                try {
                    let steps = recipe.steps || [];
                    
                    if (typeof steps === 'string') {
                        try {
                            steps = JSON.parse(steps);
                        } catch (e) {
                            steps = [steps];
                        }
                    }
                    
                    if (!Array.isArray(steps) || steps.length === 0) {
                        broadcastLog(`Recipe ${recipe.$id} has no valid steps array. Skipping.`, "warn");
                        continue;
                    }

                    const audioUrls = [];
                    let stepFailed = false;

                    // Process steps SEQUENTIALLY
                    for (let i = 0; i < steps.length; i++) {
                        if (shouldCancel) break;
                        
                        let stepTextRaw = steps[i];
                        let stepText = stepTextRaw;
                        
                        if (typeof stepText === 'object' && stepText !== null) {
                            stepText = stepText.description || stepText.text || stepText.step || '';
                        } 
                        else if (typeof stepText === 'string') {
                            try {
                                const parsedObj = JSON.parse(stepText);
                                if (parsedObj && typeof parsedObj === 'object') {
                                    stepText = parsedObj.description || parsedObj.text || parsedObj.step || stepText;
                                }
                            } catch (e) {}
                        }

                        stepText = typeof stepText === 'string' ? stepText : String(stepText || '');

                        if (!stepText || stepText.trim().length === 0) {
                            broadcastLog(`  [${recipe.title}] Step ${i} is empty. Skipping.`, "warn");
                            continue;
                        }

                        broadcastLog(`  [${recipe.title}] Generating Edge TTS for step ${i}...`, "info");
                        
                        const fileName = `${recipe.$id}_step_${i}.mp3`;

                        try {
                            // Use toStream to avoid msedge-tts's weird toFile directory-creation behavior
                            const audioBuffer = await new Promise((resolve, reject) => {
                                const { audioStream } = tts.toStream(stepText);
                                const chunks = [];
                                audioStream.on('data', chunk => chunks.push(chunk));
                                audioStream.on('end', () => resolve(Buffer.concat(chunks)));
                                audioStream.on('error', reject);
                            });
                            
                            broadcastLog(`  [${recipe.title}] Uploading ${fileName} to Appwrite Storage...`, "info");
                            
                            const uploadedFile = await storage.createFile(
                                APPWRITE_BUCKET_ID,
                                ID.unique(),
                                InputFile.fromBuffer(audioBuffer, fileName)
                            );
                            
                            audioUrls.push(uploadedFile.$id);
                        } catch (stepError) {
                            broadcastLog(`  [${recipe.title}] Failed to process step ${i}: ${stepError.message}`, "error");
                            stepFailed = true;
                            break; // Stop processing further steps for this recipe
                        }
                    }
                    
                    if (shouldCancel) break;
                    
                    if (stepFailed) {
                        broadcastLog(`  [${recipe.title}] Aborting update for this recipe due to step generation failure.`, "error");
                        continue; // skip to next recipe
                    }
                    
                    if (audioUrls.length > 0) {
                        broadcastLog(`  [${recipe.title}] Updating recipe via direct REST PATCH bypass...`, "info");
                        await updateRecipeDocumentREST(recipe.$id, audioUrls);
                        broadcastLog(`  [${recipe.title}] Successfully processed and updated!`, "success");
                    } else {
                        broadcastLog(`  [${recipe.title}] No audio generated, skipping update.`, "info");
                    }
                    
                    processedCount++;
                    updateProgress({ processed: processedCount });
                    
                } catch (recipeError) {
                    broadcastLog(`  [${recipe.title}] Error processing recipe: ${recipeError.message}`, "error");
                }
            }
            
            if (response.documents.length < 100) hasMore = false;
            else cursor = response.documents[response.documents.length - 1].$id;
        }
        
        if (shouldCancel) {
            broadcastLog(`Automation cancelled by user. Processed ${processedCount} recipes.`, "warn");
            updateProgress({ status: 'idle' });
        } else {
            broadcastLog(`Automation finished successfully! Processed a total of ${processedCount} recipes.`, "success");
            updateProgress({ status: 'idle', currentRecipe: '' });
        }
        
    } catch (error) {
        broadcastLog(`Critical error during batch processing: ${error.message}`, "error");
        updateProgress({ status: 'error' });
    } finally {
        isRunning = false;
        shouldCancel = false;
    }
}

// API Routes
app.post('/api/start', (req, res) => {
    if (isRunning) return res.status(400).json({ error: 'Job is already running' });
    processRecipes(); // run asynchronously
    res.json({ message: 'Job started' });
});

app.post('/api/stop', (req, res) => {
    if (!isRunning) return res.status(400).json({ error: 'Job is not running' });
    shouldCancel = true;
    res.json({ message: 'Job cancellation requested' });
});

app.get('/api/status', (req, res) => {
    res.json(currentProgress);
});

app.get('/api/logs', (req, res) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    
    // Send initial logs
    res.write(`data: ${JSON.stringify({ type: 'init', data: logs })}\n\n`);
    res.write(`data: ${JSON.stringify({ type: 'progress', data: currentProgress })}\n\n`);
    
    const onLog = (logEntry) => res.write(`data: ${JSON.stringify({ type: 'log', data: logEntry })}\n\n`);
    const onProgress = (prog) => res.write(`data: ${JSON.stringify({ type: 'progress', data: prog })}\n\n`);
    
    jobEvents.on('log', onLog);
    jobEvents.on('progress', onProgress);
    
    req.on('close', () => {
        jobEvents.removeListener('log', onLog);
        jobEvents.removeListener('progress', onProgress);
    });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
    console.log(`Backend Server running on http://localhost:${PORT}`);
});
