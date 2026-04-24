# Amttai

Mongolian premium recipe app built with Flutter + Appwrite.

## Payment Flow (manual transfer)

1. User selects a premium plan.
2. App generates a unique transaction code.
3. User sends bank transfer with the generated code in transfer description.
4. User submits transaction/reference ID in app.
5. Admin verifies payment and approves/rejects from admin console.
6. On approval, premium access is extended in the users collection.

## Push Notification Broadcast

The project includes an Appwrite function `broadcast-push` that uses Appwrite Messaging to queue push notifications to all registered Appwrite push targets.

### Function path

- `appwrite-functions/broadcast-push/src/main.js`

### Required function environment variables

- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_API_KEY`

Optional broadcast behavior variables:

- `APPWRITE_PUSH_PROVIDER_ID` (recommended: your Appwrite FCM provider ID)
- `BROADCAST_USER_PAGE_SIZE` (default: `100`)
- `BROADCAST_TARGET_BATCH_SIZE` (default: `100`)

Optional security variable:

- `BROADCAST_PUSH_SECRET`

If `BROADCAST_PUSH_SECRET` is set, the payload must include `secret`.
For stronger protection, configure it in production so only trusted callers can trigger broadcasts.

### Broadcast payload shape

```json
{
  "title": "Шинэ жор нэмэгдлээ",
  "body": "Өнөөдрийн шинэ жорыг үзээрэй.",
  "data": {
    "screen": "home",
    "source": "admin-broadcast"
  }
}
```

## Flutter run configuration for push

Configure Firebase values with dart defines:

```bash
flutter run \
  --dart-define=PUSH_ENABLED=true \
  --dart-define=FIREBASE_API_KEY="..." \
  --dart-define=FIREBASE_PROJECT_ID="..." \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="..." \
  --dart-define=FIREBASE_ANDROID_APP_ID="..." \
  --dart-define=APPWRITE_PUSH_PROVIDER_ID="..."
```

Optional Appwrite TLS override for local development only:

```bash
--dart-define=APPWRITE_ALLOW_SELF_SIGNED=true
```

Android-only note: this project currently registers Appwrite push targets only on Android.

## Local checks

```bash
flutter pub get
flutter analyze
flutter test
```
