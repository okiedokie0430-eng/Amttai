import { Client, Storage, ID, InputFile } from 'node-appwrite';

export default async ({ req, res, log, error }) => {
    // 1. Validate Payload
    if (!req.bodyString) {
        return res.json({ success: false, message: 'Missing payload' }, 400);
    }
    
    let document;
    try {
        document = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    } catch (e) {
        document = JSON.parse(req.bodyString);
    }

    const { $id: recipeId, steps } = document;
    
    if (!recipeId || !steps || !Array.isArray(steps) || steps.length === 0) {
        return res.json({ success: false, message: 'Invalid recipe data or missing steps array.' }, 400);
    }

    // 2. Initialize Appwrite Client
    const client = new Client()
        .setEndpoint(process.env.APPWRITE_FUNCTION_ENDPOINT)
        .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
        .setKey(process.env.APPWRITE_API_KEY);

    const storage = new Storage(client);
    const audioFileIds = [];

    const bucketId = process.env.APPWRITE_TTS_BUCKET_ID || 'recipe_audio_bucket';
    const dbId = process.env.APPWRITE_DATABASE_ID || 'main_db';
    const collectionId = process.env.APPWRITE_RECIPES_COLLECTION_ID || 'recipes';

    try {
        // 3. Loop through steps and generate MP3 via Cloud TTS API
        for (let i = 0; i < steps.length; i++) {
            const stepText = steps[i];
            log(`Generating TTS audio for step ${i + 1}: ${stepText}`);
            
            // MOCK TTS API CALL (E.g., Google Cloud TTS or Azure Cognitive Services)
            // Replace with actual fetch to TTS endpoint:
            /* 
            const ttsResponse = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': process.env.GCP_TTS_KEY },
                body: JSON.stringify({ 
                    input: { text: stepText }, 
                    voice: { languageCode: 'mn-MN', name: 'mn-MN-Standard-A' },
                    audioConfig: { audioEncoding: 'MP3' }
                })
            });
            const ttsData = await ttsResponse.json();
            const audioBuffer = Buffer.from(ttsData.audioContent, 'base64');
            */
            
            // Simulating MP3 Buffer response
            const audioBuffer = Buffer.from(`mock-mp3-audio-bytes-for-step-${i}`);
            const fileName = `recipe_${recipeId}_step_${i}.mp3`;
            
            // 4. Upload MP3 Buffer to Appwrite Storage
            const upload = await storage.createFile(
                bucketId,
                ID.unique(),
                InputFile.fromBuffer(audioBuffer, fileName)
            );
            
            audioFileIds.push(upload.$id);
            log(`Uploaded ${fileName} to storage as ${upload.$id}`);
        }

        // 5. Update Recipe Document with audio IDs (Bypassing Appwrite 1.6.0 SDK payload stripping bug)
        log(`Updating Recipe Document ${recipeId} with raw REST PATCH...`);
        
        const patchUrl = `${process.env.APPWRITE_FUNCTION_ENDPOINT}/databases/${dbId}/collections/${collectionId}/documents/${recipeId}`;
        const patchResponse = await fetch(patchUrl, {
            method: 'PATCH',
            headers: {
                'Content-Type': 'application/json',
                'X-Appwrite-Project': process.env.APPWRITE_FUNCTION_PROJECT_ID,
                'X-Appwrite-Key': process.env.APPWRITE_API_KEY
            },
            body: JSON.stringify({
                data: {
                    audio_step_urls: audioFileIds
                }
            })
        });

        if (!patchResponse.ok) {
            const errBody = await patchResponse.text();
            throw new Error(`REST PATCH failed: Status ${patchResponse.status} - ${errBody}`);
        }

        log(`Successfully generated and linked offline TTS audio for recipe ${recipeId}`);
        return res.json({ success: true, audio_step_urls: audioFileIds });

    } catch (err) {
        error(`Failed to generate TTS: ${err.message}`);
        return res.json({ success: false, message: err.message }, 500);
    }
};
