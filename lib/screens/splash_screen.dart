import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/widgets/vertical_logo.dart';

/// Premier écran affiché au lancement (mobile et web) — laisse le logo
/// respirer le temps que l'app démarre, puis redirige vers '/'. La logique
/// "installateur mobile vs back-office web vs déjà connecté" n'est pas
/// dupliquée ici : elle est entièrement gérée par le `redirect` de GoRouter,
/// que ce '/' déclenche normalement (voir router.dart).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
  );

  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    // Durée fixe indépendante de l'animation — même si l'appareil est lent et
    // que le fondu/zoom n'est pas terminé, l'utilisateur n'attend jamais plus
    // de 3 secondes avant d'atterrir sur le bon écran.
    _redirectTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.encre,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 96, child: VerticalLogo(height: 96, onDarkBackground: true)),
                const SizedBox(height: 20),
                Text(
                  'Vertical',
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monte-Charges',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.acierClair,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
