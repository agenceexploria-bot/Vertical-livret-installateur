import 'package:flutter/material.dart';
import '../theme.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final bool useScaffold;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.useScaffold = true,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Layout pour simuler un écran mobile centré sur le Web
    Widget mobileScreen = Scaffold(
      backgroundColor: backgroundColor ?? AppColors.fond,
      appBar: appBar,
      body: child,
      bottomNavigationBar: bottomNavigationBar,
    );

    if (useScaffold) {
      // La contrainte de largeur seule ne borne pas la hauteur (elle reste
      // à double.infinity par défaut) : sur le web, ce Scaffold imbriqué
      // peut alors se retrouver avec une hauteur non bornée et déborder.
      // On fixe donc explicitement la hauteur du cadre simulé sur celle du
      // viewport.
      final viewportHeight = MediaQuery.sizeOf(context).height;
      return Scaffold(
        backgroundColor: const Color(0xFFE5E5E5), // Fond gris extérieur
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500, maxHeight: viewportHeight),
            child: SizedBox(
              height: viewportHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: mobileScreen,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: child,
      ),
    );
  }
}
