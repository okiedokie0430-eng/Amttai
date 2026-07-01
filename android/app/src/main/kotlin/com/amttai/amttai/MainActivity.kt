package com.amttai.amttai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.amttai.amttai.recommendation.PreferenceLearningEngine
import com.amttai.amttai.recommendation.Recipe
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.amttai.amttai/recommendation"
    private var engine: PreferenceLearningEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initEngine" -> {
                    val userId = call.argument<String>("userId") ?: "anonymous"
                    engine = PreferenceLearningEngine(context, userId)
                    result.success(true)
                }
                "onRecipeViewed" -> {
                    val tags = call.argument<List<String>>("tags") ?: emptyList()
                    CoroutineScope(Dispatchers.Main).launch {
                        engine?.onRecipeViewed(tags)
                        result.success(true)
                    }
                }
                "onRecipeCooked" -> {
                    val tags = call.argument<List<String>>("tags") ?: emptyList()
                    CoroutineScope(Dispatchers.Main).launch {
                        engine?.onRecipeCooked(tags)
                        result.success(true)
                    }
                }
                "onRecipeBookmarked" -> {
                    val tags = call.argument<List<String>>("tags") ?: emptyList()
                    CoroutineScope(Dispatchers.Main).launch {
                        engine?.onRecipeBookmarked(tags)
                        result.success(true)
                    }
                }
                "rankRecipes" -> {
                    val rawRecipes = call.argument<List<Map<String, Any>>>("recipes") ?: emptyList()
                    val recipes = rawRecipes.map {
                        Recipe(
                            id = it["id"] as? String ?: "",
                            title = it["title"] as? String ?: "",
                            tags = (it["tags"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                        )
                    }
                    CoroutineScope(Dispatchers.Main).launch {
                        if (engine != null) {
                            val ranked = engine!!.rankRecipes(recipes)
                            val rankedIds = ranked.map { it.id }
                            result.success(rankedIds)
                        } else {
                            // If engine not init, just return original order
                            result.success(rawRecipes.map { it["id"] })
                        }
                    }
                }
                "applyDecay" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        engine?.applyTimeDecay()
                        result.success(true)
                    }
                }
                "openOfflineSettings" -> {
                    val intent = android.content.Intent(context, com.amttai.amttai.sync.SettingsSyncActivity::class.java)
                    startActivity(intent)
                    result.success(true)
                }
                "setGestureExclusion" -> {
                    val widthDp = call.argument<Int>("widthDp") ?: 30
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                        val metrics = resources.displayMetrics
                        val widthPx = (widthDp * metrics.density).toInt()
                        val heightPx = metrics.heightPixels
                        val rect = android.graphics.Rect(0, 0, widthPx, heightPx)
                        window.setSystemGestureExclusionRects(listOf(rect))
                    }
                    result.success(true)
                }
                "clearGestureExclusion" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                        window.setSystemGestureExclusionRects(emptyList())
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
