/// All user-facing strings in Mongolian.
///
/// Centralised here so the entire app stays consistent and
/// future localisation is trivial (swap this file).
class S {
  S._();

  // ── General ───────────────────────────────────────────────
  static const String appName = 'Амттай';
  static const String loading = 'Уншиж байна...';
  static const String retry = 'Дахин оролдох';
  static const String cancel = 'Цуцлах';
  static const String save = 'Хадгалах';
  static const String done = 'Болсон';
  static const String ok = 'За';
  static const String yes = 'Тийм';
  static const String no = 'Үгүй';
  static const String error = 'Алдаа';
  static const String success = 'Амжилттай';
  static const String close = 'Хаах';
  static const String next = 'Дараах';
  static const String back = 'Буцах';
  static const String seeAll = 'Бүгдийг харах';

  // ── Auth ──────────────────────────────────────────────────
  static const String login = 'Нэвтрэх';
  static const String register = 'Бүртгүүлэх';
  static const String logout = 'Гарах';
  static const String email = 'И-мэйл';
  static const String phone = 'Утасны дугаар';
  static const String password = 'Нууц үг';
  static const String confirmPassword = 'Нууц үг давтах';
  static const String forgotPassword = 'Нууц үгээ мартсан?';
  static const String otpTitle = 'Баталгаажуулах код';
  static const String otpSubtitle = 'Таны утсанд илгээсэн 6 оронтой кодыг оруулна уу';
  static const String sendCode = 'Код илгээх';
  static const String verifyCode = 'Баталгаажуулах';
  static const String nameHint = 'Нэр';
  static const String alreadyHaveAccount = 'Бүртгэлтэй юу? ';
  static const String dontHaveAccount = 'Бүртгэл байхгүй юу? ';

  // ── Bottom Nav ────────────────────────────────────────────
  static const String navHome = 'Нүүр';
  static const String navSearch = 'Хайх';
  static const String navCart = 'Сагс';
  static const String navFavorites = 'Хадгалсан';
  static const String navProfile = 'Профайл';

  // ── Grocery Cart ──────────────────────────────────────────
  static const String cartTitle = 'Сагс';
  static const String cartEmpty = 'Сагс хоосон байна';
  static const String cartEmptyHint = 'Жорын орцнуудыг сагсанд нэмээрэй';
  static const String cartAddAll = 'Бүгдийг нэмэх';
  static const String cartClearAll = 'Бүгдийг устгах';
  static const String cartItemCount = 'зүйл';

  // ── Account / Profile Sections ────────────────────────────
  static const String account = 'Бүртгэл';
  static const String subscription = 'Эрх';
  static const String freePlan = 'Үнэгүй';
  static const String appPreferences = 'Апп тохиргоо';
  static const String darkMode = 'Харанхуй горим';
  static const String inviteFriends = 'Найзуудаа урих';
  static const String leaveFeedback = 'Санал хүсэлт';
  static const String support = 'Тусламж';

  // ── Home ──────────────────────────────────────────────────
  static const String greeting = 'Сайн байна уу! 👋';
  static const String whatToCook = 'Өнөөдөр юу хоолой вэ?';
  static const String trending = 'Трэнд';
  static const String categories = 'Ангилал';
  static const String recommended = 'Санал болгох';
  static const String newRecipes = 'Шинэ жорууд';

  // ── Search ────────────────────────────────────────────────
  static const String searchHint = 'Жор хайх...';
  static const String noResults = 'Илэрц олдсонгүй';
  static const String recentSearches = 'Сүүлд хайсан';

  // ── Recipe Detail ─────────────────────────────────────────
  static const String ingredients = 'Орц';
  static const String steps = 'Алхам';
  static const String nutrition = 'Тэжээллэг чанар';
  static const String reviews = 'Сэтгэгдэл';
  static const String servings = 'Хүний тоо';
  static const String prepTime = 'Бэлтгэх';
  static const String cookTime = 'Болгох';
  static const String difficulty = 'Түвшин';
  static const String difficultyEasy = 'Амархан';
  static const String difficultyMedium = 'Дунд';
  static const String difficultyHard = 'Хэцүү';
  static const String premiumRecipe = 'Премиум жор';
  static const String watchVideo = 'Видео үзэх';
  static const String addToFavorites = 'Хадгалах';
  static const String removeFromFavorites = 'Хадгалсанаас хасах';
  static const String writeReview = 'Сэтгэгдэл бичих';
  static const String minuteShort = 'мин';

  // ── Favorites ─────────────────────────────────────────────
  static const String favoritesTitle = 'Хадгалсан жорууд';
  static const String favoritesEmpty = 'Танд хадгалсан жор байхгүй байна';
  static const String favoritesEmptyHint = 'Дуртай жоруудаа зүрхэн дүрс дээр дарж хадгалаарай';

  // ── Profile ───────────────────────────────────────────────
  static const String profileTitle = 'Профайл';
  static const String editProfile = 'Засах';
  static const String premiumStatus = 'Премиум статус';
  static const String activePremium = 'Идэвхтэй';
  static const String expiredPremium = 'Дууссан';
  static const String noPremium = 'Премиум биш';
  static const String totalFavorites = 'Хадгалсан';
  static const String memberSince = 'Бүртгүүлсэн';
  static const String settings = 'Тохиргоо';
  static const String customerService = 'Хэрэглэгчийн үйлчилгээ';

  // ── Premium / Payment ─────────────────────────────────────
  static const String premiumTitle = 'Премиум эрх';
  static const String premiumSubtitle =
      'Бүх жор, видео хичээлүүдэд хязгааргүй хандаарай';
  static const String plan1Month = '1 Сар';
  static const String plan3Month = '3 Сар';
  static const String plan6Month = '6 Сар';
  static const String selectPlan = 'Багц сонгох';
  static const String paymentInstructions = 'Төлбөрийн заавар';
  static const String paymentStep1 = '1. Доорх дансанд шилжүүлэг хийнэ үү';
  static const String paymentStep2 = '2. Гүйлгээний утга дээр кодоо бичнэ үү';
  static const String paymentStep3 = '3. Гүйлгээний дугаараа оруулна уу';
  static const String transactionCode = 'Гүйлгээний код';
  static const String transactionId = 'Гүйлгээний дугаар';
  static const String transactionIdHint = 'Банкны гүйлгээний дугаар';
  static const String submitPayment = 'Төлбөр илгээх';
  static const String paymentPending = 'Баталгаажуулж байна...';
  static const String paymentSuccess = 'Төлбөр амжилттай!';
  static const String paymentFailed = 'Төлбөр амжилтгүй';
  static const String copyCode = 'Код хуулах';
  static const String copied = 'Хуулагдсан!';

  // ── Settings ──────────────────────────────────────────────
  static const String settingsTitle = 'Тохиргоо';
  static const String notifications = 'Мэдэгдэл';
  static const String clearCache = 'Кэш цэвэрлэх';
  static const String about = 'Тухай';
  static const String version = 'Хувилбар';
  static const String privacyPolicy = 'Нууцлалын бодлого';
  static const String termsOfService = 'Үйлчилгээний нөхцөл';
  static const String deleteAccount = 'Бүртгэл устгах';
  static const String deleteAccountConfirm =
      'Бүртгэлээ устгахдаа итгэлтэй байна уу? Энэ үйлдлийг буцаах боломжгүй.';

  // ── Support / Chat ────────────────────────────────────────
  static const String supportTitle = 'Хэрэглэгчийн үйлчилгээ';
  static const String supportHint = 'Мессеж бичих...';
  static const String supportWelcome =
      'Сайн байна уу! Танд юугаар туслах вэ?';

  // ── Errors ────────────────────────────────────────────────
  static const String networkError = 'Интернэт холболт байхгүй байна';
  static const String unknownError = 'Алдаа гарлаа, дахин оролдоно уу';
  static const String authError = 'Нэвтрэх мэдээлэл буруу байна';
  static const String requiredField = 'Энэ талбарыг бөглөнө үү';
  static const String invalidEmail = 'И-мэйл буруу байна';
  static const String passwordTooShort = 'Нууц үг хамгийн багадаа 8 тэмдэгт';
  static const String passwordMismatch = 'Нууц үг таарахгүй байна';
}
