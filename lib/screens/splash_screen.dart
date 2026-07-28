import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/widgets/vertical_logo.dart';

/// Premier écran affiché au lancement — mobile natif uniquement (voir
/// router.dart, jamais l'initialLocation sur Web). Laisse le logo respirer le
/// temps que l'app démarre, puis redirige vers '/'. La logique "installateur
/// vs back-office vs déjà connecté" n'est pas dupliquée ici : elle est
/// entièrement gérée par le `redirect` de GoRouter, que ce '/' déclenche
/// normalement.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const double _logoSize = 96;
  static const double _glowSize = 168;

  // Entrée : zoom doux + fondu, avec un léger overshoot (easeOutBack) pour un
  // rendu plus vivant qu'un simple linéaire.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _entranceFade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  late final Animation<double> _entranceScale = Tween<double>(begin: 0.6, end: 1.0).animate(
    CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack),
  );

  // Respiration continue une fois l'entrée terminée (logo + halo qui pulsent
  // doucement) — inspiré du léger pulse au lancement d'Instagram, pour un
  // écran vivant plutôt qu'un logo figé.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
  );
  late final Animation<double> _glowOpacity = Tween<double>(begin: 0.15, end: 0.4).animate(
    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
  );

  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _entrance.forward().whenComplete(() {
      if (mounted) _pulse.repeat(reverse: true);
    });
    // Durée fixe indépendante de l'animation — au moins 3 secondes d'affichage
    // pour laisser l'effet (entrée + une respiration complète) bien visible,
    // même si l'appareil est lent et que l'entrée n'est pas terminée.
    _redirectTimer = Timer(const Duration(milliseconds: 3400), () {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Center(
        child: FadeTransition(
          opacity: _entranceFade,
          child: ScaleTransition(
            scale: _entranceScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    return SizedBox(
                      height: _glowSize,
                      width: _glowSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: _pulseScale.value,
                            child: Container(
                              width: _glowSize,
                              height: _glowSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.orange.withValues(alpha: _glowOpacity.value),
                                    AppColors.orange.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: _pulseScale.value,
                            child: const SizedBox(height: _logoSize, child: VerticalLogo(height: _logoSize)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Vertical',
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.encre,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monte-Charges',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.acier,
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
