import crypto from 'node:crypto';
import type { Cookies } from '@sveltejs/kit';
import { dev } from '$app/environment';
import { env } from '$env/dynamic/private';

const configuredAdminPassword = (env.ADMIN_CONSOLE_PASSWORD ?? '').trim();
const configuredSessionSecret = (env.ADMIN_CONSOLE_SESSION_SECRET ?? '').trim();
const DEV_DEFAULT_PASSWORD = 'change_me';
const SESSION_MAX_AGE_SECONDS = 60 * 60 * 12;
const LOGIN_WINDOW_MS = 15 * 60 * 1000;
const LOGIN_BLOCK_MS = 15 * 60 * 1000;
const MAX_LOGIN_ATTEMPTS = 8;

export const ADMIN_COOKIE_NAME = 'amttai_admin_session';

const loginAttempts = new Map<string, { attempts: number; windowStartMs: number; blockedUntilMs: number }>();

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

function getEffectiveSessionSecret() {
  if (configuredSessionSecret) {
    return configuredSessionSecret;
  }

  if (dev) {
    return `amttai-dev-session-secret:${getEffectiveAdminPassword()}`;
  }

  return '';
}

function hmac(value: string) {
  return crypto.createHmac('sha256', getEffectiveSessionSecret()).update(value).digest('hex');
}

function timingSafeEqualString(a: string, b: string) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  if (left.length !== right.length) {
    return false;
  }

  return crypto.timingSafeEqual(left, right);
}

function buildToken() {
  const issuedAt = Math.floor(Date.now() / 1000);
  const nonce = crypto.randomBytes(16).toString('hex');
  const payload = `${issuedAt}.${nonce}`;
  const signature = hmac(payload);
  return `v1.${issuedAt}.${nonce}.${signature}`;
}

function parseToken(token: string) {
  const parts = token.split('.');
  if (parts.length !== 4 || parts[0] !== 'v1') {
    return null;
  }

  const issuedAt = Number(parts[1]);
  const nonce = parts[2] ?? '';
  const signature = parts[3] ?? '';
  if (!Number.isFinite(issuedAt) || !nonce || !signature) {
    return null;
  }

  return { issuedAt, nonce, signature };
}

function isTokenExpired(issuedAt: number) {
  const now = Math.floor(Date.now() / 1000);
  return now - issuedAt >= SESSION_MAX_AGE_SECONDS || issuedAt > now + 60;
}

function getStableClientKey(ip?: string | null) {
  return (ip ?? '').trim() || 'unknown';
}

function buildExpectedSignature(issuedAt: number, nonce: string) {
  return hmac(`${issuedAt}.${nonce}`);
}

export function getClientIp(request: Request) {
  const forwarded = request.headers.get('x-forwarded-for');
  if (forwarded) {
    return forwarded.split(',')[0]?.trim() ?? null;
  }

  return request.headers.get('x-real-ip');
}

export function getAdminPasswordConfigurationError() {
  if (configuredAdminPassword || dev) {
    return null;
  }

  return 'ADMIN_CONSOLE_PASSWORD is not configured on the server.';
}

export function getAdminSessionConfigurationError() {
  if (getEffectiveSessionSecret()) {
    return null;
  }

  return 'ADMIN_CONSOLE_SESSION_SECRET is not configured on the server.';
}

export function verifyAdminPassword(password: string) {
  const adminPassword = getEffectiveAdminPassword();
  if (!adminPassword) {
    return false;
  }

  return timingSafeEqualString(password, adminPassword);
}

export function isAdminSessionValid(token?: string | null) {
  const adminPassword = getEffectiveAdminPassword();
  const sessionSecret = getEffectiveSessionSecret();
  if (!token) return false;
  if (!adminPassword) return false;
  if (!sessionSecret) return false;

  const parsed = parseToken(token);
  if (!parsed) {
    return false;
  }

  if (isTokenExpired(parsed.issuedAt)) {
    return false;
  }

  const expectedSignature = buildExpectedSignature(parsed.issuedAt, parsed.nonce);
  return timingSafeEqualString(parsed.signature, expectedSignature);
}

export function canAttemptLogin(ip?: string | null) {
  const key = getStableClientKey(ip);
  const now = Date.now();
  const state = loginAttempts.get(key);
  if (!state) {
    return true;
  }

  if (state.blockedUntilMs > now) {
    return false;
  }

  if (now - state.windowStartMs > LOGIN_WINDOW_MS) {
    loginAttempts.delete(key);
    return true;
  }

  return true;
}

export function registerLoginFailure(ip?: string | null) {
  const key = getStableClientKey(ip);
  const now = Date.now();
  const state = loginAttempts.get(key);

  if (!state || now - state.windowStartMs > LOGIN_WINDOW_MS) {
    loginAttempts.set(key, {
      attempts: 1,
      windowStartMs: now,
      blockedUntilMs: 0
    });
    return;
  }

  state.attempts += 1;
  if (state.attempts >= MAX_LOGIN_ATTEMPTS) {
    state.blockedUntilMs = now + LOGIN_BLOCK_MS;
  }
}

export function clearLoginFailures(ip?: string | null) {
  loginAttempts.delete(getStableClientKey(ip));
}

export function getLoginThrottleMessage() {
  return 'Too many login attempts. Please wait a few minutes and try again.';
}

export function setAdminSession(cookies: Cookies) {
  cookies.set(ADMIN_COOKIE_NAME, buildToken(), {
    path: '/',
    httpOnly: true,
    sameSite: 'strict',
    secure: !dev,
    maxAge: SESSION_MAX_AGE_SECONDS
  });
}

export function clearAdminSession(cookies: Cookies) {
  cookies.delete(ADMIN_COOKIE_NAME, {
    path: '/',
    httpOnly: true,
    sameSite: 'strict',
    secure: !dev
  });
}
