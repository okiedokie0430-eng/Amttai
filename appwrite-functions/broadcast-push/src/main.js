import { Client, ID, Messaging, Query, Users } from 'node-appwrite';

const DEFAULT_PAGE_SIZE = 100;
const DEFAULT_TARGET_BATCH_SIZE = 100;
const MAX_DATA_ENTRIES = 20;
const MAX_KEY_LENGTH = 64;
const MAX_VALUE_LENGTH = 1024;

function parseJsonBody(raw) {
  if (!raw) {
    return {};
  }

  if (typeof raw === 'object') {
    return raw;
  }

  if (typeof raw !== 'string') {
    throw new Error('Invalid JSON body.');
  }

  if (!raw.trim()) {
    return {};
  }

  try {
    return JSON.parse(raw);
  } catch {
    throw new Error('Invalid JSON body.');
  }
}

function parsePositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? '').trim(), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

function toFlatStringMap(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return {};
  }

  const result = {};
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

function chunkArray(items, size) {
  const chunks = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

function createAppwriteClients() {
  const endpoint = String(process.env.APPWRITE_ENDPOINT || '').trim();
  const projectId = String(process.env.APPWRITE_PROJECT_ID || '').trim();
  const apiKey = String(process.env.APPWRITE_API_KEY || '').trim();

  if (!endpoint || !projectId || !apiKey) {
    throw new Error(
      'Missing Appwrite env vars. Required: APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_API_KEY.'
    );
  }

  const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
  return {
    usersApi: new Users(client),
    messagingApi: new Messaging(client)
  };
}

async function listAllUserIds(usersApi, pageSize) {
  const userIds = [];
  let offset = 0;

  while (true) {
    const result = await usersApi.list([Query.limit(pageSize), Query.offset(offset)]);
    const users = Array.isArray(result.users) ? result.users : [];

    if (!users.length) {
      break;
    }

    for (const user of users) {
      if (user?.$id) {
        userIds.push(String(user.$id));
      }
    }

    offset += users.length;
    if (users.length < pageSize) {
      break;
    }
  }

  return userIds;
}

async function listAllPushTargetsForUser({ usersApi, userId, pageSize, providerId }) {
  const targetIds = [];
  let offset = 0;

  while (true) {
    const result = await usersApi.listTargets(userId, [Query.limit(pageSize), Query.offset(offset)]);
    const targets = Array.isArray(result.targets) ? result.targets : [];

    if (!targets.length) {
      break;
    }

    for (const target of targets) {
      const isPush = String(target?.providerType || '').toLowerCase() === 'push';
      if (!isPush || target?.expired) {
        continue;
      }

      if (providerId && String(target?.providerId || '').trim() !== providerId) {
        continue;
      }

      if (target?.$id) {
        targetIds.push(String(target.$id));
      }
    }

    offset += targets.length;
    if (targets.length < pageSize) {
      break;
    }
  }

  return targetIds;
}

async function collectBroadcastTargets({ usersApi, userIds, pageSize, providerId, log }) {
  const allTargetIds = [];
  const usersWithTargets = new Set();

  for (const userId of userIds) {
    try {
      const targetIds = await listAllPushTargetsForUser({
        usersApi,
        userId,
        pageSize,
        providerId
      });

      if (targetIds.length > 0) {
        usersWithTargets.add(userId);
        allTargetIds.push(...targetIds);
      }
    } catch (err) {
      log(`Failed to list push targets for user ${userId}: ${String(err)}`);
    }
  }

  return {
    allTargetIds,
    usersWithTargets: usersWithTargets.size,
    noTargetUsers: Math.max(userIds.length - usersWithTargets.size, 0)
  };
}

async function validateProviderIfConfigured(messagingApi, providerId) {
  if (!providerId) {
    return;
  }

  const provider = await messagingApi.getProvider(providerId);
  if (!provider || provider.enabled !== true) {
    throw new Error(`Configured push provider '${providerId}' is missing or disabled.`);
  }
}

async function queuePushMessages({
  messagingApi,
  title,
  body,
  data,
  action,
  targetIds,
  batchSize,
  log
}) {
  let queuedMessages = 0;
  let queuedTargets = 0;
  let failedMessages = 0;
  let failedTargets = 0;
  const messageIds = [];

  for (const batch of chunkArray(targetIds, batchSize)) {
    try {
      const message = await messagingApi.createPush(
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
      messageIds.push(String(message.$id || ''));
    } catch (err) {
      failedMessages += 1;
      failedTargets += batch.length;
      log(`Failed to queue push message for batch size ${batch.length}: ${String(err)}`);
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

function buildCompatStats({
  usersScanned,
  usersWithTargets,
  totalTargets,
  queuedMessages,
  queuedTargets,
  failedMessages,
  failedTargets,
  noTargetUsers
}) {
  return {
    usersScanned,
    usersWithTargets,
    totalTargets,
    queuedMessages,
    queuedTargets,
    failedMessages,
    failedTargets,
    noTargetUsers,
    usersWithTokens: usersWithTargets,
    totalTokens: totalTargets,
    sent: queuedTargets,
    failed: failedTargets,
    prunedUsers: 0
  };
}

export default async ({ req, res, log, error }) => {
  try {
    const payload = parseJsonBody(req.body || '{}');
    const title = String(payload.title || '').trim();
    const body = String(payload.body || '').trim();
    const data = toFlatStringMap(payload.data);
    const action = String(payload.action || '').trim() || undefined;
    const callerIdHeader = req.headers['x-appwrite-user-id'];
    const callerId = Array.isArray(callerIdHeader) ? callerIdHeader[0] : callerIdHeader;
    const normalizedCallerId = String(callerId || '').trim();

    if (!title || !body) {
      return res.json({ ok: false, message: 'title and body are required.' }, 400);
    }

    if (title.length > 120 || body.length > 1000) {
      return res.json({ ok: false, message: 'title or body exceeds allowed length.' }, 400);
    }

    const sharedSecret = String(process.env.BROADCAST_PUSH_SECRET || '').trim();
    if (!normalizedCallerId && !sharedSecret) {
      return res.json(
        { ok: false, message: 'BROADCAST_PUSH_SECRET must be configured for unauthenticated executions.' },
        500
      );
    }

    if (sharedSecret) {
      const incomingSecret = String(payload.secret || '').trim();
      if (incomingSecret !== sharedSecret) {
        return res.json({ ok: false, message: 'Unauthorized broadcast request.' }, 403);
      }
    }

    const pageSize = parsePositiveInt(process.env.BROADCAST_USER_PAGE_SIZE, DEFAULT_PAGE_SIZE);
    const batchSize = parsePositiveInt(process.env.BROADCAST_TARGET_BATCH_SIZE, DEFAULT_TARGET_BATCH_SIZE);
    const providerId = String(process.env.APPWRITE_PUSH_PROVIDER_ID || '').trim() || null;

    const { usersApi, messagingApi } = createAppwriteClients();
    await validateProviderIfConfigured(messagingApi, providerId);

    const userIds = await listAllUserIds(usersApi, pageSize);
    if (userIds.length === 0) {
      return res.json({
        ok: true,
        message: 'No users found. Broadcast skipped.',
        stats: buildCompatStats({
          usersScanned: 0,
          usersWithTargets: 0,
          totalTargets: 0,
          queuedMessages: 0,
          queuedTargets: 0,
          failedMessages: 0,
          failedTargets: 0,
          noTargetUsers: 0
        })
      });
    }

    const targetScan = await collectBroadcastTargets({
      usersApi,
      userIds,
      pageSize,
      providerId,
      log
    });

    if (targetScan.allTargetIds.length === 0) {
      return res.json({
        ok: true,
        message: 'No push targets found. Ensure Android users logged in and push target registration succeeded.',
        stats: buildCompatStats({
          usersScanned: userIds.length,
          usersWithTargets: 0,
          totalTargets: 0,
          queuedMessages: 0,
          queuedTargets: 0,
          failedMessages: 0,
          failedTargets: 0,
          noTargetUsers: targetScan.noTargetUsers
        })
      });
    }

    const queueResult = await queuePushMessages({
      messagingApi,
      title,
      body,
      data,
      action,
      targetIds: targetScan.allTargetIds,
      batchSize,
      log
    });

    const stats = buildCompatStats({
      usersScanned: userIds.length,
      usersWithTargets: targetScan.usersWithTargets,
      totalTargets: targetScan.allTargetIds.length,
      queuedMessages: queueResult.queuedMessages,
      queuedTargets: queueResult.queuedTargets,
      failedMessages: queueResult.failedMessages,
      failedTargets: queueResult.failedTargets,
      noTargetUsers: targetScan.noTargetUsers
    });

    if (queueResult.queuedMessages === 0) {
      return res.json(
        {
          ok: false,
          message: 'Broadcast failed. No Appwrite push messages were queued.',
          stats
        },
        500
      );
    }

    const providerSuffix = providerId ? ` (provider: ${providerId})` : '';
    const partial = queueResult.failedMessages > 0 ? 'partial: ' : '';
    return res.json({
      ok: true,
      message:
        `Broadcast ${partial}queued ${queueResult.queuedMessages} Appwrite push message(s) ` +
        `for ${queueResult.queuedTargets} target(s)${providerSuffix}.`,
      messageIds: queueResult.messageIds,
      stats
    });
  } catch (err) {
    error(String(err?.stack || err));
    return res.json(
      {
        ok: false,
        message: err instanceof Error ? err.message : 'Broadcast failed.'
      },
      500
    );
  }
};
