import crypto from 'node:crypto';

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
    if (typeof value === 'number' && Number.isFinite(value)) {
      return String(value);
    }
  }
  return '';
}

function pickNumber(...values) {
  for (const value of values) {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === 'string' && value.trim()) {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return NaN;
}

function applyTemplate(value, variables) {
  if (Array.isArray(value)) {
    return value.map((item) => applyTemplate(item, variables));
  }

  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, applyTemplate(v, variables)]),
    );
  }

  if (typeof value !== 'string') return value;

  const exactMatch = value.match(/^\{([a-zA-Z0-9_]+)\}$/);
  if (exactMatch) {
    const key = exactMatch[1];
    return variables[key] ?? '';
  }

  return value.replace(/\{([a-zA-Z0-9_]+)\}/g, (_, key) => {
    const replacement = variables[key];
    return replacement == null ? '' : String(replacement);
  });
}

function createChecksum(bodyText, secret) {
  return crypto.createHmac('sha256', secret).update(bodyText).digest('hex');
}

function parseJsonSafely(raw) {
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function resolveCheckoutPayload(source) {
  const candidates = [
    source,
    source?.data,
    source?.result,
    source?.payload,
    source?.response,
  ].filter(Boolean);

  const pickFromCandidates = (fieldNames) => {
    for (const candidate of candidates) {
      const value = fieldNames
        .map((field) => candidate?.[field])
        .find((fieldValue) => pickString(fieldValue));
      const text = pickString(value);
      if (text) return text;
    }
    return '';
  };

  return {
    deeplink: pickFromCandidates([
      'deeplink',
      'deepLink',
      'checkoutUrl',
      'checkout_url',
      'paymentUrl',
      'payment_url',
      'url',
    ]),
    qPayQrCode: pickFromCandidates([
      'qPay_QRcode',
      'qpay_qrcode',
      'qPayQrCode',
      'qr',
      'qrPayload',
    ]),
    key: pickFromCandidates(['key', 'encryptedKey', 'payloadKey']),
    reference: pickFromCandidates([
      'reference',
      'providerReference',
      'paymentId',
      'transactionId',
      'traceNo',
    ]),
    message: pickFromCandidates(['message', 'msg', 'description']),
  };
}

function buildDeepLinkFromPayload(payload) {
  const deeplink = pickString(payload.deeplink);
  if (deeplink) return deeplink;

  const qrPayload = pickString(payload.qPayQrCode, payload.qPay_QRcode, payload.qr);
  if (qrPayload) {
    return `socialpay-payment://q?qPay_QRcode=${encodeURIComponent(qrPayload)}`;
  }

  const keyPayload = pickString(payload.key, payload.encryptedKey);
  if (keyPayload) {
    return `socialpay-payment://key=${encodeURIComponent(keyPayload)}`;
  }

  return '';
}

function buildVariables(body) {
  const amount = Math.round(
    pickNumber(body.amount, body.amountMnt, body.totalAmount),
  );
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error('amount is required and must be greater than 0');
  }

  const transactionCode = pickString(
    body.transactionCode,
    body.transaction_code,
    body.txCode,
    body.reference,
  );
  if (!transactionCode) {
    throw new Error('transactionCode is required');
  }

  const description = pickString(body.description, body.note, transactionCode);

  return {
    amount,
    amountText: String(amount),
    description,
    transactionCode,
    userId: pickString(body.userId, body.user_id),
    userName: pickString(body.userName, body.user_name),
    plan: pickString(body.plan),
    receiverAccount: pickString(
      body.receiverAccount,
      process.env.SOCIALPAY_RECEIVER_ACCOUNT,
    ),
    callbackUrl: pickString(process.env.SOCIALPAY_CALLBACK_URL),
    language: pickString(body.language, process.env.SOCIALPAY_LANGUAGE, 'mn'),
    nowIso: new Date().toISOString(),
  };
}

function resolveTemplatePayload(body, variables) {
  const deeplinkTemplate = pickString(process.env.SOCIALPAY_DEEPLINK_TEMPLATE);
  if (deeplinkTemplate) {
    const deeplink = applyTemplate(deeplinkTemplate, variables);
    return {
      deeplink: pickString(deeplink),
      reference: variables.transactionCode,
      message: 'Resolved from SOCIALPAY_DEEPLINK_TEMPLATE',
    };
  }

  const qrTemplate = pickString(process.env.SOCIALPAY_QPAY_QRCODE_TEMPLATE);
  if (qrTemplate) {
    const qPayQrCode = applyTemplate(qrTemplate, variables);
    return {
      qPayQrCode: pickString(qPayQrCode),
      reference: variables.transactionCode,
      message: 'Resolved from SOCIALPAY_QPAY_QRCODE_TEMPLATE',
    };
  }

  const keyTemplate = pickString(process.env.SOCIALPAY_KEY_TEMPLATE);
  if (keyTemplate) {
    const key = applyTemplate(keyTemplate, variables);
    return {
      key: pickString(key),
      reference: variables.transactionCode,
      message: 'Resolved from SOCIALPAY_KEY_TEMPLATE',
    };
  }

  const direct = {
    deeplink: pickString(body.deeplink, body.deepLink),
    qPayQrCode: pickString(body.qPay_QRcode, body.qPayQrCode, body.qr),
    key: pickString(body.key, body.encryptedKey),
    reference: pickString(body.reference, body.providerReference),
  };

  if (direct.deeplink || direct.qPayQrCode || direct.key) {
    return {
      ...direct,
      message: 'Resolved from request body',
    };
  }

  return null;
}

async function requestProviderCheckout(variables) {
  const apiUrl = pickString(process.env.SOCIALPAY_API_URL);
  if (!apiUrl) {
    throw new Error(
      'SOCIALPAY_API_URL is missing. Set template envs or configure provider API access.',
    );
  }

  const checksumSecret = pickString(process.env.SOCIALPAY_CHECKSUM_SECRET);
  if (!checksumSecret) {
    throw new Error('SOCIALPAY_CHECKSUM_SECRET is missing');
  }

  const templateRaw = pickString(process.env.SOCIALPAY_REQUEST_TEMPLATE_JSON);
  const requestTemplate = templateRaw
    ? parseJsonSafely(templateRaw)
    : {
        amount: '{amount}',
        description: '{description}',
        transactionCode: '{transactionCode}',
        orderId: '{transactionCode}',
        receiverAccount: '{receiverAccount}',
        callbackUrl: '{callbackUrl}',
      };

  if (!requestTemplate || typeof requestTemplate !== 'object') {
    throw new Error('SOCIALPAY_REQUEST_TEMPLATE_JSON is invalid JSON object');
  }

  const requestBodyObject = applyTemplate(requestTemplate, variables);
  const requestBody = JSON.stringify(requestBodyObject);
  const checksum = createChecksum(requestBody, checksumSecret);

  const headers = {
    'Content-Type': 'application/json',
    'X-GOLOMT-CHECKSUM': checksum,
  };

  const apiKey = pickString(process.env.SOCIALPAY_X_API_KEY, process.env.SOCIALPAY_API_KEY);
  if (apiKey) {
    headers['x-api-key'] = apiKey;
  }

  const authorization = pickString(process.env.SOCIALPAY_AUTHORIZATION);
  if (authorization) {
    headers.Authorization = authorization.startsWith('Bearer ')
      ? authorization
      : `Bearer ${authorization}`;
  }

  const response = await fetch(apiUrl, {
    method: 'POST',
    headers,
    body: requestBody,
  });

  const responseText = await response.text();
  const responseJson = parseJsonSafely(responseText);

  if (!response.ok) {
    const providerMessage =
      pickString(responseJson?.message, responseJson?.error, response.statusText) ||
      'Provider request failed';
    throw new Error(`SocialPay provider error ${response.status}: ${providerMessage}`);
  }

  const payload = resolveCheckoutPayload(responseJson || {});
  if (!payload.deeplink && !payload.qPayQrCode && !payload.key) {
    throw new Error('Provider response has no deeplink/qPay_QRcode/key fields');
  }

  return {
    ...payload,
    providerResponse: responseJson || responseText,
  };
}

export default async ({ req, res, log, error }) => {
  const body = parseJsonBody(req.body);
  if (body === null) {
    return res.json({ ok: false, message: 'Invalid JSON body' }, 400);
  }

  try {
    const variables = buildVariables(body);

    const templatedPayload = resolveTemplatePayload(body, variables);
    const providerPayload = templatedPayload || (await requestProviderCheckout(variables));

    const deeplink = buildDeepLinkFromPayload(providerPayload);
    if (!deeplink) {
      throw new Error('Unable to build SocialPay deeplink from resolved payload');
    }

    const includeProviderResponse =
      pickString(process.env.SOCIALPAY_INCLUDE_PROVIDER_RESPONSE).toLowerCase() === 'true';

    return res.json(
      {
        ok: true,
        deeplink,
        qPay_QRcode: pickString(providerPayload.qPayQrCode),
        key: pickString(providerPayload.key),
        reference: pickString(providerPayload.reference, variables.transactionCode),
        message: pickString(providerPayload.message, 'Checkout payload generated'),
        ...(includeProviderResponse
          ? { providerResponse: providerPayload.providerResponse ?? null }
          : {}),
      },
      200,
    );
  } catch (e) {
    error(`socialpay-create-checkout error: ${e.message}`);
    return res.json({ ok: false, message: e.message }, 500);
  }
};
