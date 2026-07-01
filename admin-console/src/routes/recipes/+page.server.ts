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

export const load: PageServerLoad = async ({ url }) => {
  try {
    ensureAppwriteReady();

    const page = Math.max(1, Number(url.searchParams.get('page') ?? 1));
    const pageSize = 100;
    const offset = (page - 1) * pageSize;

    let result;
    try {
      result = await databases.listDocuments(databaseId, collectionIds.recipes, [
        Query.orderDesc('created_at'),
        Query.limit(pageSize),
        Query.offset(offset)
      ]);
    } catch {
      result = await databases.listDocuments(databaseId, collectionIds.recipes, [
        Query.orderDesc('$createdAt'),
        Query.limit(pageSize),
        Query.offset(offset)
      ]);
    }

    // Get total count for pagination
    let total = 0;
    try {
      // Use offset=0 with limit=1 and check total from result
      const countResult = await databases.listDocuments(databaseId, collectionIds.recipes, [
        Query.limit(1),
        Query.offset(0)
      ]);
      total = countResult.total;
    } catch {
      total = result.total;
    }

    const totalPages = Math.ceil(total / pageSize);
    const recipes = result.documents.map((doc) => mapDocumentWithId(doc));
    return { recipes, loadError: null, page, pageSize, total, totalPages };
  } catch (error) {
    return { recipes: [], loadError: formatAdminError(error), page: 1, pageSize: 100, total: 0, totalPages: 0 };
  }
};

export const actions: Actions = {
  togglePremium: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const recipeId = String(formData.get('recipeId') ?? '');
      const current = String(formData.get('current') ?? 'false') === 'true';

      if (!recipeId) {
        return fail(400, { error: 'Missing recipeId.' });
      }

      await databases.updateDocument(databaseId, collectionIds.recipes, recipeId, {
        is_premium: !current
      });

      return { message: !current ? 'Recipe is now premium.' : 'Recipe moved to free.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  deleteRecipe: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const recipeId = String(formData.get('recipeId') ?? '');

      if (!recipeId) {
        return fail(400, { error: 'Missing recipeId.' });
      }

      await databases.deleteDocument(databaseId, collectionIds.recipes, recipeId);
      return { message: 'Recipe deleted.' };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  },

  deleteAllRecipes: async () => {
    try {
      ensureAppwriteReady();

      // First, get total count
      const firstBatch = await databases.listDocuments(databaseId, collectionIds.recipes, [
        Query.limit(1),
        Query.offset(0)
      ]);
      const total = firstBatch.total;
      if (total === 0) return { message: 'No recipes to delete.' };

      const limit = 100;
      let totalDeleted = 0;
      let offset = 0;

      while (offset < total) {
        const result = await databases.listDocuments(databaseId, collectionIds.recipes, [
          Query.limit(limit),
          Query.offset(offset)
        ]);

        if (result.documents.length === 0) break;

        // Delete in parallel for speed
        await Promise.all(
          result.documents.map((doc) =>
            databases.deleteDocument(databaseId, collectionIds.recipes, doc.$id)
          )
        );

        totalDeleted += result.documents.length;
        offset += limit;
      }

      return { message: `Deleted ${totalDeleted} of ${total} recipes.` };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  }
};
