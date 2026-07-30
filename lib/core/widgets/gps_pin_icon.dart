import 'package:flutter/material.dart';

/// Icône "carte + repère" pour les boutons GPS — une base de carte pliée
/// (dégradé bleu eau / beige-jaune zones et itinéraires) surmontée d'un pin
/// de localisation rouge, pour que l'action soit reconnaissable au premier
/// coup d'œil plutôt qu'une simple icône monochrome.
class GpsPinIcon extends StatelessWidget {
  final double size;

  const GpsPinIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.9,
              height: size * 0.7,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFAEE1F9), Color(0xFFF5E1A4)],
                ),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
          Positioned(
            top: -size * 0.12,
            child: Icon(Icons.location_on, size: size * 0.8, color: const Color(0xFFE11F1B)),
          ),
        ],
      ),
    );
  }
}
