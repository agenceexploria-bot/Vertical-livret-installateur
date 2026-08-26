import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../core/photo_capture.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/drop_zone.dart';
import '../../../state/auth_state.dart';
import '../../../state/chantier_state.dart';
import '../../../data/models/point_controle.dart';

class ReceptionMarchandisesScreen extends StatelessWidget {
  const ReceptionMarchandisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chantierState = context.watch<ChantierState>();
    final chantier = chantierState.currentChantier!;
    final points = chantier.receptionMarchandises;

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Réception des marchandises'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.fond,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: chantier.progressionReception,
                    backgroundColor: AppColors.lignes,
                    color: AppColors.vert,
                  ),
                ),
                const SizedBox(width: 16),
                Text('${(chantier.progressionReception * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.vert)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: points.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final point = points[index];
                return _PointCard(reference: chantier.reference, point: point);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PointCard extends StatefulWidget {
  final String reference;
  final PointControle point;

  const _PointCard({required this.reference, required this.point});

  @override
  State<_PointCard> createState() => _PointCardState();
}

class _PointCardState extends State<_PointCard> {
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    final point = widget.point;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIcon(point),
              const SizedBox(width: 12),
              Expanded(child: Text(point.libelle, style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                onPressed: () => _signalerAnomalie(context),
                icon: const Icon(Icons.warning_amber_rounded),
                color: point.status == PointStatus.nonConforme ? AppColors.rouge : AppColors.acierClair,
                tooltip: 'Signaler une anomalie',
              ),
            ],
          ),
          if (point.validePar != null && point.valideAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Par ${point.validePar} · ${DateFormat('dd/MM HH:mm').format(point.valideAt!)}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.acierClair),
              ),
            ),
          const SizedBox(height: 12),
          DropZone(
            onFilesDropped: (files) => _deposerPhoto(context, files),
            child: GestureDetector(
              onTap: _isCapturing ? null : () => _prendrePhoto(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: point.photoPath != null ? AppColors.vert.withValues(alpha: 0.1) : AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt,
                      size: 16,
                      color: point.photoPath != null
                          ? AppColors.vert
                          : point.status == PointStatus.nonConforme
                              ? AppColors.rouge
                              : AppColors.orange),
                    const SizedBox(width: 8),
                    Text(
                      _isCapturing
                          ? 'Capture en cours...'
                          : point.photoPath != null
                              ? 'Photo jointe — reprendre'
                              : point.status == PointStatus.nonConforme
                                  ? 'Photo obligatoire (anomalie)'
                                  : 'Photo (facultative) — appuyer',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: point.photoPath != null
                            ? AppColors.vert
                            : point.status == PointStatus.nonConforme
                                ? AppColors.rouge
                                : AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: point.status == PointStatus.vide
                ? ElevatedButton(
                    onPressed: () => _valider(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.vert),
                    child: const Text('Valider le point'),
                  )
                : OutlinedButton(
                    onPressed: () => _annulerValidation(context),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.rouge, side: const BorderSide(color: AppColors.rouge)),
                    child: const Text('Annuler la validation'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(PointControle point) {
    switch (point.status) {
      case PointStatus.conforme:
        return const Icon(Icons.check_circle, color: AppColors.vert);
      case PointStatus.nonConforme:
        return const Icon(Icons.cancel, color: AppColors.rouge);
      default:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lignes, width: 2),
          ),
        );
    }
  }

  Future<void> _prendrePhoto(BuildContext context) async {
    setState(() => _isCapturing = true);
    try {
      final photo = await PhotoCapture.captureCompressed(context);
      if (photo == null || !context.mounted) return;
      await context.read<ChantierState>().updatePoint(widget.reference, widget.point.id, photo: photo);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Glisser-déposer (Web) — même logique que [_prendrePhoto], juste une
  /// autre façon de fournir le fichier ; un point ne prend qu'une seule
  /// photo, donc seul le premier fichier déposé est retenu.
  Future<void> _deposerPhoto(BuildContext context, List<XFile> files) async {
    setState(() => _isCapturing = true);
    try {
      final bytes = await files.first.readAsBytes();
      final photo = PhotoCapture.fromDroppedBytes(bytes);
      if (photo == null || !context.mounted) return;
      await context.read<ChantierState>().updatePoint(widget.reference, widget.point.id, photo: photo);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _valider(BuildContext context) async {
    final nom = context.read<AuthState>().currentUser?.fullName;
    await context.read<ChantierState>().updatePoint(widget.reference, widget.point.id, status: PointStatus.conforme.name, validatedByName: nom);
  }

  /// Annule une validation (conforme ou non conforme) — remet le point à
  /// l'état "à faire".
  Future<void> _annulerValidation(BuildContext context) async {
    final nom = context.read<AuthState>().currentUser?.fullName;
    await context.read<ChantierState>().updatePoint(widget.reference, widget.point.id, status: PointStatus.vide.name, validatedByName: nom);
  }

  /// Une anomalie doit être prouvée par une photo — contrairement à la
  /// validation d'un point conforme, qui n'en a plus besoin. Retaper alors
  /// que l'anomalie est déjà signalée l'annule (retour à "à faire").
  Future<void> _signalerAnomalie(BuildContext context) async {
    final nom = context.read<AuthState>().currentUser?.fullName;
    if (widget.point.status == PointStatus.nonConforme) {
      await context.read<ChantierState>().updatePoint(widget.reference, widget.point.id, status: PointStatus.vide.name, validatedByName: nom);
      return;
    }
    if (widget.point.photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une photo est obligatoire pour signaler une anomalie.')),
      );
      return;
    }
    await context.read<ChantierState>().updatePoint(widget.reference, widget.point.id, status: PointStatus.nonConforme.name, validatedByName: nom);
  }
}
