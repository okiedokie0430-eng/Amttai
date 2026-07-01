import type { PageServerLoad } from './$types';
import {
  collectionIds,
  ensureAppwriteReady,
  formatAdminError,
  functions,
  getCollectionTotal,
  storage
} from '$lib/server/appwrite';

export const load: PageServerLoad = async () => {
  try {
    ensureAppwriteReady();

    const [users, recipes, ratings, payments, supportMessages, dataErasureRequests, buckets, functionList] =
      await Promise.all([
        getCollectionTotal(collectionIds.users),
        getCollectionTotal(collectionIds.recipes),
        getCollectionTotal(collectionIds.ratings),
        getCollectionTotal(collectionIds.payments),
        getCollectionTotal(collectionIds.supportMessages),
        getCollectionTotal(collectionIds.dataErasureRequests),
        storage.listBuckets(),
        functions.list()
      ]);

    return {
      loadError: null,
      stats: [
        { label: 'Users', value: users },
        { label: 'Recipes', value: recipes },
        { label: 'Ratings', value: ratings },
        { label: 'Payments', value: payments },
        { label: 'Support Messages', value: supportMessages },
        { label: 'Data Erasure Requests', value: dataErasureRequests },
        { label: 'Buckets', value: buckets.total },
        { label: 'Functions', value: functionList.total }
      ]
    };
  } catch (error) {
    return {
      loadError: formatAdminError(error),
      stats: [
        { label: 'Users', value: 0 },
        { label: 'Recipes', value: 0 },
        { label: 'Ratings', value: 0 },
        { label: 'Payments', value: 0 },
        { label: 'Support Messages', value: 0 },
        { label: 'Buckets', value: 0 },
        { label: 'Functions', value: 0 }
      ]
    };
  }
};
