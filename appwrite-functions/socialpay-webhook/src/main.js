import { Client, Databases, Query } from 'node-appwrite';

const SUCCESS_STATUSES = new Set([
  'success',
  'successful',
  'paid',
  'approved',
  'completed',
  'done',
]);

const FAILED_STATUSES = new Set([
  'failed',
  'failure',
  'rejected',
  'declined',
  'cancelled',
  'canceled',
  'expired',
]);

function parseJsonBody(raw) {
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function pickString(...values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
    if (typeof value === 'number') {
      return String(value);
    }
  }
  return '';
}

function resolveStatus(payload) {
  const raw = pickString(
    payload.status,
    payload.payment_status,
    payload.paymentStatus,
    payload.result,
    payload.state,
  ).toLowerCase();

  if (SUCCESS_STATUSES.has(raw)) return 'approved';
  if (FAILED_STATUSES.has(raw)) return 'rejected';
  return 'pending';
}

function resolveTransactionCode(payload) {
  const direct = pickString(
    payload.transaction_code,
    payload.transactionCode,
    payload.tx_code,
    payload.txCode,
    payload.reference,
    payload.referenceCode,
    payload.order_id,
    payload.orderId,
  );
  if (direct) return direct;

  const description = pickString(
    payload.description,
    payload.desc,
    payload.note,
    payload.remark,
    payload.metadata?.description,
  );
  if (!description) return '';

  const match = description.match(/(SP|AMTTAI)-[A-Z0-9]+-[A-Z]+-\d+/i);
  return match?.[0] ?? '';
}

function resolveTransactionId(payload) {
  return pickString(
    payload.transaction_id,
    payload.transactionId,
    payload.provider_transaction_id,
    payload.providerTransactionId,
    payload.payment_id,
    payload.paymentId,
    payload.trace_no,
    payload.traceNo,
  );
}

function addMonths(base, months) {
  const d = new Date(base);
  const day = d.getDate();
  d.setMonth(d.getMonth() + months);
  if (d.getDate() < day) {
    d.setDate(0);
  }
  return d;
}

function resolvePlanMonths(plan) {
  switch (String(plan || '').toLowerCase()) {
    case 'onemonth':
      return 1;
    case 'threemonth':
      return 3;
    case 'sixmonth':
      return 6;
    default:
      return 1;
  }
}

function authHeaderMatchesSecret(headers, secret) {
  if (!secret) return true;

  const received = pickString(
    headers['x-socialpay-signature'],
    headers['x-signature'],
    headers['authorization'],
    headers['Authorization'],
  );

  if (!received) return false;
  return received === secret || received === `Bearer ${secret}`;
}

export default async ({ req, res, log, error }) => {
  const body = parseJsonBody(req.body);
  if (body === null) {
    return res.json({ ok: false, message: 'Invalid JSON body' }, 400);
  }

  const webhookSecret = process.env.SOCIALPAY_WEBHOOK_SECRET || '';
  if (!authHeaderMatchesSecret(req.headers || {}, webhookSecret)) {
    error('Invalid webhook signature/secret');
    return res.json({ ok: false, message: 'Unauthorized' }, 401);
  }

  const transactionCode = resolveTransactionCode(body);
  if (!transactionCode) {
    return res.json({ ok: false, message: 'transactionCode not found in payload' }, 400);
  }

  const status = resolveStatus(body);
  const externalTransactionId = resolveTransactionId(body);

  const databaseId = process.env.DATABASE_ID || 'amttai_db';
  const paymentsCollection = process.env.PAYMENTS_COLLECTION || 'payments';
  const usersCollection = process.env.USERS_COLLECTION || 'users';

  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const databases = new Databases(client);

  const docs = await databases.listDocuments(databaseId, paymentsCollection, [
    Query.equal('transaction_code', transactionCode),
    Query.orderDesc('created_at'),
    Query.limit(1),
  ]);

  if (docs.documents.length === 0) {
    return res.json({ ok: false, message: 'Payment not found', transactionCode }, 404);
  }

  const paymentDoc = docs.documents[0];
  const updatePayload = {
    status,
    transaction_id: externalTransactionId || paymentDoc.transaction_id || 'SOCIALPAY',
    verified_at: status === 'pending' ? null : new Date().toISOString(),
  };

  const updatedPayment = await databases.updateDocument(
    databaseId,
    paymentsCollection,
    paymentDoc.$id,
    updatePayload,
  );

  if (status === 'approved') {
    try {
      const userId = pickString(paymentDoc.user_id, body.user_id, body.userId);
      if (!userId) {
        throw new Error('Missing user_id in payment record');
      }

      const userDoc = await databases.getDocument(databaseId, usersCollection, userId);
      const months = resolvePlanMonths(paymentDoc.plan);

      const now = new Date();
      const currentExpiryRaw = pickString(userDoc.premium_expires_at);
      const currentExpiry = currentExpiryRaw ? new Date(currentExpiryRaw) : null;
      const baseDate =
        currentExpiry && currentExpiry.getTime() > now.getTime() ? currentExpiry : now;

      const premiumExpiresAt = addMonths(baseDate, months).toISOString();

      await databases.updateDocument(databaseId, usersCollection, userId, {
        is_premium: true,
        premium_expires_at: premiumExpiresAt,
      });

      log(`Premium activated for user ${userId} until ${premiumExpiresAt}`);
    } catch (e) {
      error(`Payment updated but premium activation failed: ${e.message}`);
      return res.json(
        {
          ok: false,
          message: 'Payment approved but failed to activate premium',
          transactionCode,
          paymentId: updatedPayment.$id,
        },
        500,
      );
    }
  }

  return res.json({
    ok: true,
    transactionCode,
    paymentId: updatedPayment.$id,
    status,
  });
};
