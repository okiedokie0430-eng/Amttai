package com.amttai.amttai.recommendation

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

data class Recipe(
    val id: String,
    val title: String,
    val tags: List<String>
)

data class UserPreferenceProfile(
    val userId: String,
    val tagWeights: ConcurrentHashMap<String, Double> = ConcurrentHashMap(),
    var lastDecayTimestamp: Long = System.currentTimeMillis()
)

/**
 * Intelligent Home Screen Recommendation Algorithm.
 * Tracks user behavior (views, cooks, bookmarks) and decays weights over time.
 * Calculates dynamic scoring offline natively to prevent frame drops in UI.
 */
class PreferenceLearningEngine(context: Context, private val userId: String) {

    private val prefs: SharedPreferences = context.getSharedPreferences("prefs_reco_$userId", Context.MODE_PRIVATE)
    
    // In-memory thread-safe cache
    private val profile: UserPreferenceProfile = loadProfile()

    private fun loadProfile(): UserPreferenceProfile {
        val jsonString = prefs.getString("profile_data", null)
        val weights = ConcurrentHashMap<String, Double>()
        var lastDecay = System.currentTimeMillis()

        if (jsonString != null) {
            try {
                val json = JSONObject(jsonString)
                lastDecay = json.optLong("lastDecayTimestamp", System.currentTimeMillis())
                val weightsJson = json.optJSONObject("tagWeights")
                if (weightsJson != null) {
                    weightsJson.keys().forEach { key ->
                        weights[key] = weightsJson.getDouble(key)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return UserPreferenceProfile(userId, weights, lastDecay)
    }

    private fun saveProfile() {
        val json = JSONObject().apply {
            put("userId", userId)
            put("lastDecayTimestamp", profile.lastDecayTimestamp)
            val weightsJson = JSONObject()
            // ConcurrentHashMap allows safe iteration
            profile.tagWeights.forEach { (k, v) -> weightsJson.put(k, v) }
            put("tagWeights", weightsJson)
        }
        prefs.edit().putString("profile_data", json.toString()).apply()
    }

    suspend fun onRecipeViewed(recipeTags: List<String>) = updateWeights(recipeTags, 0.1)
    
    suspend fun onRecipeCooked(recipeTags: List<String>) = updateWeights(recipeTags, 0.5)
    
    suspend fun onRecipeBookmarked(recipeTags: List<String>) = updateWeights(recipeTags, 0.8)

    /**
     * Updates the weights of specific tags asynchronously.
     */
    private suspend fun updateWeights(tags: List<String>, weightIncrease: Double) = withContext(Dispatchers.IO) {
        tags.forEach { tag ->
            val currentWeight = profile.tagWeights[tag] ?: 0.0
            profile.tagWeights[tag] = currentWeight + weightIncrease
        }
        saveProfile()
    }

    /**
     * Applies a 10% decay to all tag weights for every week that has elapsed.
     * Drops tags with a weight < 0.01 to keep the profile lean.
     */
    suspend fun applyTimeDecay() = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        val oneWeekMs = 7L * 24 * 60 * 60 * 1000 // 1 week in milliseconds
        
        val weeksElapsed = (now - profile.lastDecayTimestamp) / oneWeekMs
        
        if (weeksElapsed > 0) {
            val keys = profile.tagWeights.keys().toList()
            for (key in keys) {
                var currentWeight = profile.tagWeights[key] ?: 0.0
                
                // Apply 10% decay sequentially for each week elapsed
                for (i in 0 until weeksElapsed) {
                    currentWeight *= 0.9
                }
                
                if (currentWeight < 0.01) {
                    profile.tagWeights.remove(key)
                } else {
                    profile.tagWeights[key] = currentWeight
                }
            }
            // Advance timestamp relative to elapsed weeks to prevent drift
            profile.lastDecayTimestamp += (weeksElapsed * oneWeekMs)
            saveProfile()
        }
    }

    /**
     * Dynamic Ranking Matrix.
     * Computes vector dot-product for the recipe base asynchronously.
     */
    suspend fun rankRecipes(allRecipes: List<Recipe>): List<Recipe> = withContext(Dispatchers.Default) {
        // Snapshot the current weights to prevent race conditions during calculation
        val currentWeights = profile.tagWeights.toMap()
        
        allRecipes.map { recipe ->
            var score = 0.0
            recipe.tags.forEach { tag ->
                score += (currentWeights[tag] ?: 0.0)
            }
            Pair(recipe, score)
        }
        .sortedByDescending { it.second }
        .map { it.first }
    }
    
    /**
     * Exports raw JSON string of tag weights for Cloud Sync.
     */
    fun getRawWeightsJson(): String {
        val weightsJson = JSONObject()
        profile.tagWeights.forEach { (k, v) -> weightsJson.put(k, v) }
        return weightsJson.toString()
    }
}
