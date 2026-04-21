import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { Query } from 'node-appwrite';
import {
  addMonths,
  collectionIds,
  databaseId,
  databases,
  ensureAppwriteReady,
  formatAdminError,
  generateSerializedUserCode,
  getDocumentField,
  mapDocumentWithId
} from '$lib/server/appwrite';

export const load: PageServerLoad = async () => {
  try {
    ensureAppwriteReady();

    let result;

    try {
      result = await databases.listDocuments(databaseId, collectionIds.users, [
        Query.orderDesc('created_at'),
        Query.limit(200)
      ]);
    } catch {
      result = await databases.listDocuments(databaseId, collectionIds.users, [
        Query.orderDesc('$createdAt'),
        Query.limit(200)
      ]);
    }

    const users = result.documents.map((doc) => mapDocumentWithId(doc));

    return { users, loadError: null };
  } catch (error) {
    return { users: [], loadError: formatAdminError(error) };
  }
};

function isUserCodeSchemaMissingError(error: unknown) {
  const message = formatAdminError(error).toLowerCase();
  return (
    (message.includes('attribute not found') || message.includes('unknown attribute')) &&
    message.includes('user_code')
  );
}

async function assignUniqueUserCode(userId: string) {
  for (let i = 0; i < 20; i += 1) {
    const candidate = generateSerializedUserCode();
    let existing;
    try {
      existing = await databases.listDocuments(databaseId, collectionIds.users, [
        Query.equal('user_code', candidate),
        Query.limit(1)
      ]);
    } catch (error) {
      if (isUserCodeSchemaMissingError(error)) {
        throw new Error('users.user_code schema is missing. Run scripts/appwrite/provision_backend.ps1 first.');
      }
      throw error;
    }

    if (existing.documents.length === 0 || existing.documents[0].$id === userId) {
      try {
        await databases.updateDocument(databaseId, collectionIds.users, userId, {
          user_code: candidate
        });
      } catch (error) {
        if (isUserCodeSchemaMissingError(error)) {
          throw new Error('users.user_code schema is missing. Run scripts/appwrite/provision_backend.ps1 first.');
        }
        throw error;
      }
      return candidate;
    }
  }

  throw new Error('Unable to generate unique user code after multiple attempts.');
}

async function backfillMissingUserCodes() {
  const limit = 100;
  let cursor: string | null = null;
  let scanned = 0;
  let updated = 0;

  while (true) {
    const queries = [Query.limit(limit)];
    if (cursor) {
      queries.push(Query.cursorAfter(cursor));
    }

    const batch = await databases.listDocuments(databaseId, collectionIds.users, queries);
    if (batch.documents.length === 0) {
      break;
    }

    for (const doc of batch.documents) {
      const user = mapDocumentWithId(doc);
      scanned += 1;

      const existingCode = String(user.user_code ?? '').trim();
      if (existingCode) {
        continue;
      }

      await assignUniqueUserCode(user.id);
      updated += 1;
    }

    cursor = batch.documents[batch.documents.length - 1].$id;
    if (batch.documents.length < limit) {
      break;
    }
  }

  return { scanned, updated };
}

export const actions: Actions = {
  setPremium: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const userId = String(formData.get('userId') ?? '');
      const months = Number(formData.get('months') ?? 1);

      if (!userId) {
        return fail(400, { error: 'Missing userId.' });
      }

      const userDoc = await databases.getDocument(databaseId, collectionIds.users, userId);
      const now = new Date();
      const rawExpiry = String(getDocumentField(userDoc, 'premium_expires_at') ?? '');
      const parsedExpiry = rawExpiry ? new Date(rawExpiry) : null;
      const hasFutureExpiry = parsedExpiry && !Number.isNaN(parsedExpiry.getTime()) && parsedExpiry > now;
      const baseDate = hasFutureExpiry ? parsedExpiry : now;

      const expiresAt = addMonths(baseDate, Number.isFinite(months) && months > 0 ? months : 1).toISOString();

      await databases.updateDocument(databaseId, collectionIds.users, userId, {
        is_premium: true,
        premium_expires_at: expiresAt
      });

      return { message: `Premium enabled until ${expiresAt}.` };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  revokePremium: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const userId = String(formData.get('userId') ?? '');

      if (!userId) {
        return fail(400, { error: 'Missing userId.' });
      }

      await databases.updateDocument(databaseId, collectionIds.users, userId, {
        is_premium: false,
        premium_expires_at: null
      });

      return { message: 'Premium revoked.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  regenerateCode: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const userId = String(formData.get('userId') ?? '');

      if (!userId) {
        return fail(400, { error: 'Missing userId.' });
      }

      const code = await assignUniqueUserCode(userId);
      return { message: `User code regenerated: ${code}` };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  backfillCodes: async () => {
    try {
      ensureAppwriteReady();

      const result = await backfillMissingUserCodes();
      return {
        message: `Processed ${result.scanned} users. Generated ${result.updated} missing user IDs.`
      };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  }
};
