import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class BoPanel extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BoPanel({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.blanc,
        border: Border.all(color: AppColors.lignes),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.acier,
              ),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

class BoKv extends StatelessWidget {
  final String label;
  final Widget value;

  const BoKv({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.acier)),
          value,
        ],
      ),
    );
  }
}
