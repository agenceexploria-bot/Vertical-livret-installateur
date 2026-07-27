import 'package:flutter/material.dart';
import '../theme.dart';

enum StatusType {
  conforme,
  nonConforme,
  enCours,
  attente,
  factuel,
}

class StatusIndicator extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    bool showDot = true;

    switch (type) {
      case StatusType.conforme:
        dotColor = AppColors.vert;
        break;
      case StatusType.nonConforme:
        dotColor = AppColors.rouge;
        break;
      case StatusType.enCours:
        dotColor = AppColors.orange;
        break;
      case StatusType.attente:
        dotColor = AppColors.acierClair;
        break;
      case StatusType.factuel:
        dotColor = Colors.transparent;
        showDot = false;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: dotColor.withValues(alpha: 0.65), blurRadius: 8, spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: type == StatusType.attente || type == StatusType.factuel
                      ? AppColors.acierClair
                      : AppColors.acier,
                ),
          ),
        ),
      ],
    );
  }
}
