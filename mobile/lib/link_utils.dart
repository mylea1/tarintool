import 'package:url_launcher/url_launcher.dart';

/// The only external links KILO accepts are web links.  A missing scheme is
/// treated as a normal web address and receives an https scheme so that a
/// pasted `example.com/video` remains useful without opening arbitrary URI
/// schemes.
Uri? normalizeTrainingUri(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  final hostPortLike = RegExp(
    r'^(?:\[[0-9A-Fa-f:]+\]|[^:/\s]+):\d+(?:[/?#].*)?$',
  ).hasMatch(value);
  if (parsed.hasScheme) {
    if (!hostPortLike) {
      if (parsed.scheme != 'http' && parsed.scheme != 'https') return null;
      return parsed.host.isEmpty ? null : parsed;
    }
  }

  final withScheme = Uri.tryParse('https://$value');
  if (withScheme == null || withScheme.host.isEmpty) return null;
  return withScheme;
}

typedef TrainingUriOpener = Future<bool> Function(Uri uri);

/// Opens a normalized web link through the operating system.
///
/// The operating system gets the first chance to route a universal/app link to
/// an installed application. A normal external launch is the browser fallback
/// for links which are not claimed by an app. KILO deliberately does not
/// invent private third-party schemes: whether an HTTPS link opens an app is
/// decided by that app's universal-link/app-link registration.
///
/// [opener] is retained for existing callers and is treated as the primary
/// opener. The two explicit openers make the fallback order testable without
/// launching a real browser or app.
Future<bool> launchTrainingUri(
  Uri uri, {
  TrainingUriOpener? opener,
  TrainingUriOpener? nonBrowserOpener,
  TrainingUriOpener? browserOpener,
}) async {
  final primary =
      nonBrowserOpener ??
      opener ??
      (target) =>
          launchUrl(target, mode: LaunchMode.externalNonBrowserApplication);
  final fallback =
      browserOpener ??
      (target) => launchUrl(target, mode: LaunchMode.externalApplication);

  try {
    if (await primary(uri)) return true;
  } catch (_) {
    // A missing handler should be recoverable through the browser fallback.
  }
  try {
    return await fallback(uri);
  } catch (_) {
    return false;
  }
}
