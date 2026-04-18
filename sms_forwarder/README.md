# sms_forwarder

Android Flutter app that listens for incoming payment SMS and forwards status
to your Appwrite payment webhook.

## What it does

- Requests SMS permissions (`RECEIVE_SMS`, `READ_SMS`)
- Listens for incoming SMS in foreground and background
- Filters by sender allow-list
- Classifies SMS as `approved` / `rejected` using keyword matching
- Extracts transaction code (default regex supports `SP-...` and `AMTTAI-...`)
- Sends JSON payload to your webhook endpoint
- Keeps recent local logs in app UI

## Important note

This app can only auto-confirm payments when the SMS contains a recognizable
transaction code that matches your payment record.

## Run

```bash
cd sms_forwarder
flutter pub get
flutter run -d <android-device-id> \
	--dart-define=FORWARDER_ENDPOINT="https://fra.cloud.appwrite.io/v1/functions/socialpay-webhook/executions" \
	--dart-define=FORWARDER_WEBHOOK_SECRET="<same-secret-as-webhook>" \
	--dart-define=FORWARDER_APPWRITE_PROJECT_ID="amttai" \
	--dart-define=FORWARDER_ALLOWED_SENDERS="GOLOMT,SocialPay,151515" \
	--dart-define=FORWARDER_SUCCESS_KEYWORDS="success,successful,approved,completed,paid,amjilttai" \
	--dart-define=FORWARDER_FAILURE_KEYWORDS="failed,rejected,declined,cancelled,canceled,tatgalzsan"
```

## Appwrite webhook alignment

This forwarder sends fields compatible with your webhook parser:

- `status` (`approved`/`rejected`)
- `transaction_code`
- `reference`
- `transaction_id`
- `sender`
- `message`
- `received_at`

Your existing `socialpay-webhook` function can then:

1. find payment by transaction code
2. update payment status
3. activate premium on success

## Key dart defines

- `FORWARDER_ENDPOINT`: required webhook URL
- `FORWARDER_WEBHOOK_SECRET`: optional secret header value
- `FORWARDER_APPWRITE_PROJECT_ID`: optional Appwrite project header
- `FORWARDER_X_API_KEY`: optional api key header
- `FORWARDER_AUTHORIZATION`: optional bearer token
- `FORWARDER_ALLOWED_SENDERS`: CSV allow-list (empty means allow all)
- `FORWARDER_SUCCESS_KEYWORDS`: CSV success keywords
- `FORWARDER_FAILURE_KEYWORDS`: CSV failure keywords
- `FORWARDER_TX_CODE_REGEX`: regex with transaction code capture
- `FORWARDER_ALLOW_NO_TX_CODE`: allow forwarding when tx code missing
- `FORWARDER_FORWARD_UNCLASSIFIED`: forward unknown status as pending
- `FORWARDER_REQUEST_TIMEOUT_SECONDS`: HTTP timeout

## Recommended production behavior

- Keep sender allow-list strict (only your bank/SocialPay SMS sender IDs)
- Keep transaction regex strict
- Keep `FORWARDER_ALLOW_NO_TX_CODE=false`
- Keep webhook secret enabled
