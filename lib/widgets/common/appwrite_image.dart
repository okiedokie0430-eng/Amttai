import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/io_client.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class AmttaiCacheManager extends CacheManager {
  static const key = 'amttai_cache_v3';
  
  static final AmttaiCacheManager _instance = AmttaiCacheManager._();
  factory AmttaiCacheManager() => _instance;
  
  AmttaiCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 1000,
            fileService: HttpFileService(
              httpClient: IOClient(
                HttpClient()
                  ..maxConnectionsPerHost = 6
                  ..idleTimeout = const Duration(seconds: 15)
                  ..userAgent = 'AmttaiApp/1.0.0 (support@amttai.com; bot-like traffic avoidance)',
              ),
            ),
          ),
        );
}

/// Utility to silently download images in the background to warm the cache.
class ImagePrefetcher {
  /// Prefetch a batch of image URLs into [AmttaiCacheManager] with the correct
  /// per-URL headers (Appwrite session or Wikimedia User-Agent).
  /// Downloads are throttled with small delays between items to avoid 429s.
  static Future<void> prefetch(List<String?> urls, {int count = 8}) async {
    final validUrls = urls
        .where((u) => u != null && u.trim().isNotEmpty)
        .map((u) => u!)
        .take(count)
        .toList();

    for (final url in validUrls) {
      _downloadWithRetry(url);
      // Small stagger between kicks to avoid burst rate-limiting
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  /// Prefetch a single image URL — useful for warming the cache just before
  /// a hero transition (e.g. when a card is tapped).
  static Future<void> prefetchSingle(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    await _downloadWithRetry(url);
  }

  /// Download with up to 3 retries and exponential backoff for transient errors.
  static Future<void> _downloadWithRetry(String url, {int maxRetries = 3}) async {
    final headers = await AppwriteImage.resolveHeadersFor(url);
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await AmttaiCacheManager().downloadFile(
          url,
          authHeaders: headers,
        );
        return; // success
      } catch (e) {
        final isRetryable = e.toString().contains('429') ||
            e.toString().contains('503') ||
            e.toString().contains('502') ||
            e.toString().contains('SocketException');
        if (!isRetryable || attempt == maxRetries) return; // give up silently
        // Exponential backoff: 500ms, 1500ms, 3500ms
        await Future<void>.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      }
    }
  }
}

/// Caches the session header so we don't repeatedly read from SharedPreferences
/// on every image load, which was causing 429 rate limiting.
class _SessionHeaderCache {
  static String? _cachedSessionId;
  static DateTime? _lastFetched;
  static const _cacheValidityMs = 30000;

  static bool hasValidSession() {
    if (_cachedSessionId != null && _lastFetched != null) {
      return DateTime.now().difference(_lastFetched!).inMilliseconds < _cacheValidityMs;
    }
    return false;
  }

  static String? get cachedSessionId => _cachedSessionId;

  static Future<String?> getSessionId() async {
    final now = DateTime.now();
    if (_cachedSessionId != null &&
        _lastFetched != null &&
        now.difference(_lastFetched!).inMilliseconds < _cacheValidityMs) {
      return _cachedSessionId;
    }
    try {
      final sessionId = await AuthService().getCurrentSessionId();
      if (sessionId != null && sessionId.isNotEmpty) {
        _cachedSessionId = sessionId;
        _lastFetched = now;
      }
    } catch (_) {}
    return _cachedSessionId;
  }
}

class AppwriteImage extends StatefulWidget {
  const AppwriteImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.memCacheHeight,
    this.memCacheWidth,
    this.filterQuality = FilterQuality.low,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeOutDuration = const Duration(milliseconds: 300),
  });

  final String? imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final BorderRadius? borderRadius;
  final int? memCacheHeight;
  final int? memCacheWidth;
  final FilterQuality filterQuality;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  /// Resolve the correct HTTP headers for a given image URL.
  /// Appwrite Storage URLs get the session header; Wikimedia URLs get a
  /// compliant User-Agent; everything else gets an empty map.
  /// This is used by external consumers (e.g. RecipeDetailScreen) to ensure
  /// they hit the same cache entry as AppwriteImage widgets.
  static Future<Map<String, String>> resolveHeadersFor(String url) async {
    if (url.toLowerCase().contains('wikimedia.org')) {
      return {'User-Agent': 'AmttaiApp/1.0 (amttai_support@example.com) Flutter/3.x'};
    }
    if (url.contains('/storage/buckets/') && url.contains('/view?project=')) {
      final sessionId = await _SessionHeaderCache.getSessionId();
      if (sessionId != null && sessionId.isNotEmpty) {
        return {'X-Appwrite-Session': sessionId};
      }
    }
    return const {};
  }

  /// Synchronous header resolution — returns cached session headers immediately
  /// if available, otherwise empty. Use for zero-async widget builds.
  static Map<String, String> resolveHeadersSync(String url) {
    if (url.toLowerCase().contains('wikimedia.org')) {
      return {'User-Agent': 'AmttaiApp/1.0 (amttai_support@example.com) Flutter/3.x'};
    }
    if (url.contains('/storage/buckets/') && url.contains('/view?project=')) {
      if (_SessionHeaderCache.hasValidSession()) {
        return {'X-Appwrite-Session': _SessionHeaderCache.cachedSessionId!};
      }
    }
    return const {};
  }

  /// Build an optimized preview URL for Appwrite Storage images.
  /// External callers can use this to match the same cache key as AppwriteImage.
  static String buildOptimizedUrl(String originalUrl, {int? width, int? height}) {
    if (originalUrl.contains('/storage/buckets/') && originalUrl.contains('/view?project=')) {
      if (width != null || height != null) {
        String optimized = originalUrl.replaceAll('/view?project=', '/preview?project=');
        if (width != null) optimized += '&width=$width';
        if (height != null) optimized += '&height=$height';
        optimized += '&quality=85';
        return optimized;
      }
    }
    return originalUrl;
  }


  static Widget _defaultPlaceholder(BuildContext context, String url) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  static Widget _defaultError(BuildContext context, String url, dynamic error) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade300, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_rounded,
              color: Colors.grey.shade400,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              'Image Unavailable',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<AppwriteImage> createState() => _AppwriteImageState();
}

class _AppwriteImageState extends State<AppwriteImage> {
  Map<String, String>? _headers;
  bool _isLoadingHeaders = false;
  late String _optimizedUrl;

  @override
  void initState() {
    super.initState();
    _optimizedUrl = _buildOptimizedUrl(widget.imageUrl);
    _resolveHeaders();
  }

  @override
  void didUpdateWidget(AppwriteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _optimizedUrl = _buildOptimizedUrl(widget.imageUrl);
      _resolveHeaders();
    }
  }

  String _buildOptimizedUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return '';
    
    // Intercept only internal Appwrite Storage URLs, bypass external links like Wikimedia
    if (originalUrl.contains('/storage/buckets/') && originalUrl.contains('/view?project=')) {
      if (widget.memCacheWidth != null || widget.memCacheHeight != null) {
        String optimized = originalUrl.replaceAll('/view?project=', '/preview?project=');
        if (widget.memCacheWidth != null) {
          optimized += '&width=${widget.memCacheWidth}';
        }
        if (widget.memCacheHeight != null) {
          optimized += '&height=${widget.memCacheHeight}';
        }
        optimized += '&quality=85'; // Force 85% compression for previews
        return optimized;
      }
    }
    return originalUrl;
  }

  void _resolveHeaders() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return;
    
    final isWikimedia = widget.imageUrl!.toLowerCase().contains('wikimedia.org');
    
    if (isWikimedia) {
      setState(() {
        _headers = {'User-Agent': 'AmttaiApp/1.0 (amttai_support@example.com) Flutter/3.x'};
        _isLoadingHeaders = false;
      });
      return;
    }

    if (_SessionHeaderCache.hasValidSession()) {
      setState(() {
        _headers = {'X-Appwrite-Session': _SessionHeaderCache.cachedSessionId!};
        _isLoadingHeaders = false;
      });
    } else {
      _isLoadingHeaders = true;
      _SessionHeaderCache.getSessionId().then((sessionId) {
        if (!mounted) return;
        setState(() {
          if (sessionId != null && sessionId.isNotEmpty) {
            _headers = {'X-Appwrite-Session': sessionId};
          } else {
            _headers = {};
          }
          _isLoadingHeaders = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return AppwriteImage._defaultError(context, '', null);
    }

    if (_isLoadingHeaders) {
      return widget.placeholder?.call(context, widget.imageUrl!) ?? AppwriteImage._defaultPlaceholder(context, widget.imageUrl!);
    }

    Widget image = CachedNetworkImage(
      imageUrl: _optimizedUrl,
      fit: widget.fit ?? BoxFit.cover,
      width: widget.width,
      height: widget.height,
      memCacheHeight: widget.memCacheHeight,
      memCacheWidth: widget.memCacheWidth,
      filterQuality: widget.filterQuality,
      fadeInDuration: widget.fadeInDuration,
      fadeOutDuration: widget.fadeOutDuration,
      cacheManager: AmttaiCacheManager(),
      httpHeaders: _headers == null || _headers!.isEmpty ? null : _headers,
      placeholder: widget.placeholder ?? AppwriteImage._defaultPlaceholder,
      errorWidget: widget.errorWidget ?? AppwriteImage._defaultError,
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }
}