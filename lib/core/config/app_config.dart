/// Appwrite & app-wide configuration constants.
///
/// Replace placeholder values with real credentials once your
/// Appwrite project is provisioned.
class AppConfig {
  AppConfig._();

  // ── Appwrite ──────────────────────────────────────────────
  static const String appwriteEndpoint = 'https://cloud.appwrite.io/v1';
  static const String appwriteProjectId = 'amttai';

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
  static const String socialPayWebhookFunctionId = 'socialpay-webhook';
  static const String socialPayCheckoutFunctionId = String.fromEnvironment(
    'SOCIALPAY_CHECKOUT_FUNCTION_ID',
    defaultValue: 'socialpay-create-checkout',
  );

  // ── Storage Buckets ───────────────────────────────────────
  static const String recipeImagesBucket = 'recipe_images';
  static const String recipeVideosBucket = 'recipe_videos';
  static const String profilePhotosBucket = 'profile_photos';
  static const String paymentScreenshotsBucket = 'payment_screenshots';

  // ── Payment ───────────────────────────────────────────────
  static const String bankName = 'Голомт банк';
  static const String bankAccountNumber = '480015002905262908';
  static const String bankAccountHolder = 'Erdenee Bayarkhuu';
  static const String socialPayDeeplinkTemplate = String.fromEnvironment(
    'SOCIALPAY_DEEPLINK_TEMPLATE',
    defaultValue:
        'socialpay-payment://transfer?to={to}&amount={amount}&description={description}',
  );
  static const String socialPayDescriptionPrefix = String.fromEnvironment(
    'SOCIALPAY_DESCRIPTION_PREFIX',
    defaultValue: 'AMTTAI-',
  );
  static const bool socialPayAllowUnsafeDirectTemplate =
      bool.fromEnvironment(
        'SOCIALPAY_ALLOW_UNSAFE_DIRECT_TEMPLATE',
        defaultValue: false,
      );
  static const int socialPayWatchdogTimeoutSeconds = int.fromEnvironment(
    'SOCIALPAY_WATCHDOG_TIMEOUT_SECONDS',
    defaultValue: 180,
  );
  static const int socialPayWatchdogPollSeconds = int.fromEnvironment(
    'SOCIALPAY_WATCHDOG_POLL_SECONDS',
    defaultValue: 5,
  );

  // ── Premium Plan Prices (MNT) ─────────────────────────────
  static const int plan1MonthPrice = 9000;
  static const int plan3MonthPrice = 21000;
  static const int plan6MonthPrice = 36000;

  // ── App Info ──────────────────────────────────────────────
  static const String appName = 'Амттай';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@amttai.com';
}
