import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { Query } from 'node-appwrite';
import {
  collectionIds,
  databaseId,
  databases,
  ensureAppwriteReady,
  formatAdminError,
  mapDocumentWithId
} from '$lib/server/appwrite';

export const load: PageServerLoad = async () => {
  try {
    ensureAppwriteReady();

    let result;

    try {
      result = await databases.listDocuments(databaseId, collectionIds.supportMessages, [
        Query.orderDesc('created_at'),
        Query.limit(200)
      ]);
    } catch {
      result = await databases.listDocuments(databaseId, collectionIds.supportMessages, [
        Query.orderDesc('$createdAt'),
        Query.limit(200)
      ]);
    }

    const messages = result.documents.map((doc) => mapDocumentWithId(doc));

    return { messages, loadError: null };
  } catch (error) {
    return { messages: [], loadError: formatAdminError(error) };
  }
};

export const actions: Actions = {
  reply: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const userId = String(formData.get('userId') ?? '').trim();
      const message = String(formData.get('message') ?? '').trim();

      if (!userId || !message) {
        return fail(400, { error: 'userId and message are required.' });
      }

      await databases.createDocument(databaseId, collectionIds.supportMessages, 'unique()', {
        user_id: userId,
        message,
        is_from_admin: true,
        created_at: new Date().toISOString()
      });

      return { message: 'Reply sent.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  deleteMessage: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const messageId = String(formData.get('messageId') ?? '');

      if (!messageId) {
        return fail(400, { error: 'Missing messageId.' });
      }

      await databases.deleteDocument(databaseId, collectionIds.supportMessages, messageId);
      return { message: 'Message deleted.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  }
};
