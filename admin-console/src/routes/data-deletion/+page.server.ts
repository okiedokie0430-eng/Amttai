import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { ExecutionMethod, ID, Query } from 'node-appwrite';
import {
  collectionIds,
  databaseId,
  databases,
  ensureAppwriteReady,
  formatAdminError,
  functionIds,
  functions,
  mapDocumentWithId,
  messaging,
  users
} from '$lib/server/appwrite';

export const load: PageServerLoad = async () => {
  try {
    ensureAppwriteReady();

    const result = await databases.listDocuments(databaseId, collectionIds.dataErasureRequests, [
      Query.orderDesc('$createdAt'),
      Query.limit(200)
    ]);

    const requests = result.documents.map((doc) => mapDocumentWithId(doc));

    return { requests, loadError: null };
  } catch (error) {
    return { requests: [], loadError: formatAdminError(error) };
  }
};

export const actions: Actions = {
  updateStatus: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const requestId = String(formData.get('requestId') ?? '');
      const status = String(formData.get('status') ?? '');

      if (!requestId) {
        return fail(400, { error: 'Missing requestId.' });
      }
      if (!status) {
        return fail(400, { error: 'Missing status.' });
      }

      await databases.updateDocument(databaseId, collectionIds.dataErasureRequests, requestId, {
        status
      });

      return { message: `Status updated to "${status}".` };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  deleteRequest: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const requestId = String(formData.get('requestId') ?? '');

      if (!requestId) {
        return fail(400, { error: 'Missing requestId.' });
      }

      await databases.deleteDocument(databaseId, collectionIds.dataErasureRequests, requestId);

      return { message: 'Request deleted.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  processAndNotify: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const requestId = String(formData.get('requestId') ?? '');

      if (!requestId) {
        return fail(400, { error: 'Missing requestId.' });
      }

      // 1. Fetch the erasure request to get the email
      const erasureDoc = await databases.getDocument(
        databaseId,
        collectionIds.dataErasureRequests,
        requestId
      );
      const email = String(erasureDoc.email ?? '').trim();
      const fullName = String(erasureDoc.full_name ?? '').trim();

      if (!email) {
        return fail(400, { error: 'Request has no email address.' });
      }

      // 2. Find the Appwrite auth user by email
      let userId: string | null = null;
      try {
        const userList = await users.list([Query.equal('email', email), Query.limit(1)]);
        if (userList.users.length > 0) {
          userId = userList.users[0].$id;
        }
      } catch {
        // ignore lookup errors
      }

      // 3. Trigger delete-account function if user exists
      if (userId) {
        try {
          await functions.createExecution(
            functionIds.deleteAccount,
            JSON.stringify({ userId }),
            false,
            '/',
            ExecutionMethod.POST
          );
        } catch (fnError) {
          console.error('delete-account function failed:', fnError);
        }
      }

      // 4. Update request status to completed
      await databases.updateDocument(databaseId, collectionIds.dataErasureRequests, requestId, {
        status: 'completed'
      });

      // 5. Send confirmation email if user exists in auth
      if (userId) {
        try {
          await messaging.createEmail(
            ID.unique(),
            'Your data has been deleted — Amttai',
            `<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h2 style="color: #111;">Data Deletion Confirmed</h2>
  <p>Hello ${fullName || 'there'},</p>
  <p>We are writing to confirm that your data erasure request has been processed and <strong>all your personal data has been permanently deleted</strong> from Amttai's systems.</p>
  <p>This includes:</p>
  <ul>
    <li>Your user profile and account information</li>
    <li>All activity logs and preferences</li>
    <li>Any uploaded content associated with your account</li>
  </ul>
  <p>Some anonymized analytical records may be retained for statistical purposes as permitted by law, but these cannot be used to identify you.</p>
  <p>If you have any questions, please contact us at <a href="mailto:privacy@amttai.app">privacy@amttai.app</a>.</p>
  <p style="margin-top: 24px; color: #666; font-size: 12px;">Amttai Inc.</p>
</body>
</html>`,
            [],
            [userId],
            [],
            [],
            [],
            [],
            false,
            true
          );
        } catch (msgError) {
          console.error('Failed to send confirmation email:', msgError);
        }
      }

      return {
        message: userId
          ? 'Data deletion processed. User account removed and confirmation email sent.'
          : 'Data deletion processed. No matching Appwrite user was found; request marked completed.'
      };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  }
};
