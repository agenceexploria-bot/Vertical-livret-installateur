import 'dart:convert';
import '../api_client.dart';
import '../local/app_database.dart';

/// Rejoue la file d'attente locale (PendingOperations) vers l'API, dans
/// l'ordre où les actions ont été saisies hors-ligne.
class SyncEngine {
  final AppDatabase _db;
  final ApiClient _api;
  bool _isDraining = false;

  SyncEngine(this._db, this._api);

  Future<void> drain() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      final ops = await _db.getPendingOperationsOrdered();
      for (final op in ops) {
        try {
          await _dispatch(op);
          await _db.deleteOperation(op.id);
        } on ApiException catch (e) {
          // Le serveur a répondu et rejeté l'action (ex. validation) : on ne
          // la rejouera pas indéfiniment, mais on continue la file.
          await _db.markOperationFailed(op.id, e.message);
        } catch (_) {
          // Pas de réseau ou serveur injoignable : on retentera au prochain
          // retour en ligne, sans perdre les opérations suivantes de la file.
          break;
        }
      }
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _dispatch(PendingOperation op) async {
    final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
    switch (op.type) {
      case 'markLivretOuvert':
        await _api.markLivretOuvert(op.chantierReference);
        break;
      case 'updatePoint':
        await _api.updatePoint(
          op.chantierReference,
          payload['pointId'] as String,
          status: payload['status'] as String?,
          photo: payload['photo'] as String?,
          clientValidatedAt: payload['clientValidatedAt'] as String?,
        );
        break;
      case 'submitRex':
        await _api.postRex(
          op.chantierReference,
          transcription: payload['transcription'] as String?,
          audio: payload['audio'] as String?,
        );
        break;
      case 'submitPv':
        await _api.postPv(
          op.chantierReference,
          payload['signataire'] as String,
          signatureImage: payload['signatureImage'] as String?,
        );
        break;
      case 'addDocument':
        await _api.addDocument(
          op.chantierReference,
          titre: payload['titre'] as String,
          categorie: payload['categorie'] as String,
          file: payload['file'] as String,
        );
        break;
      case 'addHabilitation':
        await _api.addHabilitation(
          titre: payload['titre'] as String,
          dateExpiration: payload['dateExpiration'] as String,
          file: payload['file'] as String,
        );
        break;
    }
  }
}
