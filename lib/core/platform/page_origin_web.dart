// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// `location.origin` du navigateur (ex.
/// "https://vertical-livret-installateur.vercel.app") — nécessaire pour
/// transformer un chemin relatif en URL absolue avant de le transmettre à un
/// service tiers (voir ApiClient._uploadsCallbackUrl) : contrairement à nos
/// propres appels API, qu'un navigateur résout tout seul contre l'origine de
/// la page, une donnée envoyée à l'infrastructure de Vercel Blob doit déjà
/// être absolue pour que LEUR service (pas notre navigateur) sache où
/// appeler.
String? get currentPageOrigin => web.window.location.origin;
