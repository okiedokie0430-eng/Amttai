import 'package:shared_preferences/shared_preferences.dart';

class AffinityTracker {
  static const String _key = 'user_affinity_scores';

  /// Call this whenever a user opens a recipe to build their taste profile.
  static Future<void> registerCategoryInteraction(String category) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Format: "category1:score,category2:score"
    final currentStr = prefs.getString(_key) ?? '';
    final scores = <String, int>{};
    
    if (currentStr.isNotEmpty) {
      for (final pair in currentStr.split(',')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          scores[parts[0]] = int.tryParse(parts[1]) ?? 0;
        }
      }
    }

    scores[category] = (scores[category] ?? 0) + 1;

    final newStr = scores.entries.map((e) => '${e.key}:${e.value}').join(',');
    await prefs.setString(_key, newStr);
  }

  /// Extracts the highest scoring category for the backend payload.
  static Future<String> getTopCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final currentStr = prefs.getString(_key) ?? '';
    
    if (currentStr.isEmpty) return 'traditional'; // Default fallback
    
    String topCategory = 'traditional';
    int maxScore = -1;

    for (final pair in currentStr.split(',')) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final score = int.tryParse(parts[1]) ?? 0;
        if (score > maxScore) {
          maxScore = score;
          topCategory = parts[0];
        }
      }
    }
    return topCategory;
  }
}
