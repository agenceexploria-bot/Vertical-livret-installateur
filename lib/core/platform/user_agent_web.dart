// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// `navigator.userAgent` du navigateur — utilisé sur Web pour distinguer un
/// vrai navigateur mobile (Chrome Android, Safari iOS...) d'un navigateur
/// desktop, ce que `defaultTargetPlatform` ne fait pas de façon fiable sur
/// Flutter Web (il reflète souvent l'OS hôte, pas le user-agent).
String? get currentUserAgent => web.window.navigator.userAgent;
