import crypto from 'node:crypto';
import type { Cookies } from '@sveltejs/kit';
import { dev } from '$app/environment';
import { env } from '$env/dynamic/private';

const configuredAdminPassword = (env.ADMIN_CONSOLE_PASSWORD ?? '').trim();
const DEV_DEFAULT_PASSWORD = 'change_me';

export const ADMIN_COOKIE_NAME = 'amttai_admin_session';

function getEffectiveAdminPassword() {
  if (configuredAdminPassword) {
    return configuredAdminPassword;
  }

  // Keep local development unblocked even if .env is not configured yet.
  if (dev) {
    return DEV_DEFAULT_PASSWORD;
  }

  return '';
}

export function getAdminPasswordConfigurationError() {
  if (configuredAdminPassword || dev) {
    return null;
  }

  return 'ADMIN_CONSOLE_PASSWORD is not configured on the server.';
}

function buildToken() {
  const adminPassword = getEffectiveAdminPassword();

  return crypto
    .createHash('sha256')
    .update(`amttai-admin:${adminPassword}`)
    .digest('hex');
}

export function verifyAdminPassword(password: string) {
  const adminPassword = getEffectiveAdminPassword();
  if (!adminPassword) {
    return false;
  }

  return password === adminPassword;
}

export function isAdminSessionValid(token?: string | null) {
  const adminPassword = getEffectiveAdminPassword();
  if (!token) return false;
  if (!adminPassword) return false;
  return token === buildToken();
}

export function setAdminSession(cookies: Cookies) {
  cookies.set(ADMIN_COOKIE_NAME, buildToken(), {
    path: '/',
    httpOnly: true,
    sameSite: 'strict',
    secure: !dev,
    maxAge: 60 * 60 * 12
  });
}

export function clearAdminSession(cookies: Cookies) {
  cookies.delete(ADMIN_COOKIE_NAME, { path: '/' });
}
