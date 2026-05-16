import { Client, Databases, Storage, Users, Query } from 'node-appwrite';

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

  if (!userId) {
    return res.json({ ok: false, message: 'userId is required' }, 400);
  }

  // ── Verify the caller is the same user (security) ──
  // req.headers contains x-appwrite-user-id when called by an authenticated user
  const callerId = req.headers['x-appwrite-user-id'];
  if (callerId && callerId !== userId) {
    error(`Security: caller ${callerId} tried to delete user ${userId}`);
    return res.json({ ok: false, message: 'Unauthorized' }, 403);
  }

  log(`Starting account deletion for user: ${userId}`);

  // ── Init server SDK ──
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

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
      const query = col.queryField === '$id'
        ? [Query.equal('$id', userId), Query.limit(500)]
        : [Query.equal(col.queryField, userId), Query.limit(500)];

      const docs = await databases.listDocuments(databaseId, col.id, query);
      log(`Found ${docs.documents.length} docs in '${col.id}'`);

      for (const doc of docs.documents) {
        try {
          await databases.deleteDocument(databaseId, col.id, doc.$id);
        } catch (e) {
          error(`Failed to delete doc ${doc.$id} from ${col.id}: ${e.message}`);
        }
      }
    } catch (e) {
      error(`Error querying collection '${col.id}': ${e.message}`);
    }
  }

  // ── 2. Delete profile photos from storage ──
  const storageBuckets = ['profile_photos', 'payment_screenshots'];
  for (const bucketId of storageBuckets) {
    try {
      const files = await storage.listFiles(bucketId, [Query.limit(200)]);
      for (const file of files.files) {
        if (file.$id.includes(userId) || file.name.includes(userId)) {
          try {
            await storage.deleteFile(bucketId, file.$id);
            log(`Deleted file ${file.$id} from ${bucketId}`);
          } catch (e) {
            error(`Failed to delete file ${file.$id} from ${bucketId}: ${e.message}`);
          }
        }
      }
    } catch (e) {
      error(`Error listing files in bucket '${bucketId}': ${e.message}`);
    }
  }

  // ── 3. Permanently delete the auth user ──
  try {
    await users.delete(userId);
    log(`Auth user ${userId} permanently deleted`);
  } catch (e) {
    error(`Failed to delete auth user: ${e.message}`);
    return res.json({
      ok: false,
      message: 'Data deleted but failed to delete auth account: ' + e.message,
    }, 500);
  }

  log(`Account deletion complete for user: ${userId}`);
  return res.json({ ok: true, message: 'Account permanently deleted' });
};
