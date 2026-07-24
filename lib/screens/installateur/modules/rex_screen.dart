import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'dart:math' as math;
import '../../../core/theme.dart';
import '../../../core/voice_recorder.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../state/chantier_state.dart';
import '../../../state/network_state.dart';

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
  String? _audioDataUrl;
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
        _audioDataUrl = encoded;
        // La transcription en temps réel (Whisper non requis pour la V1) est
        // pré-remplie mais reste éditable : l'installateur corrige si besoin
        // avant l'envoi.
        _textController.text = _liveText;
      });
      if (encoded == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'enregistrer la note vocale — réessayez.')),
        );
      }
      return;
    }

    final started = await _recorder.start();
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Micro indisponible — vérifiez l\'autorisation d\'accès.')),
      );
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
    // même via VoiceRecorder, qui lui fonctionne sans réseau.
    if (_speechAvailable) {
      await _speech.listen(
        onResult: (result) {
          if (mounted) setState(() => _liveText = result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 10),
        ),
      );
    }
  }

  bool get _peutEnvoyer =>
      _mode == _RexMode.vocal ? _audioDataUrl != null : _textController.text.trim().isNotEmpty;

  Future<void> _envoyer(BuildContext context) async {
    final isOnline = context.read<NetworkState>().isOnline;
    final chantierState = context.read<ChantierState>();
    final reference = chantierState.currentChantier!.reference;
    final texte = _textController.text.trim();

    await chantierState.submitRex(
      reference,
      transcription: texte.isNotEmpty ? texte : null,
      audio: _mode == _RexMode.vocal ? _audioDataUrl : null,
    );

    if (!context.mounted) return;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hors-ligne : le REX sera envoyé au retour du réseau.')),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('Retour d\'expérience'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _peutEnvoyer ? () => _envoyer(context) : null,
                child: const Text('Valider et envoyer le REX'),
              ),
            ),
          ],
        ),
      ),
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
        if (_isRecording && _speechAvailable) ...[
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
              hintText: 'Aucune transcription — l\'audio seul sera envoyé.',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(9))),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTexteMode() {
    return TextField(
      controller: _textController,
      maxLines: 6,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        hintText: 'Le montage s\'est bien déroulé, RAS. Attention au réglage des fins de course...',
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(9))),
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
