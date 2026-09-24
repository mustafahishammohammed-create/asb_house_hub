import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// =============================================================================
// 1. LIGHTWEIGHT REAL-TIME 3D VECTOR & POLYGON MESH ENGINE
// =============================================================================

/// 3D Vector for real-time vertex transformations
class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);

  V3 cross(V3 o) => V3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;

  double get length => math.sqrt(x * x + y * y + z * z);

  V3 normalized() {
    final len = length;
    if (len <= 0.000001) return const V3(0, 0, 1);
    return V3(x / len, y / len, z / len);
  }
}

/// A 3D polygon facet with indices, material tone, and optional eye/gem illumination
class Face3D {
  final List<int> indices;
  final Color baseColor;
  final bool isEye;
  final bool isEmissive;
  final bool isPlinth;

  const Face3D(
    this.indices,
    this.baseColor, {
    this.isEye = false,
    this.isEmissive = false,
    this.isPlinth = false,
  });
}

/// Complete volumetric 3D mesh model
class Mesh3D {
  final List<V3> vertices;
  final List<Face3D> faces;

  const Mesh3D({required this.vertices, required this.faces});
}

/// Material finishes for authentic physical collectible rendering
enum MascotMaterialFinish {
  houseChroma,
  imperialGold,
  darkObsidian,
  astralCrystal,
}

// =============================================================================
// 2. PROCEDURAL 3D MESH BUILDERS FOR THE 4 HOUSE MASCOTS
// =============================================================================

class Mascot3DMeshes {
  /// Adds a sculpted 8-sided trophy plinth base directly to any 3D mascot mesh
  static void _attachOctagonalPlinth(
    List<V3> vertices,
    List<Face3D> faces,
    Color plinthTop,
    Color plinthBevel,
    Color plinthSide,
    Color sealColor,
  ) {
    final baseOffset = vertices.length;

    // Plinth heights & radii
    const topY = 82.0;
    const topR = 64.0;
    const bevelY = 94.0;
    const bevelR = 76.0;
    const bottomY = 110.0;
    const bottomR = 86.0;

    // Generate 8 vertices per tier
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * math.pi / 180;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // Top ring (0 to 7)
      vertices.add(V3(cosA * topR, topY, sinA * topR));
      // Bevel ring (8 to 15)
      vertices.add(V3(cosA * bevelR, bevelY, sinA * bevelR));
      // Bottom ring (16 to 23)
      vertices.add(V3(cosA * bottomR, bottomY, sinA * bottomR));
    }

    // Plinth top center & bottom center
    final topCenterIdx = vertices.length;
    vertices.add(const V3(0, topY, 0));
    final bottomCenterIdx = vertices.length;
    vertices.add(const V3(0, bottomY, 0));

    // Plinth front seal medallion vertices
    final sealIdx = vertices.length;
    vertices.add(const V3(-18, 97, 83));
    vertices.add(const V3(0, 89, 85));
    vertices.add(const V3(18, 97, 83));
    vertices.add(const V3(0, 105, 85));

    // 1. Top triangular fan faces
    for (int i = 0; i < 8; i++) {
      final next = (i + 1) % 8;
      final i0 = baseOffset + (i * 3);
      final i1 = baseOffset + (next * 3);
      faces.add(Face3D([topCenterIdx, i0, i1], plinthTop, isPlinth: true));
    }

    // 2. Upper bevel quads
    for (int i = 0; i < 8; i++) {
      final next = (i + 1) % 8;
      final t0 = baseOffset + (i * 3);
      final t1 = baseOffset + (next * 3);
      final b0 = baseOffset + (i * 3) + 1;
      final b1 = baseOffset + (next * 3) + 1;
      faces.add(Face3D([t0, t1, b1, b0], plinthBevel, isPlinth: true));
    }

    // 3. Lower vertical side quads
    for (int i = 0; i < 8; i++) {
      final next = (i + 1) % 8;
      final t0 = baseOffset + (i * 3) + 1;
      final t1 = baseOffset + (next * 3) + 1;
      final b0 = baseOffset + (i * 3) + 2;
      final b1 = baseOffset + (next * 3) + 2;
      faces.add(Face3D([t0, t1, b1, b0], plinthSide, isPlinth: true));
    }

    // 4. Front house seal medallion
    faces.add(Face3D(
      [sealIdx, sealIdx + 1, sealIdx + 2, sealIdx + 3],
      sealColor,
      isEmissive: true,
      isPlinth: true,
    ));

    // 5. Bottom ground cap
    for (int i = 0; i < 8; i++) {
      final next = (i + 1) % 8;
      final i0 = baseOffset + (i * 3) + 2;
      final i1 = baseOffset + (next * 3) + 2;
      faces.add(Face3D([bottomCenterIdx, i1, i0], plinthSide, isPlinth: true));
    }
  }

  // ---------------------------------------------------------------------------
  // 1. IGNIS THE CRIMSON DRAGON (RUBY) - Full Volumetric 3D Dragon Figurine
  // ---------------------------------------------------------------------------
  static Mesh3D buildDragonMesh() {
    const crimsonCore = Color(0xFF7A0512);
    const crimsonMid = Color(0xFFD31027);
    const crimsonBright = Color(0xFFFF3B56);
    const dragonGold = Color(0xFFFFD54F);
    const hornDark = Color(0xFF380308);
    const hornTip = Color(0xFFFFA39E);
    const eyeAmber = Color(0xFFFFE600);
    const plinthTop = Color(0xFF343E54);
    const plinthDark = Color(0xFF1E232F);
    const plinthBevel = Color(0xFF283142);

    final vertices = <V3>[
      // 0: Snout tip
      const V3(0, 8, 88),
      // 1, 2: Snout top bridge L/R
      const V3(-16, 0, 76),
      const V3(16, 0, 76),
      // 3, 4: Snout bottom jaw L/R
      const V3(-14, 22, 66),
      const V3(14, 22, 66),
      // 5: Mid muzzle center ridge
      const V3(0, -12, 56),
      // 6, 7: Mid muzzle sides L/R
      const V3(-24, -8, 52),
      const V3(24, -8, 52),
      // 8: Forehead center apex
      const V3(0, -26, 38),
      // 9, 10: Eye positions L/R
      const V3(-26, -18, 44),
      const V3(26, -18, 44),
      // 11, 12: Brow hornlets L/R
      const V3(-32, -30, 28),
      const V3(32, -30, 28),
      // 13: Crown crest dorsal spine
      const V3(0, -44, 18),
      // 14, 15: Horn roots L/R
      const V3(-26, -40, 10),
      const V3(26, -40, 10),
      // 16, 17: Horn mid curve L/R
      const V3(-48, -62, -22),
      const V3(48, -62, -22),
      // 18, 19: Horn sharp tips L/R
      const V3(-72, -92, -54),
      const V3(72, -92, -54),
      // 20: Chin underside
      const V3(0, 32, 58),
      // 21, 22: Jaw corners L/R
      const V3(-32, 22, 18),
      const V3(32, 22, 18),
      // 23: Throat front
      const V3(0, 48, 24),
      // 24: Neck dorsal spine
      const V3(0, -18, -32),
      // 25, 26: Neck flanks L/R
      const V3(-38, 18, -14),
      const V3(38, 18, -14),
      // 27: Muscular Chest breastplate
      const V3(0, 74, 14),
      // 28, 29: Shoulders L/R
      const V3(-60, 64, -20),
      const V3(60, 64, -20),
      // 30: Spine lower base
      const V3(0, 52, -48),

      // 31-33: Left wing bone strut & membrane
      const V3(-92, -25, -45),
      const V3(-138, -66, -72),
      const V3(-85, 45, -36),

      // 34-36: Right wing bone strut & membrane
      const V3(92, -25, -45),
      const V3(138, -66, -72),
      const V3(85, 45, -36),

      // 37-39: Left Talons gripping plinth (front left)
      const V3(-44, 76, 32),
      const V3(-48, 82, 50),
      const V3(-34, 82, 48),

      // 40-42: Right Talons gripping plinth (front right)
      const V3(44, 76, 32),
      const V3(48, 82, 50),
      const V3(34, 82, 48),

      // 43-46: Curled dragon tail sweeping around right plinth
      const V3(15, 68, -45),
      const V3(48, 76, -26),
      const V3(58, 80, 10),
      const V3(64, 78, 36), // Spade tip
    ];

    final faces = <Face3D>[
      // Snout front facets
      const Face3D([0, 1, 5], crimsonBright),
      const Face3D([0, 5, 2], crimsonBright),
      const Face3D([0, 3, 1], crimsonMid),
      const Face3D([0, 2, 4], crimsonMid),
      const Face3D([0, 4, 20, 3], crimsonCore),

      // Muzzle & Bridge
      const Face3D([1, 6, 5], crimsonMid),
      const Face3D([5, 7, 2], crimsonMid),
      const Face3D([1, 3, 21, 6], crimsonCore),
      const Face3D([2, 7, 22, 4], crimsonCore),

      // Eyes (Luminescent Gemstones)
      const Face3D([6, 9, 8, 5], eyeAmber, isEye: true),
      const Face3D([5, 8, 10, 7], eyeAmber, isEye: true),

      // Forehead & Brow Ridges
      const Face3D([8, 11, 13], crimsonBright),
      const Face3D([8, 13, 12], crimsonBright),
      const Face3D([9, 11, 8], crimsonMid),
      const Face3D([7, 10, 12], crimsonMid),

      // Swept Dragon Horns Left (Volumetric)
      const Face3D([11, 14, 16], hornDark),
      const Face3D([14, 16, 18], hornTip, isEmissive: true),
      const Face3D([14, 13, 16], dragonGold),

      // Swept Dragon Horns Right (Volumetric)
      const Face3D([12, 17, 15], hornDark),
      const Face3D([15, 17, 19], hornTip, isEmissive: true),
      const Face3D([13, 15, 17], dragonGold),

      // Jaw & Throat
      const Face3D([20, 4, 22, 23], crimsonCore),
      const Face3D([20, 23, 21, 3], crimsonCore),
      const Face3D([23, 22, 26, 27], crimsonMid),
      const Face3D([23, 27, 25, 21], crimsonMid),

      // Chest Breastplate (Golden Dragon Plates)
      const Face3D([27, 26, 29], dragonGold),
      const Face3D([27, 28, 25], dragonGold),

      // Neck & Spine
      const Face3D([13, 24, 14], crimsonCore),
      const Face3D([13, 15, 24], crimsonCore),
      const Face3D([24, 25, 30], crimsonCore),
      const Face3D([24, 30, 26], crimsonCore),

      // Left Wing Structure (3D Depth)
      const Face3D([25, 28, 33, 31], crimsonMid),
      const Face3D([31, 33, 32], crimsonBright),
      const Face3D([14, 24, 31], hornDark),

      // Right Wing Structure (3D Depth)
      const Face3D([26, 34, 36, 29], crimsonMid),
      const Face3D([34, 35, 36], crimsonBright),
      const Face3D([15, 34, 24], hornDark),

      // Left Claw Grip
      const Face3D([25, 37, 28], crimsonMid),
      const Face3D([37, 38, 39], dragonGold),

      // Right Claw Grip
      const Face3D([26, 29, 40], crimsonMid),
      const Face3D([40, 41, 42], dragonGold),

      // Curled Dragon Tail
      const Face3D([30, 43, 44], crimsonCore),
      const Face3D([43, 44, 45], crimsonMid),
      const Face3D([44, 45, 46], dragonGold, isEmissive: true),
    ];

    // Attach sculpted physical plinth base
    _attachOctagonalPlinth(vertices, faces, plinthTop, plinthBevel, plinthDark, crimsonBright);

    return Mesh3D(vertices: vertices, faces: faces);
  }

  // ---------------------------------------------------------------------------
  // 2. ZEPHYR THE TEMPEST GRYPHON (SAPPHIRE) - Full Volumetric 3D Gryphon Figurine
  // ---------------------------------------------------------------------------
  static Mesh3D buildGryphonMesh() {
    const sapphireDark = Color(0xFF081C54);
    const sapphireMid = Color(0xFF0066FF);
    const sapphireBright = Color(0xFF38BDF8);
    const stormSilver = Color(0xFFE2E8F0);
    const beakGold = Color(0xFFFFD54F);
    const eyeCyan = Color(0xFF00F5FF);
    const plinthTop = Color(0xFF2C3B55);
    const plinthDark = Color(0xFF141A28);
    const plinthBevel = Color(0xFF202A3D);

    final vertices = <V3>[
      // 0: Curved raptor beak tip (protrudes downward and forward)
      const V3(0, 24, 90),
      // 1: Beak top bridge
      const V3(0, -6, 78),
      // 2, 3: Beak nostril cere L/R
      const V3(-16, 6, 66),
      const V3(16, 6, 66),
      // 4: Beak lower cutting edge
      const V3(0, 14, 70),
      // 5: Avian forehead ridge
      const V3(0, -28, 48),
      // 6, 7: Eyebrow crowns L/R
      const V3(-26, -24, 42),
      const V3(26, -24, 42),
      // 8, 9: Piercing Gryphon Eyes L/R
      const V3(-24, -12, 46),
      const V3(24, -12, 46),
      // 10: Crown feather apex
      const V3(0, -62, 18),
      // 11, 12: Feathered ear tufts L/R
      const V3(-52, -78, -26),
      const V3(52, -78, -26),
      // 13, 14: Ear tuft mid L/R
      const V3(-32, -45, 6),
      const V3(32, -45, 6),
      // 15: Lower throat / Chin
      const V3(0, 36, 48),
      // 16, 17: Ruff feather flanks L/R
      const V3(-42, 22, 10),
      const V3(42, 22, 10),
      // 18: Raptor breastplate
      const V3(0, 72, 16),
      // 19, 20: Wings elbows L/R
      const V3(-95, -22, -42),
      const V3(95, -22, -42),
      // 21, 22: Wing razor tips L/R
      const V3(-138, -58, -65),
      const V3(138, -58, -65),
      // 23, 24: Lower wing feathers L/R
      const V3(-112, 36, -35),
      const V3(112, 36, -35),
      // 25: Dorsal spine back
      const V3(0, -15, -34),
      // 26, 27: Shoulders L/R
      const V3(-58, 62, -22),
      const V3(58, 62, -22),

      // 28-30: Left Gryphon Talons clutching plinth
      const V3(-42, 74, 30),
      const V3(-46, 82, 48),
      const V3(-32, 82, 46),

      // 31-33: Right Gryphon Talons clutching plinth
      const V3(42, 74, 30),
      const V3(46, 82, 48),
      const V3(32, 82, 46),

      // 34-36: Feathered Gryphon Tail curling around plinth
      const V3(10, 68, -42),
      const V3(45, 76, -24),
      const V3(55, 80, 18),
    ];

    final faces = <Face3D>[
      // Curved Golden Beak
      const Face3D([0, 1, 2], beakGold),
      const Face3D([0, 3, 1], beakGold),
      const Face3D([0, 2, 4], beakGold),
      const Face3D([0, 4, 3], beakGold),

      // Eyebrows & Forehead
      const Face3D([1, 5, 2], stormSilver),
      const Face3D([1, 3, 5], stormSilver),
      const Face3D([5, 6, 2], sapphireMid),
      const Face3D([5, 3, 7], sapphireMid),

      // Glowing Cyan Laser Eyes
      const Face3D([2, 6, 8], eyeCyan, isEye: true),
      const Face3D([3, 9, 7], eyeCyan, isEye: true),

      // Feathered Ear Tufts / Crest
      const Face3D([5, 10, 6], stormSilver),
      const Face3D([5, 7, 10], stormSilver),
      const Face3D([6, 13, 11], sapphireBright),
      const Face3D([7, 12, 14], sapphireBright),
      const Face3D([10, 13, 11], sapphireDark),
      const Face3D([10, 12, 14], sapphireDark),

      // Throat & Chin
      const Face3D([4, 15, 2], sapphireDark),
      const Face3D([4, 3, 15], sapphireDark),
      const Face3D([15, 16, 18], stormSilver),
      const Face3D([15, 18, 17], stormSilver),

      // Breastplate
      const Face3D([18, 16, 26], sapphireMid),
      const Face3D([18, 27, 17], sapphireMid),

      // Eagle Wings
      const Face3D([16, 19, 23, 26], sapphireDark),
      const Face3D([19, 21, 23], sapphireBright),
      const Face3D([17, 27, 24, 20], sapphireDark),
      const Face3D([20, 24, 22], sapphireBright),

      // Dorsal spine
      const Face3D([10, 25, 13], sapphireDark),
      const Face3D([10, 14, 25], sapphireDark),

      // Left Talons
      const Face3D([16, 28, 26], sapphireMid),
      const Face3D([28, 29, 30], beakGold),

      // Right Talons
      const Face3D([17, 27, 31], sapphireMid),
      const Face3D([31, 32, 33], beakGold),

      // Curled Feathered Tail
      const Face3D([26, 34, 35], sapphireDark),
      const Face3D([34, 35, 36], stormSilver, isEmissive: true),
    ];

    _attachOctagonalPlinth(vertices, faces, plinthTop, plinthBevel, plinthDark, sapphireBright);

    return Mesh3D(vertices: vertices, faces: faces);
  }

  // ---------------------------------------------------------------------------
  // 3. SYLVA THE TITAN WOLF (EMERALD) - Full Volumetric 3D Direwolf Figurine
  // ---------------------------------------------------------------------------
  static Mesh3D buildWolfMesh() {
    const emeraldDark = Color(0xFF092E10);
    const emeraldMid = Color(0xFF1B5E20);
    const emeraldBright = Color(0xFF4CAF50);
    const mossSilver = Color(0xFFC8E6C9);
    const noseBlack = Color(0xFF0D2212);
    const eyeJade = Color(0xFF00FF7F);
    const plinthTop = Color(0xFF263D2B);
    const plinthDark = Color(0xFF121E14);
    const plinthBevel = Color(0xFF1B2E20);

    final vertices = <V3>[
      // 0: Nose tip
      const V3(0, 14, 92),
      // 1: Snout bridge top
      const V3(0, -2, 76),
      // 2, 3: Snout sides L/R
      const V3(-18, 12, 68),
      const V3(18, 12, 68),
      // 4: Lower jaw / chin
      const V3(0, 28, 64),
      // 5: Forehead center
      const V3(0, -22, 44),
      // 6, 7: Wolf brow ridges L/R
      const V3(-26, -18, 38),
      const V3(26, -18, 38),
      // 8, 9: Glowing Jade Eyes L/R
      const V3(-22, -10, 44),
      const V3(22, -10, 44),
      // 10: Skull Crown
      const V3(0, -40, 20),
      // 11, 12: Upright wolf ear tips L/R
      const V3(-48, -88, -15),
      const V3(48, -88, -15),
      // 13, 14: Ear outer bases L/R
      const V3(-36, -42, 6),
      const V3(36, -42, 6),
      // 15, 16: Ear inner bases L/R
      const V3(-16, -42, 14),
      const V3(16, -42, 14),
      // 17, 18: Flared wolf ruff fur tips L/R
      const V3(-78, 14, -8),
      const V3(78, 14, -8),
      // 19, 20: Lower ruff fur tips L/R
      const V3(-96, 46, -24),
      const V3(96, 46, -24),
      // 21: Throat & chin front
      const V3(0, 44, 28),
      // 22: Muscular titan chest
      const V3(0, 78, 18),
      // 23, 24: Titan shoulders L/R
      const V3(-56, 66, -28),
      const V3(56, 66, -28),
      // 25: Dorsal spine back
      const V3(0, 20, -42),

      // 26-28: Left Wolf Paw planted on plinth
      const V3(-40, 74, 30),
      const V3(-44, 82, 48),
      const V3(-30, 82, 46),

      // 29-31: Right Wolf Paw planted on plinth
      const V3(40, 74, 30),
      const V3(44, 82, 48),
      const V3(30, 82, 46),

      // 32-34: Bushy Wolf Tail curled along plinth side
      const V3(12, 68, -42),
      const V3(48, 76, -24),
      const V3(56, 80, 16),
    ];

    final faces = <Face3D>[
      // Wolf Snout & Nose
      const Face3D([0, 1, 2], noseBlack),
      const Face3D([0, 3, 1], noseBlack),
      const Face3D([0, 2, 4], emeraldDark),
      const Face3D([0, 4, 3], emeraldDark),

      // Muzzle Bridge to Forehead
      const Face3D([1, 5, 2], emeraldMid),
      const Face3D([1, 3, 5], emeraldMid),
      const Face3D([2, 5, 6], emeraldMid),
      const Face3D([3, 7, 5], emeraldMid),

      // Glowing Jade Eyes
      const Face3D([2, 6, 8], eyeJade, isEye: true),
      const Face3D([3, 9, 7], eyeJade, isEye: true),

      // Upright Titan Ears Left
      const Face3D([10, 15, 11], mossSilver),
      const Face3D([15, 13, 11], emeraldBright),
      const Face3D([10, 11, 13], emeraldDark),

      // Upright Titan Ears Right
      const Face3D([10, 11, 16], mossSilver),
      const Face3D([16, 12, 14], emeraldBright),
      const Face3D([10, 14, 12], emeraldDark),

      // Flared Alpha Wolf Ruff Mane
      const Face3D([6, 13, 17], emeraldBright),
      const Face3D([7, 18, 14], emeraldBright),
      const Face3D([17, 19, 21], mossSilver),
      const Face3D([18, 21, 20], mossSilver),

      // Throat & Muscular Chest
      const Face3D([4, 21, 2], emeraldDark),
      const Face3D([4, 3, 21], emeraldDark),
      const Face3D([21, 19, 23, 22], emeraldMid),
      const Face3D([21, 22, 24, 20], emeraldMid),

      // Left Paw
      const Face3D([23, 26, 22], emeraldMid),
      const Face3D([26, 27, 28], mossSilver),

      // Right Paw
      const Face3D([24, 22, 29], emeraldMid),
      const Face3D([29, 30, 31], mossSilver),

      // Tail
      const Face3D([25, 32, 33], emeraldDark),
      const Face3D([32, 33, 34], emeraldBright),
    ];

    _attachOctagonalPlinth(vertices, faces, plinthTop, plinthBevel, plinthDark, emeraldBright);

    return Mesh3D(vertices: vertices, faces: faces);
  }

  // ---------------------------------------------------------------------------
  // 4. SOLIS THE GOLDEN CHIMERA (TOPAZ) - Full Volumetric 3D Chimera Figurine
  // ---------------------------------------------------------------------------
  static Mesh3D buildChimeraMesh() {
    const sunGoldDark = Color(0xFF5E3B00);
    const sunGoldMid = Color(0xFFFFB300);
    const sunGoldBright = Color(0xFFFFE082);
    const imperialAmber = Color(0xFFE65100);
    const solarEye = Color(0xFFFFFFFF);
    const plinthTop = Color(0xFF45361D);
    const plinthDark = Color(0xFF1E180E);
    const plinthBevel = Color(0xFF332714);

    final vertices = <V3>[
      // 0: Lion nose tip
      const V3(0, 12, 84),
      // 1: Muzzle bridge
      const V3(0, -4, 72),
      // 2, 3: Whiskers muzzle pads L/R
      const V3(-20, 12, 68),
      const V3(20, 12, 68),
      // 4: Chin / Lower jaw
      const V3(0, 30, 60),
      // 5: Forehead brow center
      const V3(0, -22, 42),
      // 6, 7: Lion brows L/R
      const V3(-26, -16, 38),
      const V3(26, -16, 38),
      // 8, 9: Sovereign Solar Eyes L/R
      const V3(-22, -8, 45),
      const V3(22, -8, 45),
      // 10: Crown apex
      const V3(0, -38, 25),
      // 11, 12: Dual Chimera Horn tips L/R
      const V3(-55, -86, -18),
      const V3(55, -86, -18),
      // 13, 14: Horn roots L/R
      const V3(-24, -40, 12),
      const V3(24, -40, 12),
      // 15, 16: Top Solar Mane starburst rays
      const V3(0, -92, -5),
      const V3(-38, -82, -12),
      const V3(38, -82, -12),
      // 17, 18: Upper flank solar rays L/R
      const V3(-78, -54, -18),
      const V3(78, -54, -18),
      // 19, 20: Middle flank solar rays L/R
      const V3(-98, -8, -22),
      const V3(98, -8, -22),
      // 21, 22: Lower mane rays L/R
      const V3(-86, 38, -26),
      const V3(86, 38, -26),
      // 23: Lion beard ray front
      const V3(0, 58, 26),
      // 24: Sovereign gold breastplate
      const V3(0, 78, 16),
      // 25, 26: Imperial shoulders L/R
      const V3(-52, 70, -20),
      const V3(52, 70, -20),

      // 27-29: Left Lion Paw planted on plinth
      const V3(-38, 74, 30),
      const V3(-42, 82, 48),
      const V3(-28, 82, 46),

      // 30-32: Right Lion Paw planted on plinth
      const V3(38, 74, 30),
      const V3(42, 82, 48),
      const V3(28, 82, 46),

      // 33-35: Arching Chimera Tail
      const V3(12, 68, -42),
      const V3(46, 76, -24),
      const V3(56, 80, 16),
    ];

    final faces = <Face3D>[
      // Lion Muzzle & Nose
      const Face3D([0, 1, 2], imperialAmber),
      const Face3D([0, 3, 1], imperialAmber),
      const Face3D([0, 2, 4], sunGoldMid),
      const Face3D([0, 4, 3], sunGoldMid),

      // Forehead & Brow
      const Face3D([1, 5, 2], sunGoldMid),
      const Face3D([1, 3, 5], sunGoldMid),
      const Face3D([2, 5, 6], sunGoldDark),
      const Face3D([3, 7, 5], sunGoldDark),

      // Blazing Solar Eyes
      const Face3D([2, 6, 8], solarEye, isEye: true),
      const Face3D([3, 9, 7], solarEye, isEye: true),

      // Chimera Horns
      const Face3D([10, 13, 11], imperialAmber),
      const Face3D([10, 12, 14], imperialAmber),

      // Explosive 3D Solar Ray Mane (Facets angled in 3D around the head)
      const Face3D([10, 15, 13], sunGoldBright),
      const Face3D([10, 14, 15], sunGoldBright),
      const Face3D([13, 15, 17], sunGoldMid),
      const Face3D([14, 18, 15], sunGoldMid),
      const Face3D([6, 13, 17], sunGoldBright),
      const Face3D([7, 18, 14], sunGoldBright),
      const Face3D([17, 19, 21], sunGoldMid),
      const Face3D([18, 22, 20], sunGoldMid),

      // Beard & Breastplate
      const Face3D([4, 23, 2], imperialAmber),
      const Face3D([4, 3, 23], imperialAmber),
      const Face3D([23, 21, 25, 24], sunGoldBright),
      const Face3D([23, 24, 26, 22], sunGoldBright),

      // Left Lion Paw
      const Face3D([25, 27, 24], sunGoldMid),
      const Face3D([27, 28, 29], sunGoldBright),

      // Right Lion Paw
      const Face3D([26, 24, 30], sunGoldMid),
      const Face3D([30, 31, 32], sunGoldBright),

      // Chimera Tail
      const Face3D([25, 33, 34], sunGoldDark),
      const Face3D([33, 34, 35], imperialAmber, isEmissive: true),
    ];

    _attachOctagonalPlinth(vertices, faces, plinthTop, plinthBevel, plinthDark, sunGoldBright);

    return Mesh3D(vertices: vertices, faces: faces);
  }
}

// =============================================================================
// 3. COMPLETE 3D MASCOT CODEX DATA MODEL
// =============================================================================

class MascotLoreData {
  final String houseId;
  final String name;
  final String title;
  final String beastSpecies;
  final String element;
  final String motto;
  final String battleCry;
  final String primaryEmoji;
  final String description;
  final String legendStory;
  final String sacredRelicTitle;
  final String sacredRelicDesc;
  final IconData sacredRelicIcon;
  final Color primaryColor;
  final Color accentColor;
  final Color glowColor;
  final Map<String, double> powerStats;
  final List<String> virtues;
  final String sacredRite;
  final Mesh3D mesh;

  const MascotLoreData({
    required this.houseId,
    required this.name,
    required this.title,
    required this.beastSpecies,
    required this.element,
    required this.motto,
    required this.battleCry,
    required this.primaryEmoji,
    required this.description,
    required this.legendStory,
    required this.sacredRelicTitle,
    required this.sacredRelicDesc,
    required this.sacredRelicIcon,
    required this.primaryColor,
    required this.accentColor,
    required this.glowColor,
    required this.powerStats,
    required this.virtues,
    required this.sacredRite,
    required this.mesh,
  });

  static List<MascotLoreData> get allMascots => [
        MascotLoreData(
          houseId: 'ruby',
          name: 'Ignis the Crimson Dragon',
          title: 'Sovereign of the Blazing Hearth',
          beastSpecies: 'Pyre-Forged Greatwyrm',
          element: 'Solar Flare & Molten Fury',
          motto: 'Courage, Honor & Unyielding Fire',
          battleCry: 'RUBY ROARS! IN FIRE WE CONQUER! 🔥',
          primaryEmoji: '🐉',
          description:
              'Forged in the heart of courage and relentless passion. Ignis embodies the fearless drive of Ruby House warriors who conquer every summit and never back down.',
          legendStory:
              'According to ASB founding chronicles, when the first collegiate championship was held in the northern mountains, a sudden blizzard threatened to extinguish the ceremony torch. Ignis descended from the volcanic peaks, breathing an eternal crimson ember into the hearth that burns to this day in Ruby Tower.',
          sacredRelicTitle: 'The Cinder Core Sceptre',
          sacredRelicDesc:
              'Carved from volcanic obsidian and bound with dragon-tempered red gold. Bestows +25% spirit surge during inter-house athletics and exam sprints.',
          sacredRelicIcon: Icons.fireplace_rounded,
          primaryColor: HouseColors.ruby,
          accentColor: const Color(0xFFFF7875),
          glowColor: const Color(0xFFFF2A4B),
          powerStats: const {
            'Elemental Power': 0.98,
            'Physical Might': 0.95,
            'Aerial Speed': 0.88,
            'Battle Wisdom': 0.84,
            'House Leadership': 0.96,
          },
          virtues: const [
            'Fearless Fortitude',
            'Relentless Passion',
            'Honor in Victory',
          ],
          sacredRite:
              'The Rite of the First Ember: Conferred upon scholars who show unmatched bravery by championing their team when the odds seem insurmountable.',
          mesh: Mascot3DMeshes.buildDragonMesh(),
        ),
        MascotLoreData(
          houseId: 'sapphire',
          name: 'Zephyr the Tempest Gryphon',
          title: 'Master of the Endless Azure Sky',
          beastSpecies: 'Celestial Storm Gryphon',
          element: 'Aero-Dynamic Gale & High Voltage',
          motto: 'Wisdom, Precision & Infallible Focus',
          battleCry: 'SAPPHIRE SOARS! WISDOM STRIKES TRUE! ⚡',
          primaryEmoji: '🦅',
          description:
              'Born in the calm before the thunder, Zephyr rules through razor-sharp intellect, analytical supremacy, and unwavering team precision.',
          legendStory:
              'Legend tells of the Great Debate of 1991, where the four houses contested the fundamental mathematics of the campus observatory. When all calculations stalled, Zephyr circled the dome in razor-sharp spirals, guiding the scholars to decipher the celestial alignments with breathtaking elegance.',
          sacredRelicTitle: 'The Aegis of Tempest Skies',
          sacredRelicDesc:
              'Forged from sky-iron and inlaid with star lapis lazuli. Vibrates with high-frequency cognitive clarity during STEM bowls and academic exhibitions.',
          sacredRelicIcon: Icons.electric_bolt_rounded,
          primaryColor: HouseColors.sapphire,
          accentColor: const Color(0xFF69C0FF),
          glowColor: const Color(0xFF2979FF),
          powerStats: const {
            'Elemental Power': 0.88,
            'Physical Might': 0.84,
            'Aerial Speed': 0.99,
            'Battle Wisdom': 0.99,
            'House Leadership': 0.92,
          },
          virtues: const [
            'Razor-Sharp Intellect',
            'Analytical Mastery',
            'Forensic Precision',
          ],
          sacredRite:
              'The Rite of the Zenith Flight: Conferred upon scholars who discover breakthrough solutions, excel in debate, and elevate house intellectual prestige.',
          mesh: Mascot3DMeshes.buildGryphonMesh(),
        ),
        MascotLoreData(
          houseId: 'emerald',
          name: 'Sylva the Titan Wolf',
          title: 'Guardian of the Verdant Forest',
          beastSpecies: 'Ancient Alpha Direwolf',
          element: 'Primal Earth & Enduring Roots',
          motto: 'Perseverance, Growth & Indomitable Might',
          battleCry: 'EMERALD STANDS! PACK RUNS ETERNAL! 🐺',
          primaryEmoji: '🐺',
          description:
              'Rooted in unshakeable resilience and relentless work ethic. Sylva defends the pack with loyal brotherhood and unstoppable momentum.',
          legendStory:
              'When the campus foundation expanded through the ancient woodlands, heavy timber and stone seemed impassable. Sylva led the pack to clear the roads shoulder-to-shoulder, proving that unified endurance and collective grit will outlast any mountain.',
          sacredRelicTitle: 'The Fang of the Ancient Oak',
          sacredRelicDesc:
              'Petrified elderwood harvested from the founding groves and ringed in sterling silver. Fortifies endurance, teamwork synergy, and attendance integrity.',
          sacredRelicIcon: Icons.eco_rounded,
          primaryColor: HouseColors.emerald,
          accentColor: const Color(0xFF95DE64),
          glowColor: const Color(0xFF00E676),
          powerStats: const {
            'Elemental Power': 0.92,
            'Physical Might': 0.97,
            'Aerial Speed': 0.90,
            'Battle Wisdom': 0.89,
            'House Leadership': 0.97,
          },
          virtues: const [
            'Unbreakable Loyalty',
            'Steadfast Resilience',
            'Relentless Growth',
          ],
          sacredRite:
              'The Rite of the Pack Vigil: Conferred upon scholars who sacrifice individual limelight to bolster their fellow classmates and keep house spirit unbreakable.',
          mesh: Mascot3DMeshes.buildWolfMesh(),
        ),
        MascotLoreData(
          houseId: 'topaz',
          name: 'Solis the Golden Chimera',
          title: 'Bringer of Dawn & Sovereign Sun',
          beastSpecies: 'Solar Lion-Dragon Chimera',
          element: 'Pure Solar Luminescence',
          motto: 'Radiance, Loyalty & Sovereign Glory',
          battleCry: 'TOPAZ SHINES! GOLDEN SUN ASCENDS! ☀️',
          primaryEmoji: '🦁',
          description:
              'Radiating warmth, sportsmanship, and electric brilliance. Solis illuminates every corridor with relentless optimism and supreme leadership.',
          legendStory:
              'During the darkest winter tournament in campus history, morale dwindled as clouds covered the stadium for three weeks. Solis roared from the quadrangle clocktower, summoning rays of golden sunlight that melted the frost and revitalized thousands of spectators.',
          sacredRelicTitle: 'The Sunforged Crown',
          sacredRelicDesc:
              'Minted from golden solstice meteoric ore. Emits an aura of infectious charisma, sportsmanship, and radiant house pride across every arena match.',
          sacredRelicIcon: Icons.stars_rounded,
          primaryColor: HouseColors.topaz,
          accentColor: const Color(0xFFFFD666),
          glowColor: const Color(0xFFFFC107),
          powerStats: const {
            'Elemental Power': 0.95,
            'Physical Might': 0.91,
            'Aerial Speed': 0.93,
            'Battle Wisdom': 0.91,
            'House Leadership': 0.98,
          },
          virtues: const [
            'Radiant Sportsmanship',
            'Supreme Optimism',
            'Charismatic Leadership',
          ],
          sacredRite:
              'The Rite of the Golden Dawn: Conferred upon scholars who uplift others, display exceptional sportsmanship on the pitch, and lead with warmth and joy.',
          mesh: Mascot3DMeshes.buildChimeraMesh(),
        ),
      ];

  static MascotLoreData forHouse(String house) {
    final lower = house.toLowerCase();
    return allMascots.firstWhere(
      (m) => m.houseId == lower,
      orElse: () => allMascots.first,
    );
  }
}

// =============================================================================
// 4. 3D PARTICLE MODEL
// =============================================================================

class _Mascot3DParticle {
  double x, y, z;
  double vx, vy, vz;
  double size;
  double opacity;
  double life;
  double maxLife;

  _Mascot3DParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.size,
    required this.opacity,
    required this.life,
    required this.maxLife,
  });
}

// =============================================================================
// 5. INTERACTIVE 3D MOVABLE MASCOT STAGE WIDGET
// =============================================================================

class Mascot3DStage extends StatefulWidget {
  final String userHouse;
  final String userName;
  final String scholarNo;

  const Mascot3DStage({
    super.key,
    required this.userHouse,
    required this.userName,
    required this.scholarNo,
  });

  @override
  State<Mascot3DStage> createState() => _Mascot3DStageState();
}

class _Mascot3DStageState extends State<Mascot3DStage>
    with TickerProviderStateMixin {
  late String _activeHouse;
  late MascotLoreData _currentMascot;

  // 3D Angles in radians
  double _rotX = 0.08;
  double _rotY = 0.0;
  double _zoomScale = 1.0;
  double _baseZoom = 1.0;
  bool _isAutoRotating = false;
  MascotMaterialFinish _currentFinish = MascotMaterialFinish.houseChroma;

  // Animation Controllers
  late final AnimationController _idleFloatController;
  late final AnimationController _altarSpinController;
  late final AnimationController _turntableController;
  late final AnimationController _roarController;
  late final AnimationController _springBackController;
  late Animation<double> _springAnimX;
  late Animation<double> _springAnimY;

  // 3D Particles
  final List<_Mascot3DParticle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _activeHouse = widget.userHouse.toLowerCase();
    _currentMascot = MascotLoreData.forHouse(_activeHouse);

    // Continuous idle floating / breathing bob
    _idleFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    // Altar pedestal runic ring rotation
    _altarSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    // Turntable 360° auto-spin controller
    _turntableController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        if (_isAutoRotating) {
          setState(() {
            _rotY = _turntableController.value * math.pi * 2;
          });
        }
      });

    // Kinetic Roar Shockwave Controller
    _roarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // Spring-back physics when releasing drag
    _springBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(() {
        setState(() {
          _rotX = _springAnimX.value;
          _rotY = _springAnimY.value;
        });
      });
    _springAnimX = const AlwaysStoppedAnimation(0.08);
    _springAnimY = const AlwaysStoppedAnimation(0.0);

    _initParticles();
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < 34; i++) {
      _particles.add(
        _Mascot3DParticle(
          x: (_rng.nextDouble() - 0.5) * 240,
          y: (_rng.nextDouble() - 0.5) * 220,
          z: (_rng.nextDouble() - 0.5) * 160,
          vx: (_rng.nextDouble() - 0.5) * 0.8,
          vy: -(_rng.nextDouble() * 0.8 + 0.3),
          vz: (_rng.nextDouble() - 0.5) * 0.8,
          size: _rng.nextDouble() * 3.5 + 2.0,
          opacity: _rng.nextDouble() * 0.6 + 0.2,
          life: _rng.nextDouble() * 60,
          maxLife: 60 + _rng.nextDouble() * 40,
        ),
      );
    }
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.y += p.vy;
      p.x += p.vx;
      p.z += p.vz;
      p.life += 1.0;
      if (p.life >= p.maxLife || p.y < -130) {
        p.x = (_rng.nextDouble() - 0.5) * 220;
        p.y = 80 + _rng.nextDouble() * 30;
        p.z = (_rng.nextDouble() - 0.5) * 140;
        p.life = 0;
        p.opacity = _rng.nextDouble() * 0.6 + 0.2;
      }
    }
  }

  @override
  void dispose() {
    _idleFloatController.dispose();
    _altarSpinController.dispose();
    _turntableController.dispose();
    _roarController.dispose();
    _springBackController.dispose();
    super.dispose();
  }

  void _switchMascot(String house) {
    if (_activeHouse == house) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeHouse = house;
      _currentMascot = MascotLoreData.forHouse(house);
      _rotX = 0.08;
      _rotY = 0.0;
      _zoomScale = 1.0;
      _isAutoRotating = false;
    });
    _turntableController.stop();
    _initParticles();
  }

  void _triggerRoar() {
    HapticFeedback.heavyImpact();
    _roarController.forward(from: 0.0);

    // Explosive particle burst outward
    for (final p in _particles) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = _rng.nextDouble() * 5.0 + 3.0;
      p.vx = math.cos(angle) * speed;
      p.vy = (math.sin(angle) * speed) - 1.5;
      p.vz = (_rng.nextDouble() - 0.5) * speed;
      p.opacity = 1.0;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(_currentMascot.primaryEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _currentMascot.battleCry,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: _currentMascot.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleAutoRotate() {
    HapticFeedback.lightImpact();
    setState(() {
      _isAutoRotating = !_isAutoRotating;
      if (_isAutoRotating) {
        _turntableController.repeat();
      } else {
        _turntableController.stop();
        _snapToAngle(0.08, 0.0);
      }
    });
  }

  void _snapToAngle(double targetX, double targetY) {
    _springAnimX = Tween<double>(begin: _rotX, end: targetX).animate(
      CurvedAnimation(parent: _springBackController, curve: Curves.easeOutBack),
    );
    _springAnimY = Tween<double>(begin: _rotY, end: targetY).animate(
      CurvedAnimation(parent: _springBackController, curve: Curves.easeOutBack),
    );
    _springBackController.forward(from: 0.0);
  }

  void _changeFinish(MascotMaterialFinish finish) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentFinish = finish;
    });
  }

  @override
  Widget build(BuildContext context) {
    _updateParticles();
    final mascot = _currentMascot;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FOUR GREAT HOUSES SELECTOR
          _buildHouseSelectorBar(),
          const SizedBox(height: 16),

          // 2. TRUE 3D VOLUMETRIC MASCOT STAGE (WITH SCULPTED PLINTH & 360 DEPTH)
          _buildTrue3DStage(mascot),
          const SizedBox(height: 12),

          // 3. MATERIAL FINISH SELECTOR (House Chroma, Imperial Gold, Dark Obsidian, Astral Crystal)
          _buildMaterialFinishSelector(mascot),
          const SizedBox(height: 14),

          // 4. 3D CAMERA ANGLE PRESETS (Front, 3/4 Hero, Profile, Back, Top)
          _buildCameraAnglePresets(),
          const SizedBox(height: 14),

          // 5. 3D CONTROL HUD (Turntable, Zoom, Reset, Roar)
          _build3DControlHud(mascot),
          const SizedBox(height: 20),

          // 6. MASCOT IDENTITY & BEAST NOBILITY
          _buildMascotHeaderCard(mascot),
          const SizedBox(height: 18),

          // 7. POWER ATTRIBUTES RADAR / BARS
          _buildMascotPowerStats(mascot),
          const SizedBox(height: 18),

          // 8. SACRED RELIC OF THE HOUSE ARCHIVES
          _buildSacredRelicCard(mascot),
          const SizedBox(height: 18),

          // 9. ANCIENT FOUNDING ERA CHRONICLES
          _buildLoreChroniclesCard(mascot),
          const SizedBox(height: 18),

          // 10. HOUSE VIRTUES & SACRED RITE
          _buildVirtuesAndRiteCard(mascot),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. HOUSE SELECTOR
  // ===========================================================================
  Widget _buildHouseSelectorBar() {
    final houses = [
      {'id': 'ruby', 'name': 'Ruby', 'emoji': '🐉', 'color': HouseColors.ruby},
      {'id': 'sapphire', 'name': 'Sapphire', 'emoji': '🦅', 'color': HouseColors.sapphire},
      {'id': 'emerald', 'name': 'Emerald', 'emoji': '🐺', 'color': HouseColors.emerald},
      {'id': 'topaz', 'name': 'Topaz', 'emoji': '🦁', 'color': HouseColors.topaz},
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: houses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final h = houses[index];
          final isSel = _activeHouse == h['id'];
          final color = h['color'] as Color;

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _switchMascot(h['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? color : const Color(0xFF101624),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSel ? Colors.white : Colors.white12,
                  width: isSel ? 1.5 : 1.0,
                ),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(h['emoji'] as String, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    h['name'] as String,
                    style: TextStyle(
                      color: isSel ? Colors.white : Colors.white70,
                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 2. TRUE 3D VOLUMETRIC MASCOT STAGE
  // ===========================================================================
  Widget _buildTrue3DStage(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      height: 420,
      decoration: BoxDecoration(
        color: const Color(0xFF03050A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: mascot.glowColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        gradient: RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 1.4,
          colors: [
            mascot.glowColor.withValues(alpha: 0.30),
            const Color(0xFF0C1322),
            const Color(0xFF020408),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.9),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: mascot.glowColor.withValues(alpha: 0.22),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: GestureDetector(
          onScaleStart: (_) {
            _baseZoom = _zoomScale;
          },
          onScaleUpdate: (details) {
            if (_isAutoRotating) {
              _isAutoRotating = false;
              _turntableController.stop();
            }
            _springBackController.stop();

            setState(() {
              // Multi-touch pinch zoom
              if (details.pointerCount > 1) {
                _zoomScale = (_baseZoom * details.scale).clamp(0.72, 1.95);
              } else {
                // Single-touch 360 degree 3D rotation
                _rotY += details.focalPointDelta.dx * 0.016;
                _rotX -= details.focalPointDelta.dy * 0.016;
                _rotX = _rotX.clamp(-0.85, 0.85);
              }
            });
          },
          onDoubleTap: _triggerRoar,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Swirling 3D Elemental Particles (Projected with 3D camera)
              Positioned.fill(
                child: CustomPaint(
                  painter: _Particles3DPainter(
                    particles: _particles,
                    glowColor: mascot.glowColor,
                    rotX: _rotX,
                    rotY: _rotY,
                  ),
                ),
              ),

              // 2. 3D Obsidian Altar Dais on Floor
              Positioned(
                bottom: 18,
                child: AnimatedBuilder(
                  animation: _altarSpinController,
                  builder: (context, _) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateX(1.15)
                        ..rotateZ(_altarSpinController.value * math.pi * 2),
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: mascot.glowColor.withValues(alpha: 0.65),
                            width: 2.0,
                          ),
                          gradient: RadialGradient(
                            colors: [
                              mascot.glowColor.withValues(alpha: 0.30),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: mascot.glowColor.withValues(alpha: 0.45),
                              blurRadius: 22,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _AltarRunicPainter(color: mascot.glowColor),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 3. Dynamic 3D Ground Shadow tracking mascot's 3D rotation and plinth
              Positioned(
                bottom: 24,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(
                    math.sin(_rotY) * 38,
                    -_rotX * 22,
                    0.0,
                  ),
                  child: Container(
                    width: 155,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.all(Radius.elliptical(155, 32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.95),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. REAL 3D POLYGONAL MESH STATUE & SCULPTED PLINTH
              AnimatedBuilder(
                animation: Listenable.merge([
                  _idleFloatController,
                  _roarController,
                ]),
                builder: (context, _) {
                  final floatVal = _idleFloatController.value;
                  final floatY = math.sin(floatVal * math.pi * 2) * 7.5;

                  // Roar scale & vibration pulse
                  final roarVal = _roarController.value;
                  final roarScale = 1.0 + (math.sin(roarVal * math.pi) * 0.18);
                  final shakeX = (roarVal > 0.0 && roarVal < 0.7)
                      ? (math.sin(roarVal * math.pi * 12) * 4.0)
                      : 0.0;

                  return Transform.translate(
                    offset: Offset(shakeX, floatY - 10),
                    child: Transform.scale(
                      scale: roarScale * _zoomScale,
                      child: SizedBox(
                        width: 340,
                        height: 340,
                        child: CustomPaint(
                          painter: _Mascot3DRendererPainter(
                            mesh: mascot.mesh,
                            rotX: _rotX,
                            rotY: _rotY,
                            glowColor: mascot.glowColor,
                            primaryColor: mascot.primaryColor,
                            finish: _currentFinish,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 5. Kinetic Roar Shockwave Ring
              AnimatedBuilder(
                animation: _roarController,
                builder: (context, _) {
                  final roarVal = _roarController.value;
                  if (roarVal <= 0.0 || roarVal >= 1.0) return const SizedBox.shrink();

                  final ringSize = 100.0 + (roarVal * 300.0);
                  final ringOpacity = (1.0 - roarVal).clamp(0.0, 1.0);

                  return Container(
                    width: ringSize,
                    height: ringSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: mascot.glowColor.withValues(alpha: ringOpacity * 0.95),
                        width: 4.0 * (1.0 - roarVal) + 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: mascot.glowColor.withValues(alpha: ringOpacity * 0.65),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 6. Interactive Hint Pill
              Positioned(
                top: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.threed_rotation_rounded, size: 14, color: mascot.accentColor),
                      const SizedBox(width: 6),
                      const Text(
                        'Full 3D Volumetric Model • Pinch to Zoom • Drag 360°',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 7. Zoom Level Indicator Floating Chip
              Positioned(
                bottom: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '${(_zoomScale * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. MATERIAL FINISH SELECTOR
  // ===========================================================================
  Widget _buildMaterialFinishSelector(MascotLoreData mascot) {
    final finishes = [
      {'finish': MascotMaterialFinish.houseChroma, 'label': 'Chroma', 'icon': Icons.palette_rounded},
      {'finish': MascotMaterialFinish.imperialGold, 'label': '24K Gold', 'icon': Icons.emoji_events_rounded},
      {'finish': MascotMaterialFinish.darkObsidian, 'label': 'Obsidian', 'icon': Icons.dark_mode_rounded},
      {'finish': MascotMaterialFinish.astralCrystal, 'label': 'Astral', 'icon': Icons.auto_awesome_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B101D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: finishes.map((f) {
          final isSel = _currentFinish == f['finish'];
          final finishEnum = f['finish'] as MascotMaterialFinish;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _changeFinish(finishEnum),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? mascot.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: mascot.glowColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      f['icon'] as IconData,
                      size: 13,
                      color: isSel ? Colors.white : Colors.white60,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      f['label'] as String,
                      style: TextStyle(
                        color: isSel ? Colors.white : Colors.white70,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // 4. CAMERA ANGLE PRESETS
  // ===========================================================================
  Widget _buildCameraAnglePresets() {
    final angles = [
      {'label': 'Front', 'icon': Icons.visibility_rounded, 'x': 0.08, 'y': 0.0},
      {'label': '3/4 Hero', 'icon': Icons.explore_rounded, 'x': 0.12, 'y': math.pi / 4},
      {'label': 'Profile', 'icon': Icons.swap_horiz_rounded, 'x': 0.08, 'y': math.pi / 2},
      {'label': 'Back Spine', 'icon': Icons.shield_moon_rounded, 'x': 0.08, 'y': math.pi},
      {'label': 'Top Down', 'icon': Icons.arrow_downward_rounded, 'x': 0.65, 'y': 0.0},
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: angles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final a = angles[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.selectionClick();
              if (_isAutoRotating) {
                _isAutoRotating = false;
                _turntableController.stop();
              }
              _snapToAngle(a['x'] as double, a['y'] as double);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF101624),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(a['icon'] as IconData, size: 13, color: Colors.white60),
                  const SizedBox(width: 5),
                  Text(
                    a['label'] as String,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 5. 3D CONTROL HUD (Turntable, Zoom +/- , Reset, Roar)
  // ===========================================================================
  Widget _build3DControlHud(MascotLoreData mascot) {
    return Row(
      children: [
        // 1. Turntable 360 Auto-Spin Toggle
        Expanded(
          flex: 4,
          child: OutlinedButton.icon(
            icon: Icon(
              _isAutoRotating ? Icons.pause_circle_filled_rounded : Icons.rotate_right_rounded,
              size: 18,
              color: _isAutoRotating ? Colors.amberAccent : Colors.white70,
            ),
            label: Text(
              _isAutoRotating ? 'Spinning' : '360° Spin',
              style: TextStyle(
                color: _isAutoRotating ? Colors.amberAccent : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: _isAutoRotating ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFF101624),
              side: BorderSide(
                color: _isAutoRotating ? Colors.amberAccent : Colors.white12,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _toggleAutoRotate,
          ),
        ),
        const SizedBox(width: 8),

        // Zoom -
        IconButton.outlined(
          icon: const Icon(Icons.remove_rounded, size: 18, color: Colors.white70),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF101624),
            side: const BorderSide(color: Colors.white12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {
              _zoomScale = (_zoomScale - 0.15).clamp(0.72, 1.95);
            });
          },
        ),
        const SizedBox(width: 4),

        // Zoom +
        IconButton.outlined(
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white70),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF101624),
            side: const BorderSide(color: Colors.white12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {
              _zoomScale = (_zoomScale + 0.15).clamp(0.72, 1.95);
            });
          },
        ),
        const SizedBox(width: 8),

        // 3. Reset View
        IconButton.outlined(
          icon: const Icon(Icons.center_focus_strong_rounded, size: 18, color: Colors.white70),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF101624),
            side: const BorderSide(color: Colors.white12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (_isAutoRotating) {
              _isAutoRotating = false;
              _turntableController.stop();
            }
            setState(() => _zoomScale = 1.0);
            _snapToAngle(0.08, 0.0);
          },
        ),
        const SizedBox(width: 8),

        // 4. Unleash Roar Button
        Expanded(
          flex: 4,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.volume_up_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Roar!',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mascot.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              shadowColor: mascot.glowColor.withValues(alpha: 0.5),
              elevation: 4,
            ),
            onPressed: _triggerRoar,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 6. MASCOT IDENTITY & BEAST NOBILITY
  // ===========================================================================
  Widget _buildMascotHeaderCard(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        gradient: RadialGradient(
          center: const Alignment(0.8, -0.6),
          radius: 1.4,
          colors: [
            mascot.glowColor.withValues(alpha: 0.16),
            const Color(0xFF111827),
            const Color(0xFF0A0E18),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mascot.primaryColor.withValues(alpha: 0.25),
                  border: Border.all(color: mascot.accentColor.withValues(alpha: 0.6), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(mascot.primaryEmoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mascot.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mascot.title.toUpperCase(),
                      style: TextStyle(
                        color: mascot.accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPillTag(Icons.pets_rounded, mascot.beastSpecies, mascot.accentColor),
              _buildPillTag(Icons.bolt_rounded, mascot.element, Colors.amberAccent),
              _buildPillTag(Icons.flag_rounded, '${mascot.houseId.toUpperCase()} HOUSE', Colors.white70),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            mascot.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. POWER ATTRIBUTES RADAR / BARS
  // ===========================================================================
  Widget _buildMascotPowerStats(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.query_stats_rounded, color: mascot.accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Mascot Power Attributes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...mascot.powerStats.entries.map((entry) {
            final pct = (entry.value * 100).toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$pct / 100',
                        style: TextStyle(
                          color: mascot.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: entry.value,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(mascot.primaryColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 8. SACRED RELIC OF THE HOUSE ARCHIVES
  // ===========================================================================
  Widget _buildSacredRelicCard(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withValues(alpha: 0.12),
            const Color(0xFF131A29),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Icon(mascot.sacredRelicIcon, color: Colors.amberAccent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SACRED HOUSE RELIC',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mascot.sacredRelicTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mascot.sacredRelicDesc,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 9. ANCIENT FOUNDING ERA CHRONICLES
  // ===========================================================================
  Widget _buildLoreChroniclesCard(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Founding Era Chronicles',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mascot.legendStory,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_quote_rounded, color: Colors.amberAccent, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mascot.motto,
                    style: const TextStyle(
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 10. HOUSE VIRTUES & SACRED RITE
  // ===========================================================================
  Widget _buildVirtuesAndRiteCard(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded, color: mascot.accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'House Virtues & Sacred Rite',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...mascot.virtues.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: mascot.accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      v,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(color: Colors.white12, height: 24),
          Text(
            mascot.sacredRite,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 6. REAL-TIME 3D POLYGONAL MESH PAINTER (DEPTH-SORTED & SHADED)
// =============================================================================

class _Mascot3DRendererPainter extends CustomPainter {
  final Mesh3D mesh;
  final double rotX;
  final double rotY;
  final Color glowColor;
  final Color primaryColor;
  final MascotMaterialFinish finish;

  static final V3 _lightDir = const V3(-0.4, -0.65, 0.7).normalized();

  _Mascot3DRendererPainter({
    required this.mesh,
    required this.rotX,
    required this.rotY,
    required this.glowColor,
    required this.primaryColor,
    required this.finish,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    const cameraDistance = 380.0;
    const fov = 420.0;

    // 1. Precalculate trigonometric rotation constants
    final cosY = math.cos(rotY);
    final sinY = math.sin(rotY);
    final cosX = math.cos(rotX);
    final sinX = math.sin(rotX);

    // 2. Transform vertices to rotated camera space & project to 2D
    final numVertices = mesh.vertices.length;
    final projPts = List<Offset>.filled(numVertices, Offset.zero);
    final rotVertices = List<V3>.filled(numVertices, const V3(0, 0, 0));

    for (int i = 0; i < numVertices; i++) {
      final v = mesh.vertices[i];
      // Y rotation
      final x1 = v.x * cosY + v.z * sinY;
      final z1 = -v.x * sinY + v.z * cosY;
      // X rotation
      final y2 = v.y * cosX - z1 * sinX;
      final z2 = v.y * sinX + z1 * cosX;

      rotVertices[i] = V3(x1, y2, z2);

      // Perspective projection
      final zCam = z2 + cameraDistance;
      final scale = fov / math.max(10.0, zCam);
      projPts[i] = Offset(center.dx + x1 * scale, center.dy + y2 * scale);
    }

    // 3. Process and depth-sort visible faces (Painter's Algorithm)
    final drawableFaces = <_DrawableFace>[];

    for (final face in mesh.faces) {
      if (face.indices.length < 3) continue;

      final p0 = projPts[face.indices[0]];
      final p1 = projPts[face.indices[1]];
      final p2 = projPts[face.indices[2]];

      // 2D Cross product for winding order (backface culling)
      final winding = (p1.dx - p0.dx) * (p2.dy - p0.dy) - (p1.dy - p0.dy) * (p2.dx - p0.dx);
      if (winding >= 0.0) continue; // Face pointing away from camera

      // 3D Normal vector calculation in camera space
      final v0 = rotVertices[face.indices[0]];
      final v1 = rotVertices[face.indices[1]];
      final v2 = rotVertices[face.indices[2]];

      final edge1 = v1 - v0;
      final edge2 = v2 - v0;
      final normal = edge1.cross(edge2).normalized();

      // Average depth (Z-buffer proxy)
      double avgZ = 0.0;
      for (final idx in face.indices) {
        avgZ += rotVertices[idx].z;
      }
      avgZ /= face.indices.length;

      // Directional diffuse + ambient lighting
      final nDotL = normal.dot(_lightDir);
      final diffuse = nDotL.clamp(0.0, 1.0);
      const ambient = 0.28;

      // Specular glint
      final viewDir = const V3(0, 0, 1);
      final halfVector = (_lightDir + viewDir).normalized();
      final spec = math.pow(normal.dot(halfVector).clamp(0.0, 1.0), 12).toDouble() * 0.45;

      // Determine face base color according to chosen material finish
      Color baseColor = face.baseColor;
      if (!face.isEye && !face.isPlinth) {
        final lum = face.baseColor.computeLuminance();
        switch (finish) {
          case MascotMaterialFinish.imperialGold:
            final v = (0.52 + (lum * 0.46)).clamp(0.0, 1.0);
            baseColor = HSVColor.fromAHSV(1.0, 42.0, 0.78, v).toColor();
            break;
          case MascotMaterialFinish.darkObsidian:
            final v = (0.15 + (lum * 0.35)).clamp(0.0, 1.0);
            baseColor = HSVColor.fromAHSV(1.0, 220.0, 0.28, v).toColor();
            break;
          case MascotMaterialFinish.astralCrystal:
            final v = (0.74 + (lum * 0.26)).clamp(0.0, 1.0);
            baseColor = HSVColor.fromAHSV(0.92, 195.0, 0.22, v).toColor();
            break;
          case MascotMaterialFinish.houseChroma:
            baseColor = face.baseColor;
            break;
        }
      }

      // Final illuminated color
      final Color shadedColor;
      if (face.isEye) {
        shadedColor = face.baseColor; // Self-illuminated gemstone eyes
      } else {
        final totalLight = (ambient + (diffuse * 0.72)).clamp(0.0, 1.0);
        shadedColor = Color.from(
          alpha: baseColor.a,
          red: (baseColor.r * totalLight + spec).clamp(0.0, 1.0),
          green: (baseColor.g * totalLight + spec).clamp(0.0, 1.0),
          blue: (baseColor.b * totalLight + spec).clamp(0.0, 1.0),
        );
      }

      drawableFaces.add(
        _DrawableFace(
          indices: face.indices,
          depth: avgZ,
          color: shadedColor,
          isEye: face.isEye,
          specular: spec,
        ),
      );
    }

    // Sort from furthest back to nearest front
    drawableFaces.sort((a, b) => b.depth.compareTo(a.depth));

    // 4. Render 3D polygons with metallic edge creases
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final face in drawableFaces) {
      final path = Path();
      for (int i = 0; i < face.indices.length; i++) {
        final pt = projPts[face.indices[i]];
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();

      // Draw facet fill
      fillPaint.color = face.color;
      canvas.drawPath(path, fillPaint);

      // Draw sharp metallic facet crease edge
      if (face.isEye) {
        // Eye radial glow
        final centerPt = projPts[face.indices[0]];
        final eyeGlow = Paint()
          ..color = face.color.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(centerPt, 5.0, eyeGlow);
      } else {
        edgePaint.color = Colors.white.withValues(alpha: 0.18 + (face.specular * 0.4).clamp(0.0, 0.4));
        canvas.drawPath(path, edgePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Mascot3DRendererPainter oldDelegate) {
    return oldDelegate.rotX != rotX ||
        oldDelegate.rotY != rotY ||
        oldDelegate.mesh != mesh ||
        oldDelegate.finish != finish ||
        oldDelegate.glowColor != glowColor;
  }
}

class _DrawableFace {
  final List<int> indices;
  final double depth;
  final Color color;
  final bool isEye;
  final double specular;

  _DrawableFace({
    required this.indices,
    required this.depth,
    required this.color,
    required this.isEye,
    required this.specular,
  });
}

// =============================================================================
// 7. 3D PROJECTED PARTICLE PAINTER
// =============================================================================

class _Particles3DPainter extends CustomPainter {
  final List<_Mascot3DParticle> particles;
  final Color glowColor;
  final double rotX;
  final double rotY;

  _Particles3DPainter({
    required this.particles,
    required this.glowColor,
    required this.rotX,
    required this.rotY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const cameraDistance = 380.0;
    const fov = 420.0;

    final cosY = math.cos(rotY);
    final sinY = math.sin(rotY);
    final cosX = math.cos(rotX);
    final sinX = math.sin(rotX);

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final x1 = p.x * cosY + p.z * sinY;
      final z1 = -p.x * sinY + p.z * cosY;
      final y2 = p.y * cosX - z1 * sinX;
      final z2 = p.y * sinX + z1 * cosX;

      final zCam = z2 + cameraDistance;
      if (zCam <= 10.0) continue;

      final scale = fov / zCam;
      final sx = center.dx + x1 * scale;
      final sy = center.dy + y2 * scale;
      final pSize = math.max(1.0, p.size * scale);

      paint.color = glowColor.withValues(alpha: (p.opacity * (zCam / cameraDistance)).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(sx, sy), pSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Particles3DPainter oldDelegate) => true;
}

// =============================================================================
// 8. ALTAR RUNIC FLOOR PAINTER
// =============================================================================

class _AltarRunicPainter extends CustomPainter {
  final Color color;

  _AltarRunicPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius * 0.78, ringPaint);
    canvas.drawCircle(center, radius * 0.52, ringPaint);

    final spikePaint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final p1 = Offset(center.dx + math.cos(angle) * (radius * 0.52), center.dy + math.sin(angle) * (radius * 0.52));
      final p2 = Offset(center.dx + math.cos(angle) * (radius * 0.95), center.dy + math.sin(angle) * (radius * 0.95));
      canvas.drawLine(p1, p2, spikePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AltarRunicPainter oldDelegate) => oldDelegate.color != color;
}
