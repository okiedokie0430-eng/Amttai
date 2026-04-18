# socialpay-create-checkout

Appwrite Function that returns a SocialPay deeplink for the Flutter app.

This function supports two modes:

1. Template mode (quick setup): use env templates to return deeplink/qr/key.
2. Provider API mode: call SocialPay merchant API with `X-GOLOMT-CHECKSUM`.

## Request Body

Required fields:
- `amount` (number)
- `transactionCode` (string)

Optional fields:
- `description`
- `userId`
- `userName`
- `plan`
- `language`
- `receiverAccount`
- `deeplink` / `qPay_QRcode` / `key` (direct override)

## Response

```json
{
  "ok": true,
  "deeplink": "socialpay-payment://q?qPay_QRcode=...",
  "qPay_QRcode": "...",
  "key": "...",
  "reference": "SP-...",
  "message": "Checkout payload generated"
}
```

## Environment Variables

Template mode (any one is enough):
- `SOCIALPAY_DEEPLINK_TEMPLATE`
- `SOCIALPAY_QPAY_QRCODE_TEMPLATE`
- `SOCIALPAY_KEY_TEMPLATE`

Provider API mode:
- `SOCIALPAY_API_URL` (example: `https://sp-api.golomtbank.com/api/transaction/deeplink/v1.0?language=mn`)
- `SOCIALPAY_CHECKSUM_SECRET`
- `SOCIALPAY_REQUEST_TEMPLATE_JSON` (JSON object template)

Optional provider headers:
- `SOCIALPAY_X_API_KEY`
- `SOCIALPAY_API_KEY`
- `SOCIALPAY_AUTHORIZATION`

Optional shared values:
- `SOCIALPAY_RECEIVER_ACCOUNT`
- `SOCIALPAY_CALLBACK_URL`
- `SOCIALPAY_LANGUAGE` (default: `mn`)
- `SOCIALPAY_INCLUDE_PROVIDER_RESPONSE` (`true`/`false`)

## Template Placeholders

Supported placeholders in template strings/JSON:
- `{amount}`
- `{amountText}`
- `{description}`
- `{transactionCode}`
- `{userId}`
- `{userName}`
- `{plan}`
- `{receiverAccount}`
- `{callbackUrl}`
- `{language}`
- `{nowIso}`

## Notes

- Recent SocialPay app versions reject unsigned raw transfer links.
- Prefer returning signed provider payload (`deeplink`, `qPay_QRcode`, or `key`).
- If provider returns checksum errors, verify secret and request template fields.
