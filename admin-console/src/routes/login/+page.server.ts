import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';
import {
  canAttemptLogin,
  clearLoginFailures,
  getAdminSessionConfigurationError,
  getClientIp,
  getLoginThrottleMessage,
  getAdminPasswordConfigurationError,
  registerLoginFailure,
  setAdminSession,
  verifyAdminPassword
} from '$lib/server/auth';

export const actions: Actions = {
  default: async ({ request, cookies }) => {
    const passwordConfigError = getAdminPasswordConfigurationError();
    if (passwordConfigError) {
      return fail(500, { error: passwordConfigError });
    }

    const sessionConfigError = getAdminSessionConfigurationError();
    if (sessionConfigError) {
      return fail(500, { error: sessionConfigError });
    }

    const clientIp = getClientIp(request);
    if (!canAttemptLogin(clientIp)) {
      return fail(429, { error: getLoginThrottleMessage() });
    }

    const formData = await request.formData();
    const password = String(formData.get('password') ?? '');

    if (!verifyAdminPassword(password)) {
      registerLoginFailure(clientIp);
      return fail(400, { error: 'Invalid admin password.' });
    }

    clearLoginFailures(clientIp);
    setAdminSession(cookies);
    throw redirect(303, '/');
  }
};
