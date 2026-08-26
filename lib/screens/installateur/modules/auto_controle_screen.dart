import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/photo_capture.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/drop_zone.dart';
import '../../../data/api_client.dart';
import '../../../state/auth_state.dart';
import '../../../state/chantier_state.dart';
import '../../../data/models/point_controle.dart';

class AutoControleScreen extends StatefulWidget {
  const AutoControleScreen({super.key});

  @override
  State<AutoControleScreen> createState() => _AutoControleScreenState();
}

class _AutoControleScreenState extends State<AutoControleScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final chantierState = context.watch<ChantierState>();
    final chantier = chantierState.currentChantier!;
    final categories = chantier.autoControle.map((p) => p.categorie).toSet().toList();
    final tabIndex = _tabIndex < categories.length ? _tabIndex : 0;
    final points = categories.isEmpty
        ? const <PointControle>[]
        : chantier.autoControle.where((p) => p.categorie == categories[tabIndex]).toList();

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Auto-contrôle'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: Column(
        children: [
          _buildTabs(categories),
          _buildProgress(chantier.progressionAutoControle),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: points.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _PointCard(reference: chantier.reference, point: points[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(List<String> categories) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: AppColors.blanc,
      child: Row(
        children: List.generate(categories.length, (i) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tabIndex = i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _tabIndex == i ? AppColors.encre : Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                categories[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _tabIndex == i ? Colors.white : AppColors.acier,
                ),
              ),
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildProgress(double value) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.fond,
      child: Row(
        children: [
          Expanded(child: LinearProgressIndicator(value: value, color: AppColors.vert, backgroundColor: AppColors.lignes)),
          const SizedBox(width: 16),
          Text('${(value * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.vert)),
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
              GestureDetector(
                onTap: () => _toggle(context),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: point.status == PointStatus.conforme ? AppColors.vert : Colors.transparent,
                    border: Border.all(
                      color: point.status == PointStatus.conforme ? AppColors.vert : AppColors.lignes,
                      width: 2,
                    ),
                  ),
                  child: point.status == PointStatus.conforme ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 12),
              if (point.critique) const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.shield_outlined, size: 16, color: AppColors.rouge),
              ),
              Expanded(child: Text(point.libelle, style: const TextStyle(fontSize: 13))),
              IconButton(
                onPressed: () => _signalerAnomalie(context),
                icon: const Icon(Icons.warning_amber_rounded, size: 20),
                color: point.status == PointStatus.nonConforme ? AppColors.rouge : AppColors.acierClair,
                tooltip: 'Signaler une anomalie',
              ),
            ],
          ),
          if (point.validePar != null && point.valideAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 2),
              child: Text(
                'Par ${point.validePar} · ${DateFormat('dd/MM HH:mm').format(point.valideAt!)}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.acierClair),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 8),
            child: DropZone(
              onFilesDropped: (files) => _deposerPhoto(context, files),
              child: GestureDetector(
                onTap: _isCapturing ? null : () => _prendrePhoto(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: point.photoPath != null ? AppColors.vert.withValues(alpha: 0.1) : AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt, size: 14, color: point.photoPath != null ? AppColors.vert : AppColors.orange),
                      const SizedBox(width: 6),
                      Text(
                        _isCapturing
                            ? 'Capture en cours...'
                            : point.photoPath != null
                                ? 'Photo de détail jointe'
                                : point.status == PointStatus.nonConforme
                                    ? 'Photo obligatoire (anomalie)'
                                    : 'Photo (facultative) — appuyer',
                        style: TextStyle(
                          fontSize: 10.5,
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
          ),
        ],
      ),
    );
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
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Une erreur est survenue. Réessayez.')));
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Un point déjà validé (conforme ou non conforme) redevient "à faire" en
  /// retapant la case — seul un point encore vide se marque conforme ici.
  Future<void> _toggle(BuildContext context) async {
    final next = widget.point.status == PointStatus.vide ? PointStatus.conforme : PointStatus.vide;
    final nom = context.read<AuthState>().currentUser?.fullName;
    await context.read<ChantierState>().updatePoint(widget.reference, widget.point.id, status: next.name, validatedByName: nom);
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
