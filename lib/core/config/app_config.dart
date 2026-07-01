/// Appwrite & app-wide configuration constants.
///
/// Replace placeholder values with real credentials once your
/// Appwrite project is provisioned.
class AppConfig {
  AppConfig._();

  // ── Appwrite ──────────────────────────────────────────────
  static const String appwriteEndpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://fra.cloud.appwrite.io/v1',
  );
  static const String appwriteProjectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: 'amttai',
  );
  static const String appwritePushProviderId = String.fromEnvironment(
    'APPWRITE_PUSH_PROVIDER_ID',
    defaultValue: '',
  );

  // ── Database ──────────────────────────────────────────────
  static const String databaseId = 'amttai_db';

  // Collections
  static const String recipesCollection = 'recipes';
  static const String usersCollection = 'users';
  static const String ratingsCollection = 'ratings';
  static const String paymentsCollection = 'payments';
  static const String supportMessagesCollection = 'support_messages';

  // ── Functions ─────────────────────────────────────────────
  static const String deleteAccountFunctionId = 'delete-account';
  static const String broadcastPushFunctionId = 'broadcast-push';

  // ── Storage Buckets ───────────────────────────────────────
  static const String recipeImagesBucket = 'recipe_images';
  static const String recipeVideosBucket = 'recipe_videos';
  static const String profilePhotosBucket = 'profile_photos';
  static const String paymentScreenshotsBucket = 'payment_screenshots';

  // ── Payment ───────────────────────────────────────────────
  static const String bankName = 'Golomt Bank';
  static const String bankAccountNumber = '480015002905262908';
  static const String bankAccountHolder = 'Erdenee Bayarkhuu';
  static const String socialPayDeeplinkTemplate =
      'socialpay-payment://transfer?to={to}&amount={amount}&description={description}&txCode={txCode}';

  // ── Firebase Push (FCM) ──────────────────────────────────
  static const bool pushEnabled = bool.fromEnvironment(
    'PUSH_ENABLED',
    defaultValue: true,
  );
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '',
  );
  static const String firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '',
  );

  static bool get hasFirebaseAndroidConfig {
    return firebaseApiKey.isNotEmpty &&
        firebaseProjectId.isNotEmpty &&
        firebaseMessagingSenderId.isNotEmpty &&
        firebaseAndroidAppId.isNotEmpty;
  }

  static String? get appwritePushProviderIdOrNull {
    final normalized = appwritePushProviderId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static bool get hasFirebaseIosConfig {
    return firebaseApiKey.isNotEmpty &&
        firebaseProjectId.isNotEmpty &&
        firebaseMessagingSenderId.isNotEmpty &&
        firebaseIosAppId.isNotEmpty;
  }

  // ── Premium Plan Prices (MNT) ─────────────────────────────
  static const int plan1MonthPrice = 9000;
  static const int plan3MonthPrice = 21000;
  static const int plan6MonthPrice = 36000;

  // ── App Info ──────────────────────────────────────────────
  static const String appName = 'Amttai';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@amttai.com';
}
