# socialpay-webhook

Appwrite Function that receives SocialPay callback payloads and updates payment status.

## Behavior

- Finds payment by `transaction_code`
- Maps callback status to one of:
  - `approved`
  - `rejected`
  - `pending`
- Writes `transaction_id` + `verified_at`
- If approved, updates user premium expiry in `users` collection

## Required Environment Variables

- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_API_KEY`
- `DATABASE_ID` (default: `amttai_db`)
- `PAYMENTS_COLLECTION` (default: `payments`)
- `USERS_COLLECTION` (default: `users`)

## Optional Security

- `SOCIALPAY_WEBHOOK_SECRET`

If provided, request must include this value in one header:
- `x-socialpay-signature`
- `x-signature`
- `authorization` (`Bearer <secret>` is accepted)

## Payload Mapping

Transaction code is read from one of these fields (first non-empty wins):

- `transaction_code`
- `transactionCode`
- `tx_code`
- `txCode`
- `reference`
- `referenceCode`
- `order_id`
- `orderId`

If not found, parser attempts regex extraction from `description`/`note`.
