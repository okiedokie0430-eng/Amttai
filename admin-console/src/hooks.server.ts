import type { Handle } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';
import { ADMIN_COOKIE_NAME, isAdminSessionValid } from '$lib/server/auth';

export const handle: Handle = async ({ event, resolve }) => {
  const pathname = event.url.pathname;
  const isLoginRoute = pathname === '/login' || pathname.startsWith('/login');

  const token = event.cookies.get(ADMIN_COOKIE_NAME);
  const isAuthenticated = isAdminSessionValid(token);
  event.locals.isAdminAuthenticated = isAuthenticated;

  if (!isAuthenticated && !isLoginRoute) {
    throw redirect(303, '/login');
  }

  if (isAuthenticated && isLoginRoute) {
    throw redirect(303, '/');
  }

  return resolve(event);
};
