/// All user-facing strings in English.
///
/// Centralised here so the entire app stays consistent and
/// future localisation is trivial (swap this file).
class S {
  S._();

  // ── General ───────────────────────────────────────────────
  static const String appName = 'Amttai';
  static const String loading = 'Loading...';
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String done = 'Done';
  static const String ok = 'OK';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String close = 'Close';
  static const String next = 'Next';
  static const String back = 'Back';
  static const String seeAll = 'See All';

  // ── Auth ──────────────────────────────────────────────────
  static const String login = 'Login';
  static const String register = 'Register';
  static const String logout = 'Logout';
  static const String email = 'Email';
  static const String phone = 'Phone Number';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String otpTitle = 'Verification Code';
  static const String otpSubtitle = 'Enter the 6-digit code sent to your phone';
  static const String sendCode = 'Send Code';
  static const String verifyCode = 'Verify';
  static const String nameHint = 'Name';
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String dontHaveAccount = 'Don\'t have an account? ';

  // ── Bottom Nav ────────────────────────────────────────────
  static const String navHome = 'Home';
  static const String navSearch = 'Search';
  static const String navCart = 'Cart';
  static const String navFavorites = 'Saved';
  static const String navProfile = 'Profile';

  // ── Grocery Cart ──────────────────────────────────────────
  static const String cartTitle = 'Cart';
  static const String cartEmpty = 'Your cart is empty';
  static const String cartEmptyHint = 'Add recipe ingredients to your cart';
  static const String cartAddAll = 'Add All';
  static const String cartClearAll = 'Clear All';
  static const String cartItemCount = 'items';

  // ── Account / Profile Sections ────────────────────────────
  static const String account = 'Account';
  static const String subscription = 'Subscription';
  static const String freePlan = 'Free';
  static const String appPreferences = 'App Preferences';
  static const String darkMode = 'Dark Mode';
  static const String inviteFriends = 'Invite Friends';
  static const String leaveFeedback = 'Feedback';
  static const String support = 'Help';

  // ── Home ──────────────────────────────────────────────────
  static const String greeting = 'Hello! 👋';
  static const String whatToCook = 'What would you like to cook today?';
  static const String trending = 'Trending';
  static const String categories = 'Categories';
  static const String recommended = 'Recommended';
  static const String newRecipes = 'New Recipes';

  // ── Search ────────────────────────────────────────────────
  static const String searchHint = 'Search recipes...';
  static const String noResults = 'No results found';
  static const String recentSearches = 'Recent Searches';

  // ── Recipe Detail ─────────────────────────────────────────
  static const String ingredients = 'Ingredients';
  static const String steps = 'Steps';
  static const String nutrition = 'Nutrition';
  static const String reviews = 'Reviews';
  static const String servings = 'Servings';
  static const String prepTime = 'Prep Time';
  static const String cookTime = 'Cook Time';
  static const String difficulty = 'Difficulty';
  static const String difficultyEasy = 'Easy';
  static const String difficultyMedium = 'Medium';
  static const String difficultyHard = 'Hard';
  static const String premiumRecipe = 'Premium Recipe';
  static const String watchVideo = 'Watch Video';
  static const String addToFavorites = 'Save';
  static const String removeFromFavorites = 'Remove from Saved';
  static const String writeReview = 'Write a Review';
  static const String minuteShort = 'min';

  // ── Favorites ─────────────────────────────────────────────
  static const String favoritesTitle = 'Saved Recipes';
  static const String favoritesEmpty = 'You have no saved recipes';
  static const String favoritesEmptyHint = 'Tap the heart icon to save your favorite recipes';

  // ── Profile ───────────────────────────────────────────────
  static const String profileTitle = 'Profile';
  static const String editProfile = 'Edit';
  static const String premiumStatus = 'Premium Status';
  static const String activePremium = 'Active';
  static const String expiredPremium = 'Expired';
  static const String noPremium = 'Not Premium';
  static const String totalFavorites = 'Saved';
  static const String memberSince = 'Member Since';
  static const String settings = 'Settings';
  static const String customerService = 'Customer Service';

  // ── Premium / Payment ─────────────────────────────────────
  static const String premiumTitle = 'Premium Access';
  static const String premiumSubtitle =
      'Get unlimited access to all recipes and video tutorials';
  static const String plan1Month = '1 Month';
  static const String plan3Month = '3 Months';
  static const String plan6Month = '6 Months';
  static const String selectPlan = 'Select Plan';
  static const String paymentInstructions = 'Payment Instructions';
  static const String paymentStep1 = '1. Transfer to the account below';
  static const String paymentStep2 = '2. Write your code in the transaction note';
  static const String paymentStep3 = '3. Enter your transaction number';
  static const String transactionCode = 'Transaction Code';
  static const String transactionId = 'Transaction ID';
  static const String transactionIdHint = 'Bank transaction number';
  static const String submitPayment = 'Submit Payment';
  static const String paymentPending = 'Verifying...';
  static const String paymentSuccess = 'Payment Successful!';
  static const String paymentFailed = 'Payment Failed';
  static const String copyCode = 'Copy Code';
  static const String copied = 'Copied!';

  // ── Settings ──────────────────────────────────────────────
  static const String settingsTitle = 'Settings';
  static const String notifications = 'Notifications';
  static const String clearCache = 'Clear Cache';
  static const String about = 'About';
  static const String version = 'Version';
  static const String privacyPolicy = 'Privacy Policy';
  static const String termsOfService = 'Terms of Service';
  static const String deleteAccount = 'Delete Account';
  static const String deleteAccountConfirm =
      'Are you sure you want to delete your account? This action cannot be undone.';

  // ── Support / Chat ────────────────────────────────────────
  static const String supportTitle = 'Customer Support';
  static const String supportHint = 'Type a message...';
  static const String supportWelcome =
      'Hello! How can I help you today?';

  // ── Errors ────────────────────────────────────────────────
  static const String networkError = 'No internet connection';
  static const String unknownError = 'An error occurred, please try again';
  static const String authError = 'Invalid login credentials';
  static const String requiredField = 'This field is required';
  static const String invalidEmail = 'Invalid email';
  static const String passwordTooShort = 'Password must be at least 8 characters';
  static const String passwordMismatch = 'Passwords do not match';
}
