import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import '../../../core/platform/mobile_detector.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/voice_recorder.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/api_client.dart';
import '../../../data/models/chantier.dart';
import '../../../state/chantier_state.dart';

enum _RexMode { vocal, texte }

class RexScreen extends StatefulWidget {
  const RexScreen({super.key});

  @override
  State<RexScreen> createState() => _RexScreenState();
}

class _RexScreenState extends State<RexScreen> with SingleTickerProviderStateMixin {
  _RexMode _mode = _RexMode.vocal;
  final _recorder = VoiceRecorder();
  final _speech = stt.SpeechToText();
  final _textController = TextEditingController();
  late final AnimationController _waveController;

  bool _speechAvailable = false;
  bool _isRecording = false;
  bool _isEncoding = false;
  bool _isSubmitting = false;
  String? _audioDataUrl;
  // Cause précise du dernier échec d'enregistrement/envoi — affichée à
  // l'écran (voir _buildVocalMode/_buildTechnicalDetails) pour que Tobi
  // puisse lire lui-même ce qui a cassé, sans brancher de console (voir
  // diagnostic transcription REX mobile).
  String? _voiceError;
  String? _sendError;
  bool _showTechnicalDetails = false;
  String _liveText = '';
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _speech.initialize().then((available) {
      if (mounted) setState(() => _speechAvailable = available);
    }).catchError((_) {
      // Reconnaissance vocale indisponible (navigateur non supporté,
      // permission refusée...) : on reste en mode audio seul, déjà géré
      // sans elle — pas d'exception non interceptée dans la console.
      if (mounted) setState(() => _speechAvailable = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveController.dispose();
    _recorder.dispose();
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _timer?.cancel();
      _waveController.stop();
      if (_speechAvailable) await _speech.stop();
      setState(() {
        _isRecording = false;
        _isEncoding = true;
      });
      final encoded = await _recorder.stopAndEncode();
      if (!mounted) return;
      setState(() {
        _isEncoding = false;
        _audioDataUrl = encoded.dataUrl;
        _voiceError = encoded.error;
        _showTechnicalDetails = false;
        // La transcription en temps réel (best-effort, voir plus bas) est
        // pré-remplie mais reste éditable : l'installateur corrige si besoin
        // avant l'envoi. Si ce champ reste vide, le backend tente une
        // transcription automatique sur l'audio envoyé (voir
        // backend/src/lib/transcription.ts).
        _textController.text = _liveText;
      });
      if (!encoded.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec enregistrement audio : ${encoded.error}')),
        );
      }
      return;
    }

    // Toujours branché, JAMAIS gaté par _speechAvailable : sur Web mobile,
    // voice_recorder.dart n'exploite ce callback que là où il a réellement
    // un second enregistreur à brancher (voir isMobileDevice() dans
    // VoiceRecorder.start) — inoffensif ailleurs (desktop, natif), ignoré
    // purement et simplement. Un ancien garde-fou ici se fiait à
    // _speechAvailable pour éviter que Web Speech API et le streaming par
    // segments écrivent tous les deux dans _liveText — mais
    // speech_to_text.initialize() peut renvoyer `true` sur Android ET
    // iPhone sans jamais livrer le moindre résultat en pratique (fiabilité
    // mobile de cette API, la raison même de l'existence du streaming par
    // segments) : ce garde-fou désactivait alors les deux mécanismes à la
    // fois, silencieusement — c'est exactement ce qui s'est produit lors du
    // diagnostic transcription REX mobile (zéro appel à
    // /transcribe-segment sur Android ET iPhone).
    final result = await _recorder.start(onLiveSegment: _handleLiveSegment);
    if (!mounted) return;
    if (result != VoiceRecorderStartResult.started) {
      final SnackBar snackBar;
      switch (result) {
        case VoiceRecorderStartResult.permissionPermanentlyDenied:
          snackBar = SnackBar(
            content: const Text('Micro refusé. Activez-le dans les réglages du téléphone.'),
            action: SnackBarAction(label: 'Réglages', onPressed: openAppSettings),
          );
        case VoiceRecorderStartResult.unsupported:
          // Jamais un bouton mort ni un échec silencieux : ce navigateur ne
          // sait tout simplement pas enregistrer d'audio (voir
          // pickSupportedAudioMimeType) — bascule vers la saisie texte,
          // seule option qui reste réellement utilisable ici.
          snackBar = const SnackBar(
            content: Text('L\'enregistrement audio n\'est pas supporté sur cette version d\'iOS — utilisez la saisie texte du REX.'),
          );
          setState(() => _mode = _RexMode.texte);
        case VoiceRecorderStartResult.permissionDenied:
        case VoiceRecorderStartResult.error:
        case VoiceRecorderStartResult.started:
          snackBar = const SnackBar(content: Text('Micro indisponible — vérifiez l\'autorisation d\'accès.'));
      }
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }
    setState(() {
      _isRecording = true;
      _audioDataUrl = null;
      _liveText = '';
      _textController.clear();
      _seconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
      _waveController.repeat();
    });

    // Transcription en direct via la reconnaissance vocale native de
    // l'appareil (nécessite le réseau) — best-effort : si indisponible
    // (hors-ligne, navigateur non supporté), l'audio brut reste envoyé quand
    // même via VoiceRecorder, qui lui fonctionne sans réseau. Une erreur ici
    // ne doit pas empêcher l'enregistrement audio, déjà démarré, de continuer.
    if (_speechAvailable) {
      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted) setState(() => _liveText = result.recognizedWords);
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            partialResults: true,
            listenFor: const Duration(minutes: 5),
            pauseFor: const Duration(seconds: 10),
            // Sans ça, la reconnaissance suit la langue système de
            // l'appareil — correcte par défaut sur un téléphone configuré en
            // français, mais fausse dès que ce n'est pas le cas alors que
            // l'app (et le témoignage client) sont toujours en français.
            localeId: 'fr_FR',
          ),
        );
      } catch (e) {
        debugPrint('RexScreen: échec de la transcription en direct — $e');
      }
    }
  }

  /// Segment audio d'environ 5s transcrit en direct par Groq (Web mobile
  /// uniquement — voir VoiceRecorder.start, WebRecordingSession) : le texte
  /// reçu s'accumule dans _liveText, affiché en direct exactement comme la
  /// Web Speech API le fait sur desktop. Un échec ici (réseau,
  /// rate-limit...) ne doit JAMAIS interrompre l'enregistrement en cours —
  /// voir VoiceRecorder.start pour l'isolation côté enregistreur lui-même,
  /// ceci couvre l'échec de l'envoi du segment.
  Future<void> _handleLiveSegment(Uint8List bytes, String mimeType, String extension) async {
    if (!mounted) return;
    final api = context.read<ApiClient>();
    try {
      final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      final data = await api.transcribeSegment(dataUrl);
      if (!mounted) return;
      setState(() => _liveText = appendLiveSegmentText(_liveText, data['text'] as String?));
    } catch (e) {
      debugPrint('RexScreen._handleLiveSegment: échec — $e');
    }
  }

  bool get _peutEnvoyer => !_isSubmitting &&
      (_mode == _RexMode.vocal ? _audioDataUrl != null : _textController.text.trim().isNotEmpty);

  Future<void> _envoyer(BuildContext context) async {
    final chantierState = context.read<ChantierState>();
    final reference = chantierState.currentChantier!.reference;
    final texte = _textController.text.trim();

    setState(() {
      _isSubmitting = true;
      _sendError = null;
      _showTechnicalDetails = false;
    });

    bool wasQueued;
    try {
      // Depuis que ChantierRepository.submitRex ne met plus en file
      // d'attente hors-ligne que les vraies coupures réseau (voir
      // isOfflineRetryable), un rejet serveur ou un bug client remonte ici
      // au lieu d'être avalé en silence — voir diagnostic transcription REX
      // mobile : c'est exactement l'absence de cette remontée qui laissait
      // croire qu'un REX avait été envoyé alors qu'il n'avait jamais atteint
      // le serveur.
      wasQueued = await chantierState.submitRex(
        reference,
        transcription: texte.isNotEmpty ? texte : null,
        audio: _mode == _RexMode.vocal ? _audioDataUrl : null,
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      setState(() {
        _isSubmitting = false;
        _sendError = 'Échec envoi REX : ${e.message}';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_sendError!)));
      return;
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _isSubmitting = false;
        _sendError = 'Échec envoi REX : $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_sendError!)));
      return;
    }

    if (!context.mounted) return;
    if (wasQueued) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('REX créé — hors-ligne, l\'audio sera envoyé au retour du réseau.')),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier;
    final envoyes = chantier?.rex ?? const <Rex>[];

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Retour d\'expérience'),
        backgroundColor: AppColors.primaire,
        foregroundColor: Colors.white,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (envoyes.isNotEmpty) ...[
              _buildHistorique(envoyes),
              const SizedBox(height: 32),
            ],
            _buildFormulaire(context),
          ],
        ),
      ),
    );
  }

  /// Retours déjà envoyés pour ce chantier — informatif, n'empêche jamais
  /// d'en soumettre un nouveau (contrairement à l'ancien comportement qui
  /// bloquait après un seul REX).
  Widget _buildHistorique(List<Rex> envoyes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Déjà envoyé (${envoyes.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        for (final rex in envoyes) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.fond, borderRadius: BorderRadius.circular(9)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(rex.soumisAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
                ),
                if (rex.transcription != null) ...[
                  const SizedBox(height: 4),
                  Text('« ${rex.transcription} »', style: const TextStyle(fontSize: 13, color: AppColors.encre, height: 1.4)),
                ] else if (rex.audioPath != null) ...[
                  const SizedBox(height: 4),
                  const Text('(note vocale sans transcription)', style: TextStyle(fontSize: 12, color: AppColors.acier, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormulaire(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Laissez un retour sur le chantier — note vocale ou texte. Vos remarques aident à améliorer nos produits.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.acier, height: 1.4),
        ),
        const SizedBox(height: 24),
        _buildModeSwitch(),
        const SizedBox(height: 32),
        if (_mode == _RexMode.vocal) _buildVocalMode() else _buildTexteMode(),
        if (_sendError != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(_sendError!, _recorder.stepLog),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _peutEnvoyer ? () => _envoyer(context) : null,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Valider et envoyer le REX'),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSwitch() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.lignes, width: 1.5), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          _modeButton('Note vocale', _RexMode.vocal),
          _modeButton('Texte', _RexMode.texte),
        ],
      ),
    );
  }

  Widget _modeButton(String label, _RexMode mode) {
    final isOn = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: _isRecording ? null : () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: isOn ? AppColors.encre : Colors.white),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isOn ? Colors.white : AppColors.acier)),
        ),
      ),
    );
  }

  Widget _buildVocalMode() {
    if (_isEncoding) {
      return const Column(
        children: [
          CircularProgressIndicator(color: AppColors.orange),
          SizedBox(height: 16),
          Text('Préparation de la note vocale...', style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      );
    }

    return Column(
      children: [
        if (_isRecording) ...[_buildWaveform(), const SizedBox(height: 20)],
        GestureDetector(
          onTap: _toggleRecording,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _isRecording ? AppColors.rouge : AppColors.orange,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: (_isRecording ? AppColors.rouge : AppColors.orange).withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 10),
              ],
            ),
            child: Icon(_isRecording ? Icons.stop : Icons.mic, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isRecording
              ? 'Enregistrement... ${_formatTime(_seconds)}'
              : _audioDataUrl != null
                  ? 'Note vocale enregistrée (${_formatTime(_seconds)}) — appuyer pour ré-enregistrer'
                  : 'Appuyer pour parler',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _isRecording ? AppColors.rouge : AppColors.encre),
        ),
        // Indicateur de diagnostic permanent (Web mobile uniquement) : sans
        // lui, un second enregistreur qui ne démarre jamais (interop, ou
        // simplement jamais branché — voir le garde-fou _speechAvailable
        // retiré ci-dessus, exactement ce qui s'est produit lors du
        // diagnostic transcription REX mobile) reste invisible tant que
        // personne ne branche de console.
        if (_isRecording && kIsWeb && isMobileDevice()) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_recorder.liveTranscriptionAvailable ? AppColors.vert : AppColors.acierClair).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _recorder.liveTranscriptionAvailable ? 'Direct : actif' : 'Direct : indisponible',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _recorder.liveTranscriptionAvailable ? AppColors.vert : AppColors.acier,
              ),
            ),
          ),
        ],
        if (!_isRecording && !_isEncoding && _voiceError != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner('Échec enregistrement audio : $_voiceError', _recorder.stepLog),
        ],
        if (_isRecording && (_speechAvailable || _recorder.liveTranscriptionAvailable)) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.fond, borderRadius: BorderRadius.circular(9)),
            child: Text(
              _liveText.isEmpty ? 'La transcription apparaît ici pendant que vous parlez...' : _liveText,
              style: TextStyle(fontSize: 13, color: _liveText.isEmpty ? AppColors.acierClair : AppColors.encre, height: 1.4),
            ),
          ),
        ],
        if (!_isRecording && _audioDataUrl != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Transcription (modifiable)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.acier)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _textController,
            maxLines: 4,
            decoration: const InputDecoration(
              // L'audio a bien été capturé (sinon _voiceError serait affiché
              // ci-dessus à la place) — ce champ vide signifie seulement que
              // la reconnaissance vocale en direct n'a rien capté, pas que
              // l'envoi va échouer : le backend tente sa propre transcription
              // automatique sur l'audio dès réception (voir
              // backend/src/lib/transcription.ts).
              hintText: 'Aucune transcription captée en direct — seul l\'audio sera envoyé (une transcription sera tentée à la réception).',
            ),
          ),
        ],
      ],
    );
  }

  /// Message d'erreur affiché à l'écran pour une étape en échec, avec un
  /// panneau "détails techniques" dépliable listant les étapes franchies
  /// (voir VoiceRecorder.stepLog) — pensé pour être lisible directement sur
  /// le téléphone de Tobi, sans brancher aucune console (voir diagnostic
  /// transcription REX mobile).
  Widget _buildErrorBanner(String message, List<String> technicalSteps) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rouge.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.rouge.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontSize: 13, color: AppColors.rouge, fontWeight: FontWeight.w600, height: 1.4)),
          if (technicalSteps.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showTechnicalDetails = !_showTechnicalDetails),
              child: Text(
                _showTechnicalDetails ? 'Masquer les détails techniques ▲' : 'Voir les détails techniques ▼',
                style: const TextStyle(fontSize: 12, color: AppColors.acier, fontWeight: FontWeight.w600),
              ),
            ),
            if (_showTechnicalDetails) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.fond, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  technicalSteps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n'),
                  style: const TextStyle(fontSize: 11, color: AppColors.acier, fontFamily: 'monospace', height: 1.5),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTexteMode() {
    return TextField(
      controller: _textController,
      maxLines: 6,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        hintText: 'Le montage s\'est bien déroulé, RAS. Attention au réglage des fins de course...',
      ),
    );
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final double height = (20 + 30 * math.sin((_waveController.value * 2 * math.pi) + (index * 0.5))).clamp(4.0, 50.0);
            return Container(
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: AppColors.rouge, borderRadius: BorderRadius.circular(2)),
            );
          }),
        );
      },
    );
  }
}
