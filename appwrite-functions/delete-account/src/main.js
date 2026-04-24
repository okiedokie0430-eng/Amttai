import { Client, Databases, Storage, Users, Query } from 'node-appwrite';

const MAX_DOCUMENT_DELETION_PASSES = 50;
const FILE_SCAN_PAGE_SIZE = 100;

/**
 * Appwrite Function: delete-account
 *
 * Permanently deletes a user account and all associated data.
 * Called from the Flutter app via createExecution().
 *
 * Expected body (JSON): { "userId": "<user-id>" }
 *
 * This function uses a Server API key so it can:
 *   - Delete documents from all collections
 *   - Delete files from storage buckets
 *   - Permanently delete the auth user (not just disable)
 */
export default async ({ req, res, log, error }) => {
  // ── Parse input ──
  let userId;
  try {
    const body = JSON.parse(req.body || '{}');
    userId = body.userId;
  } catch (e) {
    error('Failed to parse request body: ' + e.message);
    return res.json({ ok: false, message: 'Invalid request body' }, 400);
  }

  const normalizedUserId = String(userId || '').trim();
  if (!normalizedUserId) {
    return res.json({ ok: false, message: 'userId is required' }, 400);
  }

  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(normalizedUserId)) {
    return res.json({ ok: false, message: 'Invalid userId format' }, 400);
  }

  // ── Verify the caller is the same user (security) ──
  // req.headers contains x-appwrite-user-id when called by an authenticated user
  const callerIdHeader = req.headers['x-appwrite-user-id'];
  const callerId = Array.isArray(callerIdHeader) ? callerIdHeader[0] : callerIdHeader;
  const normalizedCallerId = String(callerId || '').trim();
  if (!normalizedCallerId) {
    return res.json({ ok: false, message: 'Authenticated user is required' }, 401);
  }

  if (normalizedCallerId !== normalizedUserId) {
    error(`Security: caller ${normalizedCallerId} tried to delete user ${normalizedUserId}`);
    return res.json({ ok: false, message: 'Unauthorized' }, 403);
  }

  log(`Starting account deletion for user: ${normalizedUserId}`);

  // ── Init server SDK ──
  const endpoint = String(process.env.APPWRITE_ENDPOINT || '').trim();
  const projectId = String(process.env.APPWRITE_PROJECT_ID || '').trim();
  const apiKey = String(process.env.APPWRITE_API_KEY || '').trim();

  if (!endpoint || !projectId || !apiKey) {
    return res.json(
      {
        ok: false,
        message: 'Missing required server configuration.'
      },
      500
    );
  }

  const client = new Client()
    .setEndpoint(endpoint)
    .setProject(projectId)
    .setKey(apiKey);

  const databases = new Databases(client);
  const storage = new Storage(client);
  const users = new Users(client);

  const databaseId = process.env.DATABASE_ID || 'amttai_db';

  // ── Collection config ──
  const collections = [
    { id: 'users',           queryField: '$id' },
    { id: 'ratings',         queryField: 'user_id' },
    { id: 'payments',        queryField: 'user_id' },
    { id: 'support_messages', queryField: 'user_id' },
  ];

  // ── 1. Delete documents from all collections ──
  for (const col of collections) {
    try {
      let docsDeleted = 0;
      let pass = 0;
      while (pass < MAX_DOCUMENT_DELETION_PASSES) {
        pass += 1;
        const query = col.queryField === '$id'
          ? [Query.equal('$id', normalizedUserId), Query.limit(FILE_SCAN_PAGE_SIZE)]
          : [Query.equal(col.queryField, normalizedUserId), Query.limit(FILE_SCAN_PAGE_SIZE)];
        const docs = await databases.listDocuments(databaseId, col.id, query);
        if (!Array.isArray(docs.documents) || docs.documents.length === 0) {
          break;
        }

        let deletedInPass = 0;
        for (const doc of docs.documents) {
          try {
            await databases.deleteDocument(databaseId, col.id, doc.$id);
            docsDeleted += 1;
            deletedInPass += 1;
          } catch (e) {
            error(`Failed to delete doc ${doc.$id} from ${col.id}: ${e.message}`);
          }
        }

        if (deletedInPass === 0) {
          break;
        }
      }

      log(`Deleted ${docsDeleted} docs in '${col.id}'`);
    } catch (e) {
      error(`Error querying collection '${col.id}': ${e.message}`);
    }
  }

  // ── 2. Delete profile photos from storage ──
  const storageBuckets = ['profile_photos', 'payment_screenshots'];
  for (const bucketId of storageBuckets) {
    try {
      const matchingFileIds = [];
      let offset = 0;
      while (true) {
        const files = await storage.listFiles(
          bucketId,
          [Query.limit(FILE_SCAN_PAGE_SIZE), Query.offset(offset)]
        );
        const listedFiles = Array.isArray(files.files) ? files.files : [];
        if (listedFiles.length === 0) {
          break;
        }

        for (const file of listedFiles) {
          if (file.$id.includes(normalizedUserId) || file.name.includes(normalizedUserId)) {
            matchingFileIds.push(file.$id);
          }
        }

        offset += listedFiles.length;
        if (listedFiles.length < FILE_SCAN_PAGE_SIZE) {
          break;
        }
      }

      let filesDeleted = 0;
      for (const fileId of matchingFileIds) {
        try {
          await storage.deleteFile(bucketId, fileId);
          filesDeleted += 1;
          log(`Deleted file ${fileId} from ${bucketId}`);
        } catch (e) {
          const errorCode = e && typeof e === 'object' ? e.code : null;
          if (errorCode !== 404) {
            error(`Failed to delete file ${fileId} from ${bucketId}: ${e.message}`);
          }
        }
      }

      log(`Deleted ${filesDeleted} files from bucket '${bucketId}'`);
    } catch (e) {
      error(`Error listing files in bucket '${bucketId}': ${e.message}`);
    }
  }

  // ── 3. Permanently delete the auth user ──
  try {
    await users.delete(normalizedUserId);
    log(`Auth user ${normalizedUserId} permanently deleted`);
  } catch (e) {
    error(`Failed to delete auth user: ${e.message}`);
    return res.json({
      ok: false,
      message: 'Data deleted but failed to delete auth account: ' + e.message,
    }, 500);
  }

  log(`Account deletion complete for user: ${normalizedUserId}`);
  return res.json({ ok: true, message: 'Account permanently deleted' });
};
