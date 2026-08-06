import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/platform/file_downloader.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/chantier.dart';
import '../../data/models/point_controle.dart';
import '../../state/chantier_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';
import 'widgets/bo_responsive_table.dart';
import 'widgets/bo_table_row.dart';

class _AutoControleRow {
  final String chantierRef;
  final String client;
  final PointControle point;
  const _AutoControleRow(this.chantierRef, this.client, this.point);
}

/// Vue détaillée des auto-contrôles, tous chantiers confondus — atteinte via
/// le bouton "Exports Qualité" de la barre du haut (voir BoShell). Chaque
/// point de contrôle du module auto-contrôle (Module 6) est listé
/// individuellement, avec export PDF/CSV des mêmes données pour un usage
/// hors application (reporting qualité).
class BoAutoControleDetailScreen extends StatelessWidget {
  const BoAutoControleDetailScreen({super.key});

  List<_AutoControleRow> _rows(List<Chantier> chantiers) {
    final rows = <_AutoControleRow>[];
    for (final c in chantiers) {
      for (final p in c.autoControle) {
        rows.add(_AutoControleRow(c.reference, c.client, p));
      }
    }
    return rows;
  }

  (String, StatusType) _statutOf(PointControle p) {
    switch (p.status) {
      case PointStatus.conforme:
        return ('Conforme', StatusType.conforme);
      case PointStatus.nonConforme:
        return ('Non conforme', StatusType.nonConforme);
      case PointStatus.vide:
        return ('À faire', StatusType.attente);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chantiers = context.watch<ChantierState>().chantiers;
    final rows = _rows(chantiers);

    return BoShell(
      activeNav: 'chantiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Auto-contrôles & qualité — détail (${rows.length})', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: rows.isEmpty ? null : () => _exporterCsv(rows),
                icon: const Icon(Icons.table_view_outlined, size: 16),
                label: const Text('CSV', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: rows.isEmpty ? null : () => _exporterPdf(rows),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('PDF', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            BoPanel(
              child: EmptyState(
                icon: Icons.fact_check_outlined,
                message: 'Aucun point d\'auto-contrôle enregistré pour l\'instant.',
              ),
            )
          else
            BoResponsiveTable(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.blanc,
                  border: Border.all(color: AppColors.lignes),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: AppColors.encre.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _headerRow(),
                    for (final (i, r) in rows.indexed) _dataRow(r, i),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    const style = TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.acier, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFFEDF0F2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('AFFAIRE', style: style)),
          Expanded(flex: 2, child: Text('CLIENT', style: style)),
          Expanded(flex: 4, child: Text('POINT DE CONTRÔLE', style: style)),
          Expanded(flex: 2, child: Text('STATUT', style: style)),
          Expanded(flex: 3, child: Text('VALIDÉ PAR', style: style)),
        ],
      ),
    );
  }

  Widget _dataRow(_AutoControleRow r, int index) {
    final (label, type) = _statutOf(r.point);
    return BoTableRow(
      border: const Border(top: BorderSide(color: AppColors.lignes)),
      backgroundColor: index.isOdd ? const Color(0xFFF7F8F9) : null,
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(r.chantierRef, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(flex: 2, child: Text(r.client, style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 4,
            child: Text(
              '${r.point.libelle}${r.point.critique ? ' (sécurité)' : ''}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(flex: 2, child: StatusBadge(label: label, type: type)),
          Expanded(
            flex: 3,
            child: Text(
              r.point.validePar != null
                  ? '${r.point.validePar} · ${DateFormat('dd/MM HH:mm').format(r.point.valideAt!)}'
                  : '—',
              style: const TextStyle(fontSize: 12.5, color: AppColors.acier),
            ),
          ),
        ],
      ),
    );
  }

  void _exporterCsv(List<_AutoControleRow> rows) {
    final buffer = StringBuffer();
    buffer.writeln(['Affaire', 'Client', 'Point de contrôle', 'Catégorie', 'Statut', 'Validé par', 'Validé le'].map(_csvField).join(';'));
    for (final r in rows) {
      final (label, _) = _statutOf(r.point);
      buffer.writeln([
        r.chantierRef,
        r.client,
        r.point.libelle,
        r.point.categorie,
        label,
        r.point.validePar ?? '',
        r.point.valideAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(r.point.valideAt!) : '',
      ].map(_csvField).join(';'));
    }
    downloadTextFile('auto-controles.csv', buffer.toString(), mimeType: 'text/csv;charset=utf-8');
  }

  String _csvField(String value) => '"${value.replaceAll('"', '""')}"';

  Future<void> _exporterPdf(List<_AutoControleRow> rows) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Auto-contrôles & qualité', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Affaire', 'Client', 'Point de contrôle', 'Statut', 'Validé par', 'Validé le'],
            data: [
              for (final r in rows)
                [
                  r.chantierRef,
                  r.client,
                  '${r.point.libelle}${r.point.critique ? ' (sécurité)' : ''}',
                  _statutOf(r.point).$1,
                  r.point.validePar ?? '—',
                  r.point.valideAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(r.point.valideAt!) : '—',
                ],
            ],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'auto-controles.pdf');
  }
}
