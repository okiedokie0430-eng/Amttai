import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { ExecutionMethod } from 'node-appwrite';
import {
  ensureAppwriteReady,
  formatAdminError,
  functionIds,
  functions
} from '$lib/server/appwrite';

export const load: PageServerLoad = async () => {
  try {
    ensureAppwriteReady();

    const list = await functions.list();
    const rows = list.functions.map((fn) => ({
      id: fn.$id,
      name: fn.name,
      runtime: fn.runtime,
      enabled: fn.enabled,
      timeout: fn.timeout,
      deployments: (fn as any).deploymentsTotal ?? 0
    }));

    return {
      functions: rows,
      knownIds: Object.values(functionIds),
      loadError: null
    };
  } catch (error) {
    return {
      functions: [],
      knownIds: Object.values(functionIds),
      loadError: formatAdminError(error)
    };
  }
};

export const actions: Actions = {
  execute: async ({ request }) => {
    try {
      ensureAppwriteReady();

      const formData = await request.formData();
      const functionId = String(formData.get('functionId') ?? '').trim();
      const payload = String(formData.get('payload') ?? '').trim();

      if (!functionId) {
        return fail(400, { error: 'functionId is required.' });
      }

      const execution = await functions.createExecution(functionId, payload || '{}', false, '/', ExecutionMethod.POST);

      return {
        message: `Execution started: ${execution.$id}`
      };
    } catch (error) {
      return fail(500, { error: formatAdminError(error) });
    }
  }
};
