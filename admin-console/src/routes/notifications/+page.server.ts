import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { ID, Query } from 'node-appwrite';
import { env } from '$env/dynamic/private';
import {
  ensureAppwriteReady,
  formatAdminError,
  messaging,
  users
} from '$lib/server/appwrite';

type DispatchStats = {
  usersScanned: number;
  usersWithTargets: number;
  totalTargets: number;
  queuedMessages: number;
  queuedTargets: number;
  failedMessages: number;
  failedTargets: number;
  noTargetUsers: number;
  recipientMode: 'users' | 'targets';
  providerFilter: string | null;
  usedUserFallback: boolean;
};

type RecentMessageSummary = {
  id: string;
  status: string;
  createdAt: string;
  title: string;
  body: string;
  targetsTotal: number;
  deliveredTotal: number;
  failedTotal: number;
};

type DispatchSummary = {
  id: string;
  status: string;
  createdAt: string;
  message: string;
  stats: DispatchStats;
  messageIds: string[];
};

const DEFAULT_USER_PAGE_SIZE = 100;
const DEFAULT_TARGET_BATCH_SIZE = 100;
const MAX_DATA_ENTRIES = 20;
const MAX_KEY_LENGTH = 64;
const MAX_VALUE_LENGTH = 1024;

function parsePositiveInt(value: unknown, fallback: number) {
  const parsed = Number.parseInt(String(value ?? '').trim(), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }

  return parsed;
}

function toSafeNumber(value: unknown) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function sanitizeDataMap(data: Record<string, unknown>) {
  const result: Record<string, string> = {};

  for (const [rawKey, rawValue] of Object.entries(data)) {
    if (Object.keys(result).length >= MAX_DATA_ENTRIES) {
      break;
    }

    const key = String(rawKey ?? '').trim();
    if (!key || key.length > MAX_KEY_LENGTH) {
      continue;
    }

    if (rawValue === null || rawValue === undefined) {
      continue;
    }

    result[key] = String(rawValue).slice(0, MAX_VALUE_LENGTH);
  }

  return result;
}

function chunkArray<T>(items: T[], size: number) {
  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

function toRecentMessageSummary(raw: Record<string, unknown>): RecentMessageSummary {
  return {
    id: String(raw.$id ?? ''),
    status: String(raw.status ?? 'unknown'),
    createdAt: String(raw.$createdAt ?? ''),
    title: String(raw.title ?? ''),
    body: String(raw.body ?? ''),
    targetsTotal: toSafeNumber(raw.targetsTotal),
    deliveredTotal: toSafeNumber(raw.deliveredTotal),
    failedTotal: toSafeNumber(raw.failedTotal)
  };
}

async function listAllUserIds(pageSize: number) {
  const userIds: string[] = [];
  let offset = 0;

  while (true) {
    const listed = await users.list([Query.limit(pageSize), Query.offset(offset)]);
    const batch = Array.isArray(listed.users) ? listed.users : [];

    if (batch.length === 0) {
      break;
    }

    for (const user of batch) {
      if (user?.$id) {
        userIds.push(String(user.$id));
      }
    }

    offset += batch.length;
    if (batch.length < pageSize) {
      break;
    }
  }

  return userIds;
}

async function listPushTargetIdsForUser({
  userId,
  pageSize,
  providerId
}: {
  userId: string;
  pageSize: number;
  providerId: string | null;
}) {
  const targetIds: string[] = [];
  let offset = 0;

  while (true) {
    const listed = await users.listTargets(userId, [Query.limit(pageSize), Query.offset(offset)]);
    const batch = Array.isArray(listed.targets) ? listed.targets : [];

    if (batch.length === 0) {
      break;
    }

    for (const target of batch) {
      const providerType = String(target?.providerType ?? '').trim().toLowerCase();
      const targetProviderId = String(target?.providerId ?? '').trim();

      if (providerType !== 'push' || target?.expired) {
        continue;
      }

      if (providerId && targetProviderId !== providerId) {
        continue;
      }

      if (target?.$id) {
        targetIds.push(String(target.$id));
      }
    }

    offset += batch.length;
    if (batch.length < pageSize) {
      break;
    }
  }

  return targetIds;
}

async function collectBroadcastTargets({
  userIds,
  pageSize,
  providerId
}: {
  userIds: string[];
  pageSize: number;
  providerId: string | null;
}) {
  const allTargetIds: string[] = [];
  let usersWithTargets = 0;

  for (const userId of userIds) {
    const targetIds = await listPushTargetIdsForUser({
      userId,
      pageSize,
      providerId
    });

    if (targetIds.length > 0) {
      usersWithTargets += 1;
      allTargetIds.push(...targetIds);
    }
  }

  return {
    allTargetIds,
    usersWithTargets,
    noTargetUsers: Math.max(userIds.length - usersWithTargets, 0)
  };
}

async function validateProviderIfConfigured(providerId: string | null) {
  if (!providerId) {
    return;
  }

  const provider = await messaging.getProvider(providerId);
  if (!provider || provider.enabled !== true) {
    throw new Error(`Configured push provider '${providerId}' is missing or disabled.`);
  }
}

async function queuePushMessagesToTargets({
  title,
  body,
  data,
  action,
  targetIds,
  batchSize
}: {
  title: string;
  body: string;
  data: Record<string, string>;
  action?: string;
  targetIds: string[];
  batchSize: number;
}) {
  let queuedMessages = 0;
  let queuedTargets = 0;
  let failedMessages = 0;
  let failedTargets = 0;
  const messageIds: string[] = [];

  for (const batch of chunkArray(targetIds, batchSize)) {
    try {
      const message = await messaging.createPush(
        ID.unique(),
        title,
        body,
        undefined,
        undefined,
        batch,
        data,
        action,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        false
      );

      queuedMessages += 1;
      queuedTargets += batch.length;
      messageIds.push(String(message.$id ?? ''));
    } catch {
      failedMessages += 1;
      failedTargets += batch.length;
    }
  }

  return {
    queuedMessages,
    queuedTargets,
    failedMessages,
    failedTargets,
    messageIds
  };
}

async function queuePushMessagesToUsers({
  title,
  body,
  data,
  action,
  userIds,
  batchSize
}: {
  title: string;
  body: string;
  data: Record<string, string>;
  action?: string;
  userIds: string[];
  batchSize: number;
}) {
  let queuedMessages = 0;
  let queuedUsers = 0;
  let failedMessages = 0;
  let failedUsers = 0;
  const messageIds: string[] = [];

  for (const batch of chunkArray(userIds, batchSize)) {
    try {
      const message = await messaging.createPush(
        ID.unique(),
        title,
        body,
        undefined,
        batch,
        undefined,
        data,
        action,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        false
      );

      queuedMessages += 1;
      queuedUsers += batch.length;
      messageIds.push(String(message.$id ?? ''));
    } catch {
      failedMessages += 1;
      failedUsers += batch.length;
    }
  }

  return {
    queuedMessages,
    queuedUsers,
    failedMessages,
    failedUsers,
    messageIds
  };
}

export const load: PageServerLoad = async () => {
  try {
    ensureAppwriteReady();

    const listed = await messaging.listMessages([Query.orderDesc('$createdAt'), Query.limit(30)]);
    const recentMessages = (Array.isArray(listed.messages) ? listed.messages : [])
      .map((message) => toRecentMessageSummary(message as Record<string, unknown>))
      .filter((message) => message.title || message.body)
      .slice(0, 12);

    return {
      recentMessages,
      loadError: null
    };
  } catch (error) {
    return {
      recentMessages: [],
      loadError: formatAdminError(error)
    };
  }
};

export const actions: Actions = {
  sendBroadcast: async ({ request }) => {
    const formData = await request.formData();
    const title = String(formData.get('title') ?? '').trim();
    const body = String(formData.get('body') ?? '').trim();
    const action = String(formData.get('action') ?? '').trim();
    const dataRaw = String(formData.get('data') ?? '').trim();

    const input = {
      title,
      body,
      action,
      data: dataRaw
    };

    if (!title || !body) {
      return fail(400, {
        error: 'Title and body are required.',
        input
      });
    }

    let parsedData: Record<string, unknown> = {};
    if (dataRaw) {
      try {
        const parsed = JSON.parse(dataRaw) as unknown;
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
          return fail(400, {
            error: 'Data must be a JSON object. Example: {"screen":"home"}',
            input
          });
        }

        parsedData = parsed as Record<string, unknown>;
      } catch {
        return fail(400, {
          error: 'Invalid data JSON. Example: {"screen":"home"}',
          input
        });
      }
    }

    try {
      ensureAppwriteReady();

      const providerId = String(env.APPWRITE_PUSH_PROVIDER_ID ?? '').trim() || null;
      const userPageSize = parsePositiveInt(env.BROADCAST_USER_PAGE_SIZE, DEFAULT_USER_PAGE_SIZE);
      const targetBatchSize = parsePositiveInt(env.BROADCAST_TARGET_BATCH_SIZE, DEFAULT_TARGET_BATCH_SIZE);
      const allowUserFallback = String(env.BROADCAST_ALLOW_USER_FALLBACK ?? 'true').trim().toLowerCase() !== 'false';

      await validateProviderIfConfigured(providerId);

      const userIds = await listAllUserIds(userPageSize);
      if (userIds.length === 0) {
        const stats: DispatchStats = {
          usersScanned: 0,
          usersWithTargets: 0,
          totalTargets: 0,
          queuedMessages: 0,
          queuedTargets: 0,
          failedMessages: 0,
          failedTargets: 0,
          noTargetUsers: 0,
          recipientMode: 'users',
          providerFilter: providerId,
          usedUserFallback: false
        };

        const dispatch: DispatchSummary = {
          id: '',
          status: 'skipped',
          createdAt: new Date().toISOString(),
          message: 'No users found. Broadcast skipped.',
          stats,
          messageIds: []
        };

        return {
          message: dispatch.message,
          dispatch,
          input
        };
      }

      const data = sanitizeDataMap(parsedData);

      const sendByUsers = async ({
        targetScan,
        fallbackUsed
      }: {
        targetScan: {
          usersWithTargets: number;
          allTargetIds: string[];
          noTargetUsers: number;
        };
        fallbackUsed: boolean;
      }) => {
        const queueResult = await queuePushMessagesToUsers({
          title,
          body,
          action: action || undefined,
          data,
          userIds,
          batchSize: targetBatchSize
        });

        const stats: DispatchStats = {
          usersScanned: userIds.length,
          usersWithTargets: targetScan.usersWithTargets,
          totalTargets: targetScan.allTargetIds.length,
          queuedMessages: queueResult.queuedMessages,
          queuedTargets: queueResult.queuedUsers,
          failedMessages: queueResult.failedMessages,
          failedTargets: queueResult.failedUsers,
          noTargetUsers: targetScan.noTargetUsers,
          recipientMode: 'users',
          providerFilter: providerId,
          usedUserFallback: fallbackUsed
        };

        const dispatch: DispatchSummary = {
          id: queueResult.messageIds[queueResult.messageIds.length - 1] ?? '',
          status: queueResult.failedMessages > 0 ? 'partial' : 'queued',
          createdAt: new Date().toISOString(),
          message:
            queueResult.queuedMessages > 0
              ? fallbackUsed
                ? `Broadcast queued using user recipients fallback. Messages ${queueResult.queuedMessages}, users ${queueResult.queuedUsers}, failed users ${queueResult.failedUsers}.`
                : `Broadcast queued using user recipients. Messages ${queueResult.queuedMessages}, users ${queueResult.queuedUsers}, failed users ${queueResult.failedUsers}.`
              : 'No messages were queued.',
          stats,
          messageIds: queueResult.messageIds
        };

        return { queueResult, dispatch };
      };

      let queueResult:
        | {
            queuedMessages: number;
            queuedTargets: number;
            failedMessages: number;
            failedTargets: number;
            messageIds: string[];
          }
        | {
            queuedMessages: number;
            queuedUsers: number;
            failedMessages: number;
            failedUsers: number;
            messageIds: string[];
          };
      let dispatch: DispatchSummary;

      if (providerId) {
        const targetScan = await collectBroadcastTargets({
          userIds,
          pageSize: userPageSize,
          providerId
        });

        if (targetScan.allTargetIds.length > 0) {
          const targetQueueResult = await queuePushMessagesToTargets({
            title,
            body,
            action: action || undefined,
            data,
            targetIds: targetScan.allTargetIds,
            batchSize: targetBatchSize
          });

          queueResult = targetQueueResult;
          const stats: DispatchStats = {
            usersScanned: userIds.length,
            usersWithTargets: targetScan.usersWithTargets,
            totalTargets: targetScan.allTargetIds.length,
            queuedMessages: targetQueueResult.queuedMessages,
            queuedTargets: targetQueueResult.queuedTargets,
            failedMessages: targetQueueResult.failedMessages,
            failedTargets: targetQueueResult.failedTargets,
            noTargetUsers: targetScan.noTargetUsers,
            recipientMode: 'targets',
            providerFilter: providerId,
            usedUserFallback: false
          };

          dispatch = {
            id: targetQueueResult.messageIds[targetQueueResult.messageIds.length - 1] ?? '',
            status: targetQueueResult.failedMessages > 0 ? 'partial' : 'queued',
            createdAt: new Date().toISOString(),
            message:
              targetQueueResult.queuedMessages > 0
                ? `Broadcast queued. Messages ${targetQueueResult.queuedMessages}, targets ${targetQueueResult.queuedTargets}, failed targets ${targetQueueResult.failedTargets}.`
                : 'No messages were queued.',
            stats,
            messageIds: targetQueueResult.messageIds
          };
        } else if (allowUserFallback) {
          const userSend = await sendByUsers({ targetScan, fallbackUsed: true });
          queueResult = userSend.queueResult;
          dispatch = userSend.dispatch;
        } else {
          const stats: DispatchStats = {
            usersScanned: userIds.length,
            usersWithTargets: 0,
            totalTargets: 0,
            queuedMessages: 0,
            queuedTargets: 0,
            failedMessages: 0,
            failedTargets: 0,
            noTargetUsers: targetScan.noTargetUsers,
            recipientMode: 'targets',
            providerFilter: providerId,
            usedUserFallback: false
          };

          dispatch = {
            id: '',
            status: 'skipped',
            createdAt: new Date().toISOString(),
            message:
              'No push targets found for configured provider. Set BROADCAST_ALLOW_USER_FALLBACK=true to send by users instead.',
            stats,
            messageIds: []
          };

          return {
            message: dispatch.message,
            dispatch,
            input
          };
        }
      } else {
        const targetScan = {
          usersWithTargets: 0,
          allTargetIds: [] as string[],
          noTargetUsers: 0
        };
        const userSend = await sendByUsers({ targetScan, fallbackUsed: false });
        queueResult = userSend.queueResult;
        dispatch = userSend.dispatch;
      }

      if (queueResult.queuedMessages === 0) {
        return fail(500, {
          error: 'Broadcast failed. No push messages were queued.',
          dispatch,
          input
        });
      }

      return {
        message: dispatch.message,
        dispatch,
        input
      };
    } catch (error) {
      return fail(500, {
        error: formatAdminError(error),
        input
      });
    }
  }
};
