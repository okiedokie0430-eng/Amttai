import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_config.dart';

class SocialPayLaunchPayload {
  final Uri deeplink;
  final String description;

  const SocialPayLaunchPayload({
    required this.deeplink,
    required this.description,
  });
}

/// Builds and launches SocialPay deeplinks.
///
/// Preferred flow: use server-generated `qPay_QRcode`, `key`, or a full
/// signed deeplink.
class SocialPayService {
  const SocialPayService();

  SocialPayLaunchPayload buildFromQrPayload({
    required String qrPayload,
    required String description,
  }) {
    final deeplink = Uri.parse(
      'socialpay-payment://q?qPay_QRcode=${Uri.encodeComponent(qrPayload)}',
    );

    return SocialPayLaunchPayload(deeplink: deeplink, description: description);
  }

  SocialPayLaunchPayload buildFromKeyPayload({
    required String keyPayload,
    required String description,
  }) {
    final deeplink = Uri.parse(
      'socialpay-payment://key=${Uri.encodeComponent(keyPayload)}',
    );

    return SocialPayLaunchPayload(deeplink: deeplink, description: description);
  }

  SocialPayLaunchPayload buildFromDeeplink({
    required String deeplink,
    required String description,
  }) {
    return SocialPayLaunchPayload(
      deeplink: Uri.parse(deeplink),
      description: description,
    );
  }

  /// Unsafe fallback: raw transfer templating is rejected by newer SocialPay
  /// builds unless payload is provider-signed.
  SocialPayLaunchPayload buildUnsafeTransferPayload({
    required String receiverAccount,
    required int amountMnt,
    required String description,
    required String transactionCode,
  }) {
    final cleanAccount = receiverAccount.replaceAll(RegExp(r'\s+'), '');

    final deeplinkRaw = AppConfig.socialPayDeeplinkTemplate
        .replaceAll('{to}', Uri.encodeComponent(cleanAccount))
        .replaceAll('{amount}', Uri.encodeComponent(amountMnt.toString()))
        .replaceAll('{description}', Uri.encodeComponent(description))
        .replaceAll('{txCode}', Uri.encodeComponent(transactionCode));

    return SocialPayLaunchPayload(
      deeplink: Uri.parse(deeplinkRaw),
      description: description,
    );
  }

  @Deprecated('Use buildFromQrPayload/buildFromKeyPayload/buildFromDeeplink.')
  SocialPayLaunchPayload buildTransferPayload({
    required String receiverAccount,
    required int amountMnt,
    required String description,
    required String transactionCode,
  }) {
    return buildUnsafeTransferPayload(
      receiverAccount: receiverAccount,
      amountMnt: amountMnt,
      description: description,
      transactionCode: transactionCode,
    );
  }

  Future<bool> launch(Uri deeplink) async {
    final candidates = <Uri>[deeplink];

    if (deeplink.scheme == 'socialpay') {
      candidates.add(deeplink.replace(scheme: 'socialpay-payment'));
    } else if (deeplink.scheme == 'socialpay-payment') {
      candidates.add(deeplink.replace(scheme: 'socialpay'));
    }

    for (final candidate in candidates) {
      try {
        final openedExternal = await launchUrl(
          candidate,
          mode: LaunchMode.externalApplication,
        );
        if (openedExternal) return true;
      } catch (_) {
        // Try next strategy.
      }

      try {
        final openedDefault = await launchUrl(candidate);
        if (openedDefault) return true;
      } catch (_) {
        // Try next strategy.
      }
    }

    return false;
  }
}
