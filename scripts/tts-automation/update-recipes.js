import { Client, Databases } from 'node-appwrite';
import axios from 'axios';
import dotenv from 'dotenv';
dotenv.config();

const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);

const translations = {
    "Buuz": [
        {"order":1,"description":"Гурилаа бэлтгэнэ."},
        {"order":2,"description":"Махаа амталж холино."},
        {"order":3,"description":"20 минут жигнэнэ."}
    ],
    "Khuushuur": [
        {"order":1,"description":"Гурил болон махаа бэлтгэнэ."},
        {"order":2,"description":"Чимхэж хавчуулна."},
        {"order":3,"description":"Алтан шар өнгөтэй болтол тосонд шарна."}
    ],
    "Tsuivan": [
        {"order":1,"description":"Гар аргаар гурилаа хайчилж бэлтгэнэ."},
        {"order":2,"description":"Мах болон хүнсний ногоогоо хуурна."},
        {"order":3,"description":"Гурилаа нэмж хуураад жигнэнэ."}
    ],
    "Guriltai Shul": [
        {"order":1,"description":"Махаа чанаж шөл гаргана."},
        {"order":2,"description":"Гурилаа нимгэн элдээд хэрчинэ."},
        {"order":3,"description":"Шөлөндөө гурилаа хийж чанана."}
    ],
    "Bantan": [
        {"order":1,"description":"Махаа усанд буцалгана."},
        {"order":2,"description":"Гурилаа үрж жижигхэн хэсгүүд болгоод нэмнэ."},
        {"order":3,"description":"Өтгөртөл нь зөөлөн гал дээр чанана."}
    ],
    "Boodog": [
        {"order":1,"description":"Мах болон халуун чулууг бэлтгэнэ."},
        {"order":2,"description":"Чулуу болон махаа арьсанд хийж битүүлнэ."},
        {"order":3,"description":"Ойролцоогоор 2 цаг орчим зөөлөн жигнэнэ."}
    ],
    "Khorhog": [
        {"order":1,"description":"Чулуугаа гал дээр халаана."},
        {"order":2,"description":"Мах болон хүнсний ногоогоо давхарлан хийнэ."},
        {"order":3,"description":"Битүү саванд хийж жигнэж болгоно."}
    ]
};

async function updateRecipe(id, newStepsStr) {
    const url = `${process.env.APPWRITE_ENDPOINT}/databases/${process.env.APPWRITE_DATABASE_ID}/collections/${process.env.APPWRITE_RECIPES_COLLECTION_ID}/documents/${id}`;
    const headers = {
        'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
        'X-Appwrite-Key': process.env.APPWRITE_API_KEY,
        'Content-Type': 'application/json'
    };
    const payload = { data: { steps: newStepsStr, audio_step_urls: [] } };
    await axios.patch(url, payload, { headers });
}

async function run() {
    console.log("Fetching recipes to update...");
    const res = await databases.listDocuments(process.env.APPWRITE_DATABASE_ID, process.env.APPWRITE_RECIPES_COLLECTION_ID);
    
    for (const d of res.documents) {
        if (translations[d.title]) {
            console.log(`Updating ${d.title}...`);
            const newSteps = JSON.stringify(translations[d.title]);
            await updateRecipe(d.$id, newSteps);
            console.log(`✅ ${d.title} updated with Mongolian steps.`);
        }
    }
    console.log("All recipes updated successfully!");
}

run().catch(console.error);
