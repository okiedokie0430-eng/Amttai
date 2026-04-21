import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { clearAdminSession } from '$lib/server/auth';

export const GET: RequestHandler = async ({ cookies }) => {
  clearAdminSession(cookies);
  throw redirect(303, '/login');
};
