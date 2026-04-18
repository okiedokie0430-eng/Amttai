# Amttai

Mongolian premium recipe app built with Flutter + Appwrite.

## SocialPay Flow (implemented)

1. User selects plan and payment method: Bank transfer or SocialPay.
2. For SocialPay:
	 - App creates a pending payment document in Appwrite.
	 - App generates a unique transaction code.
	 - App calls Appwrite Function `socialpay-create-checkout`.
	 - Function returns provider-signed payload (`deeplink`, `qPay_QRcode`, or `key`).
	 - App opens SocialPay app using `socialpay-payment://...` deeplink.
3. App starts watchdog polling to check payment status updates.
4. Appwrite webhook function updates payment status when callback arrives.
5. On approved status, user premium is auto-extended in users collection.

## Flutter Run Config

You can configure SocialPay checkout function and watchdog without changing code:

```bash
flutter run \
	--dart-define=SOCIALPAY_CHECKOUT_FUNCTION_ID="socialpay-create-checkout" \
	--dart-define=SOCIALPAY_DESCRIPTION_PREFIX="AMTTAI-" \
	--dart-define=SOCIALPAY_WATCHDOG_TIMEOUT_SECONDS=180 \
	--dart-define=SOCIALPAY_WATCHDOG_POLL_SECONDS=5 \
	--dart-define=SOCIALPAY_ALLOW_UNSAFE_DIRECT_TEMPLATE=false
```

Optional unsafe fallback (not recommended, many SocialPay versions reject it):

```bash
--dart-define=SOCIALPAY_ALLOW_UNSAFE_DIRECT_TEMPLATE=true \
--dart-define=SOCIALPAY_DEEPLINK_TEMPLATE="socialpay-payment://transfer?to={to}&amount={amount}&description={description}"
```

Fallback template placeholders:

- `{to}` receiver account
- `{amount}` amount in MNT
- `{description}` transaction description
- `{txCode}` generated transaction code

## Appwrite Requirements

### Collections

- `payments`: needs at least
	- `user_id` (string)
	- `plan` (string)
	- `amount` (integer)
	- `transaction_code` (string)
	- `transaction_id` (string)
	- `status` (string: pending/approved/rejected)
	- `created_at` (datetime/string)
	- `verified_at` (datetime/string, optional)
- `users`: needs at least
	- `is_premium` (boolean)
	- `premium_expires_at` (datetime/string, optional)

### Function: socialpay-webhook

Path: `appwrite-functions/socialpay-webhook/src/main.js`

Expected env vars:

- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_API_KEY`
- `DATABASE_ID` (default: `amttai_db`)
- `PAYMENTS_COLLECTION` (default: `payments`)
- `USERS_COLLECTION` (default: `users`)
- `SOCIALPAY_WEBHOOK_SECRET` (optional but recommended)

Security note:

- Configure SocialPay to send a shared secret in one of these headers:
	- `x-socialpay-signature`
	- `x-signature`
	- `authorization`

### Function: socialpay-create-checkout

Path: `appwrite-functions/socialpay-create-checkout/src/main.js`

This function must return one of:

- `deeplink`
- `qPay_QRcode`
- `key`

See detailed setup in:

- `appwrite-functions/socialpay-create-checkout/README.md`

Important notes:

- Public SocialPay app builds validate payload/checksum and reject unsigned raw transfer links.
- If you receive `Invalid checksum`, verify merchant secret and provider request template.

## Local Checks

```bash
flutter pub get
flutter analyze
flutter test
```
