import 'package:flutter/foundation.dart';
import 'user_agent.dart';

/// Vrai si l'app tourne sur un mobile — build natif Android/iOS, ou
/// navigateur mobile sur Web (Chrome Android, Safari iOS...).
///
/// Sur Web, `defaultTargetPlatform` reflète souvent l'OS de la machine plutôt
/// que le navigateur réellement utilisé (ex. Chrome desktop redimensionné en
/// petite largeur reste détecté comme "Windows") : on se base donc sur
/// `navigator.userAgent`, qui reflète le vrai navigateur, y compris en mode
/// "appareil" des DevTools Chrome (profil d'appareil sélectionné).
bool isMobileDevice() {
  if (kIsWeb) {
    final userAgent = currentUserAgent?.toLowerCase() ?? '';
    return userAgent.contains('android') || userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('mobile');
  }
  return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
}
