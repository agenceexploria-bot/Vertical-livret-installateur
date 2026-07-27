import 'package:flutter/material.dart';
import '../theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, AppColors.fond],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.encre.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: padding ?? const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }
}
