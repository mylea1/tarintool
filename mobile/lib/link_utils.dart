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
/// The optional opener keeps this pure at the UI boundary and lets widget
/// tests verify success and failure without launching a real browser or app.
Future<bool> launchTrainingUri(Uri uri, {TrainingUriOpener? opener}) =>
    (opener ??
    (target) => launchUrl(target, mode: LaunchMode.externalApplication))(uri);
