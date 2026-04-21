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
  getDocumentField,
  mapDocumentWithId,
  planToMonths
} from '$lib/server/appwrite';

export const load: PageServerLoad = async () => {
  try {
    ensureAppwriteReady();

    let result;

    try {
      result = await databases.listDocuments(databaseId, collectionIds.payments, [
        Query.orderDesc('created_at'),
        Query.limit(200)
      ]);
    } catch {
      result = await databases.listDocuments(databaseId, collectionIds.payments, [
        Query.orderDesc('$createdAt'),
        Query.limit(200)
      ]);
    }

    const payments = result.documents.map((doc) => mapDocumentWithId(doc));

    return { payments, loadError: null };
  } catch (error) {
    return { payments: [], loadError: formatAdminError(error) };
  }
};

async function activatePremiumForPayment(paymentId: string) {
  const paymentDoc = await databases.getDocument(databaseId, collectionIds.payments, paymentId);
  const userId = String(getDocumentField(paymentDoc, 'user_id') ?? '');
  const plan = String(getDocumentField(paymentDoc, 'plan') ?? 'oneMonth');
  const transactionId = String(getDocumentField(paymentDoc, 'transaction_id') ?? 'MANUAL_APPROVED');

  if (!userId) {
    throw new Error('Payment has no user_id.');
  }

  const months = planToMonths(plan);
  const now = new Date();

  await databases.updateDocument(databaseId, collectionIds.payments, paymentId, {
    status: 'approved',
    verified_at: now.toISOString(),
    transaction_id: transactionId
  });

  const userDoc = await databases.getDocument(databaseId, collectionIds.users, userId);
  const rawExpiry = String(getDocumentField(userDoc, 'premium_expires_at') ?? '');
  const parsedExpiry = rawExpiry ? new Date(rawExpiry) : null;
  const hasFutureExpiry = parsedExpiry && !Number.isNaN(parsedExpiry.getTime()) && parsedExpiry > now;
  const baseDate = hasFutureExpiry ? parsedExpiry : now;
  const premiumExpiresAt = addMonths(baseDate, months).toISOString();

  await databases.updateDocument(databaseId, collectionIds.users, userId, {
    is_premium: true,
    premium_expires_at: premiumExpiresAt
  });
}

export const actions: Actions = {
  approve: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const paymentId = String(formData.get('paymentId') ?? '');

      if (!paymentId) {
        return fail(400, { error: 'Missing paymentId.' });
      }

      await activatePremiumForPayment(paymentId);
      return { message: 'Payment approved and premium activated.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  reject: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const paymentId = String(formData.get('paymentId') ?? '');

      if (!paymentId) {
        return fail(400, { error: 'Missing paymentId.' });
      }

      await databases.updateDocument(databaseId, collectionIds.payments, paymentId, {
        status: 'rejected',
        verified_at: new Date().toISOString()
      });

      return { message: 'Payment rejected.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  }
};
