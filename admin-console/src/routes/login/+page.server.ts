import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';
import {
  getAdminPasswordConfigurationError,
  setAdminSession,
  verifyAdminPassword
} from '$lib/server/auth';

export const actions: Actions = {
  default: async ({ request, cookies }) => {
    const passwordConfigError = getAdminPasswordConfigurationError();
    if (passwordConfigError) {
      return fail(500, { error: passwordConfigError });
    }

    const formData = await request.formData();
    const password = String(formData.get('password') ?? '');

    if (!verifyAdminPassword(password)) {
      return fail(400, { error: 'Invalid admin password.' });
    }

    setAdminSession(cookies);
    throw redirect(303, '/');
  }
};
