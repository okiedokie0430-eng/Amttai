/**
 * Fix recipe images in Appwrite by validating URLs from recipes.csv
 * Usage: node fix-images.js [recipes.csv] [start_row]
 *   e.g. node fix-images.js recipes.csv 1
 *        node fix-images.js recipes.csv 1500   // resume from row 1500
 */

import 'dotenv/config';
import fs from 'fs';
import csvParser from 'csv-parser';

const {
  APPWRITE_ENDPOINT,
  APPWRITE_PROJECT_ID,
  APPWRITE_API_KEY,
  APPWRITE_DATABASE_ID,
  APPWRITE_RECIPES_COLLECTION_ID,
} = process.env;

const CSV_PATH        = process.argv[2] || 'recipes.csv';
const START_ROW       = Math.max(1, parseInt(process.argv[3]) || 1);
const CHECKPOINT_FILE = 'fix-images-checkpoint.json';
const SAVE_EVERY      = 50;

const log = (...a) => console.log(`[${new Date().toLocaleTimeString()}]`, ...a);
const err = (...a) => console.error(`[${new Date().toLocaleTimeString()}]`, '✖', ...a);
const delay = ms => new Promise(r => setTimeout(r, ms));

/* ─── List parser (same as ingestion script) ───────────────────────────── */
function parsePyList(str) {
  if (!str || str === 'NA' || str === 'nan') return [];
  let s = str.trim();
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) s = s.slice(1, -1);
  s = s.trim();
  if (s.startsWith('c(') && s.endsWith(')')) s = s.slice(2, -1).trim();
  if (s.startsWith('[') && s.endsWith(']')) s = s.slice(1, -1).trim();
  const items = [];
  let cur = '', inQ = false, qCh = null;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (!inQ && (c === "'" || c === '"')) { inQ = true; qCh = c; continue; }
    if (inQ && c === qCh) { inQ = false; qCh = null; continue; }
    if (!inQ && c === ',') { if (cur.trim()) items.push(cur.trim()); cur = ''; continue; }
    if (!inQ && /\s/.test(c)) { /* skip whitespace outside quotes */ }
    else { cur += c; }
  }
  if (cur.trim()) items.push(cur.trim());
  return items;
}

/* ─── Check if an image URL is alive ───────────────────────────────────── */
async function isImageUrlValid(url) {
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 10000);
    const res = await fetch(url, {
      method: 'HEAD',
      signal: controller.signal,
      redirect: 'follow',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'image/webp,image/apng,image/*,*/*',
      }
    });
    clearTimeout(t);
    return res.ok;
  } catch {
    return false;
  }
}

/* ─── Appwrite: list documents sorted by created_at ────────────────────── */
async function listDocs(offset, limit) {
  const url = new URL(`${APPWRITE_ENDPOINT}/databases/${APPWRITE_DATABASE_ID}/collections/${APPWRITE_RECIPES_COLLECTION_ID}/documents`);
  url.searchParams.set('limit', String(limit));
  url.searchParams.set('offset', String(offset));
  url.searchParams.set('orderAttributes[]', 'created_at');
  url.searchParams.set('orderType', 'ASC');

  const res = await fetch(url.toString(), {
    headers: {
      'X-Appwrite-Project': APPWRITE_PROJECT_ID,
      'X-Appwrite-Key': APPWRITE_API_KEY,
    }
  });
  if (!res.ok) throw new Error(`List ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.documents || [];
}

/* ─── Appwrite: patch image_url on existing document ───────────────────── */
async function patchDoc(docId, imageUrl) {
  const url = `${APPWRITE_ENDPOINT}/databases/${APPWRITE_DATABASE_ID}/collections/${APPWRITE_RECIPES_COLLECTION_ID}/documents/${docId}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-Appwrite-Project': APPWRITE_PROJECT_ID,
      'X-Appwrite-Key': APPWRITE_API_KEY,
    },
    body: JSON.stringify({ data: { image_url: imageUrl } }),
  });
  if (!res.ok) throw new Error(`Patch ${res.status}: ${await res.text()}`);
}

/* ─── Async generators ─────────────────────────────────────────────────── */
async function* appwriteDocs(startOffset) {
  let offset = startOffset;
  const limit = 100;
  while (true) {
    const docs = await listDocs(offset, limit);
    if (!docs.length) break;
    for (const d of docs) yield d;
    offset += limit;
  }
}

async function* csvRows(startIndex) {
  let idx = 0;
  const stream = fs.createReadStream(CSV_PATH).pipe(csvParser());
  for await (const row of stream) {
    idx++;
    if (idx < startIndex) continue;
    yield { index: idx, ...row };
  }
}

/* ─── Main ──────────────────────────────────────────────────────────────── */
async function main() {
  let row = START_ROW;
  try {
    const cp = JSON.parse(fs.readFileSync(CHECKPOINT_FILE, 'utf8'));
    if (cp.lastRow) row = cp.lastRow + 1;
  } catch {}

  log(`Starting from CSV row ${row}`);

  const docGen = appwriteDocs(row - 1);
  const csvGen = csvRows(row);

  let processed = 0, fixed = 0, cleared = 0, alreadyOk = 0, failed = 0;

  process.on('SIGINT', () => {
    log('Interrupted. Saving checkpoint...');
    fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify({ lastRow: row + processed - 1, at: new Date().toISOString() }, null, 2));
    process.exit(0);
  });

  for await (const doc of docGen) {
    const csvNext = await csvGen.next();
    if (csvNext.done) { log('CSV exhausted — all caught up'); break; }
    const csvRow = csvNext.value;

    const allUrls = parsePyList(csvRow.Images).filter(u => u.startsWith('http'));
    let workingUrl = null;
    for (const url of allUrls) {
      if (await isImageUrlValid(url)) { workingUrl = url; break; }
    }

    const currentUrl = doc.image_url;

    if (workingUrl && workingUrl !== currentUrl) {
      try {
        await patchDoc(doc.$id, workingUrl);
        fixed++;
        log(`✅ Row ${csvRow.index}: Fixed image for "${doc.title?.slice(0, 40)}"`);
      } catch (e) {
        err(`Row ${csvRow.index}: Patch failed — ${e.message}`);
        failed++;
      }
    } else if (!workingUrl && currentUrl) {
      try {
        await patchDoc(doc.$id, null);
        cleared++;
        log(`⚠️ Row ${csvRow.index}: Cleared dead image for "${doc.title?.slice(0, 40)}"`);
      } catch (e) {
        err(`Row ${csvRow.index}: Clear failed — ${e.message}`);
        failed++;
      }
    } else if (workingUrl && workingUrl === currentUrl) {
      alreadyOk++;
    }

    processed++;
    if (processed % SAVE_EVERY === 0) {
      const lastRow = csvRow.index;
      fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify({ lastRow, at: new Date().toISOString() }, null, 2));
      log(`💾 Checkpoint: row ${lastRow} | Fixed ${fixed} | Cleared ${cleared} | OK ${alreadyOk} | Failed ${failed}`);
    }

    await delay(50); // be polite to image servers
  }

  log(`🏁 Done. Processed ${processed} | Fixed ${fixed} | Cleared ${cleared} | Already OK ${alreadyOk} | Failed ${failed}`);
}

main().catch(e => { err(e.message); process.exit(1); });
