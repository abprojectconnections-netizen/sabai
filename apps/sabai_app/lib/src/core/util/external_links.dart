import 'package:url_launcher/url_launcher.dart';

/// Opens a URL outside the app. Injected so tests never touch a platform plugin.
typedef UrlOpener = Future<bool> Function(Uri uri);

Future<bool> openExternally(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
