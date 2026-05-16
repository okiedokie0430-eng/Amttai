import { Client, Databases, ID, Query } from 'node-appwrite';
import crypto from 'crypto-js';

const DATABASE_ID = process.env.DATABASE_ID || 'amttai_db';
const PAYMENTS_COLLECTION = process.env.PAYMENTS_COLLECTION || 'payments';
const USERS_COLLECTION = process.env.USERS_COLLECTION || 'users';
const SMS_TRANSACTIONS_COLLECTION = process.env.SMS_TRANSACTIONS_COLLECTION || 'sms_transactions';
const HMAC_SECRET = process.env.HMAC_SECRET || 'amttai-bridge-hmac-secret-change-me';
const AMOUNT_TOLERANCE = Number.parseInt(process.env.AMOUNT_TOLERANCE || '500', 10);

function validateSignature(payload, log, error) {
  const { device_id, transaction_code, amount, timestamp, nonce, signature } = payload;
  
  if (!signature) {
    error('Missing signature in payload.');
    return false;
  }

  const message = `${device_id}|${transaction_code}|${amount}|${timestamp}|${nonce}`;
  const expectedSignature = crypto.HmacSHA256(message, HMAC_SECRET).toString();
  
  if (signature !== expectedSignature) {
    error(`Signature mismatch. Expected: ${expectedSignature}, Received: ${signature}. Payload message: ${message}`);
    return false;
  }
  return true;
}

function planMonths(planName) {
  const normalized = String(planName).toLowerCase().replace(/[^a-z0-9]/g, '');
  if (normalized.includes('three') || normalized.includes('3')) return 3;
  if (normalized.includes('six') || normalized.includes('6')) return 6;
  if (normalized.includes('year') || normalized.includes('12')) return 12;
  return 1; // Default to 1 month
}

export default async ({ req, res, log, error }) => {
  log("--- NEW PAYMENT REQUEST RECEIVED ---");
  
  if (req.method !== 'POST') {
    error(`Invalid method: ${req.method}`);
    return res.json({ success: false, error: 'Method not allowed' }, 405);
  }

  let payload;
  try {
    payload = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  } catch (err) {
    error(`Failed to parse JSON payload: ${req.body}`);
    return res.json({ success: false, error: 'Invalid JSON payload' }, 400);
  }

  log(`Payload parsed successfully: ${JSON.stringify(payload)}`);

  if (!validateSignature(payload, log, error)) {
    return res.json({ success: false, error: 'Unauthorized signature' }, 401);
  }

  const apiKey =
    req.headers['x-appwrite-key'] ||
    req.headers['X-Appwrite-Key'] ||
    process.env.APPWRITE_API_KEY ||
    process.env.APPWRITE_FUNCTION_API_KEY;

  if (!apiKey) {
    error("Missing APPWRITE_API_KEY in environment or headers.");
    return res.json({ success: false, error: 'Server misconfiguration: API Key missing' }, 500);
  }

  const client = new Client()
    .setEndpoint(
      process.env.APPWRITE_FUNCTION_API_ENDPOINT ||
      process.env.APPWRITE_FUNCTION_ENDPOINT ||
      process.env.APPWRITE_ENDPOINT ||
      'https://fra.cloud.appwrite.io/v1'
    )
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID)
    .setKey(apiKey);

  const db = new Databases(client);

  try {
    log(`Checking for replay attack on nonce: ${payload.nonce}`);
    const existingNonce = await db.listDocuments(DATABASE_ID, SMS_TRANSACTIONS_COLLECTION, [
      Query.equal('nonce', payload.nonce),
      Query.limit(1)
    ]);

    if (existingNonce.documents.length > 0) {
      error(`Replay attack detected. Nonce already used: ${payload.nonce}`);
      return res.json({ success: false, error: 'Nonce already used' }, 409);
    }

    const transactionCode = String(payload.transaction_code || '');
    const directUserId = payload.direct_user_id ? String(payload.direct_user_id) : null;
    const amount = Number.parseInt(payload.amount, 10);
    const now = new Date().toISOString();

    if (!transactionCode || !Number.isFinite(amount) || amount <= 0) {
      error(`Invalid transaction data. Code: ${transactionCode}, Amount: ${amount}`);
      return res.json({ success: false, error: 'Invalid transaction payload' }, 400);
    }

    let paymentId = null;
    let userId = directUserId;
    let plan = payload.plan || 'oneMonth';

    if (!userId) {
      log(`No direct_user_id provided. Looking for pending payment with code: ${transactionCode}`);
      const payments = await db.listDocuments(DATABASE_ID, PAYMENTS_COLLECTION, [
        Query.equal('transaction_code', transactionCode),
        Query.equal('status', 'pending'),
        Query.limit(1)
      ]);

      if (payments.documents.length === 0) {
        error(`No pending payment found for transaction code: ${transactionCode}`);
        return res.json({ success: false, error: 'No pending payment found' }, 404);
      }

      const payment = payments.documents[0];
      paymentId = payment.$id;
      userId = payment.user_id;
      plan = payment.plan || plan;

      const expectedAmount = Number.parseInt(payment.amount, 10);
      if (Number.isFinite(expectedAmount) && Math.abs(amount - expectedAmount) > AMOUNT_TOLERANCE) {
        error(`Amount mismatch: expected ${expectedAmount}, got ${amount} (tolerance ${AMOUNT_TOLERANCE})`);
        return res.json({
          success: false,
          error: `Amount mismatch: expected ${expectedAmount}, got ${amount}`,
          payment_id: paymentId,
          user_id: userId
        }, 409);
      }

      log(`Updating existing payment: ${paymentId}`);
      await db.updateDocument(DATABASE_ID, PAYMENTS_COLLECTION, paymentId, {
        status: 'approved',
        verified_at: now
      });
    } else {
      log(`Creating new payment for user: ${userId}`);
      paymentId = ID.unique();
      await db.createDocument(DATABASE_ID, PAYMENTS_COLLECTION, paymentId, {
        user_id: userId,
        amount: amount,
        plan: plan,
        status: 'approved',
        transaction_code: transactionCode,
        created_at: now,
        verified_at: now
      });
    }

    // Update User Document
    log(`Fetching current user document for: ${userId}`);
    let userDoc;
    try {
        userDoc = await db.getDocument(DATABASE_ID, USERS_COLLECTION, userId);
    } catch (fetchErr) {
        error(`Failed to fetch user document ${userId}: ${fetchErr.message}`);
        return res.json({ success: false, error: `User not found: ${userId}` }, 404);
    }

    const monthsToAdd = planMonths(plan);
    const rawExpiry = userDoc.premium_expires_at;
    const parsedExpiry = rawExpiry ? new Date(rawExpiry) : null;
    const hasFutureExpiry = parsedExpiry && !Number.isNaN(parsedExpiry.getTime()) && parsedExpiry > new Date();
    
    const baseDate = hasFutureExpiry ? parsedExpiry : new Date();
    const premiumExpiresAt = new Date(baseDate.setMonth(baseDate.getMonth() + monthsToAdd)).toISOString();

    log(`Updating user ${userId}. Adding ${monthsToAdd} months. New expiry: ${premiumExpiresAt}`);
    
    await db.updateDocument(DATABASE_ID, USERS_COLLECTION, userId, {
      is_premium: true,
      premium_expires_at: premiumExpiresAt
    });

    log(`Logging transaction in sms_transactions`);
    await db.createDocument(DATABASE_ID, SMS_TRANSACTIONS_COLLECTION, ID.unique(), {
      device_id: payload.device_id,
      sms_hash: payload.sms_hash,
      sender: payload.sender,
      amount: amount,
      transaction_code: transactionCode,
      matched_payment_id: paymentId,
      matched_user_id: userId,
      status: 'approved',
      processed_at: now,
      hmac_signature: payload.signature,
      nonce: payload.nonce
    });

    log(`✅ Successfully processed payment for ${userId}. Transaction: ${transactionCode}`);
    return res.json({
      success: true,
      payment_id: paymentId,
      user_id: userId,
      plan: plan
    });
  } catch (err) {
    error(`CRITICAL DATABASE ERROR: ${err.message} \nStack: ${err.stack}`);
    return res.json({ success: false, error: err.message }, 500);
  }
};
