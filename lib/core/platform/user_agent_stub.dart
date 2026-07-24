/// Implémentation par défaut (mobile natif) — pas de `navigator.userAgent`
/// en dehors du Web, la détection de plateforme mobile s'appuie alors
/// uniquement sur `defaultTargetPlatform` (voir mobile_detector.dart).
String? get currentUserAgent => null;
