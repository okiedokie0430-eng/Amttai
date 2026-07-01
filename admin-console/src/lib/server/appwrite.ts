import { env } from '$env/dynamic/private';
import { AppwriteException, Client, Databases, Functions, Messaging, Query, Storage, Users } from 'node-appwrite';

const rawAppwriteApiKey = (env.APPWRITE_API_KEY ?? '').trim();
const rawAppwriteDatabaseId = (env.APPWRITE_DATABASE_ID ?? '').trim();
const rawAppwriteEndpoint = (env.APPWRITE_ENDPOINT ?? '').trim();
const rawAppwriteProjectId = (env.APPWRITE_PROJECT_ID ?? '').trim();

function envOrDefault(key: string, fallback: string) {
  const value = ((env as Record<string, string | undefined>)[key] ?? '').trim();
  return value || fallback;
}

const APPWRITE_API_KEY = rawAppwriteApiKey || 'missing-api-key';
const APPWRITE_ENDPOINT = rawAppwriteEndpoint || 'https://cloud.appwrite.io/v1';
const APPWRITE_PROJECT_ID = rawAppwriteProjectId || 'missing-project-id';

const appwriteConfigIssues: string[] = [];
if (!rawAppwriteEndpoint) {
  appwriteConfigIssues.push('APPWRITE_ENDPOINT is missing.');
}
if (!rawAppwriteProjectId) {
  appwriteConfigIssues.push('APPWRITE_PROJECT_ID is missing.');
}
if (!rawAppwriteApiKey) {
  appwriteConfigIssues.push('APPWRITE_API_KEY is missing.');
}
if (!rawAppwriteDatabaseId) {
  appwriteConfigIssues.push('APPWRITE_DATABASE_ID is missing (falling back to amttai_db).');
}

const client = new Client()
  .setEndpoint(APPWRITE_ENDPOINT)
  .setProject(APPWRITE_PROJECT_ID)
  .setKey(APPWRITE_API_KEY);

export const databases = new Databases(client);
export const storage = new Storage(client);
export const functions = new Functions(client);
export const users = new Users(client);
export const messaging = new Messaging(client);

export const databaseId = rawAppwriteDatabaseId || 'amttai_db';
export const appwriteEndpoint = APPWRITE_ENDPOINT;
export const appwriteProjectId = APPWRITE_PROJECT_ID;

export const collectionIds = {
  users: envOrDefault('APPWRITE_COLLECTION_USERS_ID', 'users'),
  recipes: envOrDefault('APPWRITE_COLLECTION_RECIPES_ID', 'recipes'),
  ratings: envOrDefault('APPWRITE_COLLECTION_RATINGS_ID', 'ratings'),
  payments: envOrDefault('APPWRITE_COLLECTION_PAYMENTS_ID', 'payments'),
  supportMessages: envOrDefault('APPWRITE_COLLECTION_SUPPORT_MESSAGES_ID', 'support_messages'),
  dataErasureRequests: envOrDefault('APPWRITE_COLLECTION_DATA_ERASURE_REQUESTS_ID', 'data_erasure_requests')
} as const;

export const functionIds = {
  deleteAccount: envOrDefault('APPWRITE_FUNCTION_DELETE_ACCOUNT_ID', 'delete-account'),
  broadcastPush: envOrDefault('APPWRITE_FUNCTION_BROADCAST_PUSH_ID', 'broadcast-push')
} as const;

export const bucketIds = {
  recipeImages: envOrDefault('APPWRITE_BUCKET_RECIPE_IMAGES_ID', 'recipe_images'),
  recipeVideos: envOrDefault('APPWRITE_BUCKET_RECIPE_VIDEOS_ID', 'recipe_videos'),
  profilePhotos: envOrDefault('APPWRITE_BUCKET_PROFILE_PHOTOS_ID', 'profile_photos'),
  paymentScreenshots: envOrDefault('APPWRITE_BUCKET_PAYMENT_SCREENSHOTS_ID', 'payment_screenshots')
} as const;

const collectionAttributeCache = new Map<string, Set<string>>();

export function toDocumentData(document: Record<string, any>) {
  const nestedData =
    document && typeof document.data === 'object' && document.data !== null
      ? (document.data as Record<string, any>)
      : document;

  const data = { ...nestedData };

  if (!data.$id && document.$id) {
    data.$id = document.$id;
  }
  if (!data.$createdAt && document.$createdAt) {
    data.$createdAt = document.$createdAt;
  }

  return data;
}

export function mapDocumentWithId(document: Record<string, any>): Record<string, any> & { id: string } {
  const data = toDocumentData(document);
  return {
    id: String(data.$id ?? ''),
    ...data
  };
}

export function getDocumentField<T = unknown>(document: Record<string, any>, key: string): T | undefined {
  const data = toDocumentData(document);
  return data[key] as T | undefined;
}

export async function getCollectionAttributeKeys(collectionId: string) {
  const cached = collectionAttributeCache.get(collectionId);
  if (cached) {
    return cached;
  }

  const listed = await databases.listAttributes(databaseId, collectionId);
  const keys = new Set<string>(listed.attributes.map((attr: any) => attr.key));
  collectionAttributeCache.set(collectionId, keys);
  return keys;
}

export async function filterDataForCollection(collectionId: string, data: Record<string, any>) {
  try {
    const keys = await getCollectionAttributeKeys(collectionId);
    if (keys.size === 0) {
      return data;
    }

    const filtered = Object.fromEntries(Object.entries(data).filter(([key]) => keys.has(key)));
    return filtered;
  } catch {
    // If metadata lookup fails, return original payload and let Appwrite validate.
    return data;
  }
}

export function buildStorageFileViewUrl(bucketId: string, fileId: string) {
  const endpoint = APPWRITE_ENDPOINT.replace(/\/$/, '');
  const encodedBucketId = encodeURIComponent(bucketId);
  const encodedFileId = encodeURIComponent(fileId);
  const encodedProject = encodeURIComponent(APPWRITE_PROJECT_ID);
  return `${endpoint}/storage/buckets/${encodedBucketId}/files/${encodedFileId}/view?project=${encodedProject}`;
}

export function getAppwriteConfigurationError() {
  if (appwriteConfigIssues.length === 0) {
    return null;
  }

  return `Admin console Appwrite configuration issue: ${appwriteConfigIssues.join(' ')}`;
}

export function ensureAppwriteReady() {
  const configError = getAppwriteConfigurationError();
  if (configError) {
    throw new Error(configError);
  }
}

export function formatAdminError(error: unknown) {
  if (error instanceof AppwriteException) {
    return `Appwrite error ${error.code}: ${error.message}`;
  }

  if (error instanceof Error) {
    return error.message;
  }

  return 'Unexpected server error.';
}

export async function getCollectionTotal(collectionId: string) {
  const result = await databases.listDocuments(databaseId, collectionId, [Query.limit(1)]);
  return result.total;
}

export function generateSerializedUserCode(now = new Date()) {
  const year = String(now.getUTCFullYear() % 100).padStart(2, '0');
  const start = Date.UTC(now.getUTCFullYear(), 0, 1);
  const dayOfYear = Math.floor((Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) - start) / 86400000) + 1;
  const day = String(dayOfYear).padStart(3, '0');
  const randomPart = Array.from({ length: 6 }, () => Math.floor(Math.random() * 10)).join('');
  const core = `${year}${day}${randomPart}`;

  let sum = 0;
  for (let i = 0; i < core.length; i += 1) {
    const weight = i % 2 === 0 ? 3 : 7;
    sum += Number(core[i]) * weight;
  }
  const checkDigit = String(sum % 10);

  return `${core}${checkDigit}`;
}

export function planToMonths(plan: string) {
  switch ((plan || '').toLowerCase()) {
    case 'onemonth':
      return 1;
    case 'threemonth':
      return 3;
    case 'sixmonth':
      return 6;
    case 'oneyear':
      return 12;
    default:
      return 1;
  }
}

export function addMonths(base: Date, months: number) {
  const d = new Date(base);
  const day = d.getDate();
  d.setMonth(d.getMonth() + months);
  if (d.getDate() < day) {
    d.setDate(0);
  }
  return d;
}
