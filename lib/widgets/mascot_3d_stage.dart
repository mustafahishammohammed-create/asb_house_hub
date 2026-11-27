import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
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

/// Professional 3D diagram display modes
enum MascotDiagramMode {
  solidRender,
  holoBlueprint,
  tacticalXRay,
}

/// 3D anatomical hotspot definition for interactive technical callout diagrams
class MascotHotspot {
  final String label;
  final String subtitle;
  final V3 position3D;
  final IconData icon;

  const MascotHotspot({
    required this.label,
    required this.subtitle,
    required this.position3D,
    required this.icon,
  });
}

// =============================================================================
// 2. PROCEDURAL 3D MESH BUILDERS FOR THE 4 HOUSE MASCOTS
// =============================================================================

class Mascot3DMeshes {
  /// Adds a sculpted 16-sided Grand Runic Pedestal Disc directly to any 3D mascot mesh
  static void _attachGrandRunicPedestalDisc(
    List<V3> vertices,
    List<Face3D> faces,
    Color plinthTop,
    Color plinthBevel,
    Color plinthSide,
    Color sealColor, [
    Color? runeColor,
  ]) {
    final baseOffset = vertices.length;
    final rColor = runeColor ?? sealColor;

    // Plinth heights & radii:
    // Tier 1: Upper collar step where paws/claws grip
    const stepTopY = 76.0;
    const stepTopR = 56.0;
    const stepBevelY = 84.0;
    const stepBevelR = 72.0;

    // Tier 2: Grand Runic Disc wide platform
    const discTopY = 84.0;
    const discTopR = 114.0;

    // Tier 3: Beveled outer rim
    const discBevelY = 96.0;
    const discBevelR = 124.0;

    // Tier 4: Vertical cylindrical base wall
    const discBaseY = 108.0;
    const discBaseR = 126.0;

    // Generate 16 vertices per tier (5 rings = 80 vertices)
    for (int i = 0; i < 16; i++) {
      final angle = (i * 22.5) * math.pi / 180;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // Ring 0: Collar top (i * 5 + 0)
      vertices.add(V3(cosA * stepTopR, stepTopY, sinA * stepTopR));
      // Ring 1: Collar bevel / Disc inner (i * 5 + 1)
      vertices.add(V3(cosA * stepBevelR, stepBevelY, sinA * stepBevelR));
      // Ring 2: Disc top outer rim (i * 5 + 2)
      vertices.add(V3(cosA * discTopR, discTopY, sinA * discTopR));
      // Ring 3: Disc bevel rim (i * 5 + 3)
      vertices.add(V3(cosA * discBevelR, discBevelY, sinA * discBevelR));
      // Ring 4: Disc base ring (i * 5 + 4)
      vertices.add(V3(cosA * discBaseR, discBaseY, sinA * discBaseR));
    }

    // Collar top center & Disc bottom center
    final collarCenterIdx = vertices.length;
    vertices.add(const V3(0, stepTopY, 0));
    final discBottomCenterIdx = vertices.length;
    vertices.add(const V3(0, discBaseY, 0));

    // Front house seal medallion vertices (embossed on front face of disc bevel)
    final sealIdx = vertices.length;
    vertices.add(const V3(-18, 93, 118));
    vertices.add(const V3(0, 87, 122));
    vertices.add(const V3(18, 93, 118));
    vertices.add(const V3(0, 101, 122));

    // 1. Collar Top Triangular Fan Faces (16 triangles)
    for (int i = 0; i < 16; i++) {
      final next = (i + 1) % 16;
      final i0 = baseOffset + (i * 5);
      final i1 = baseOffset + (next * 5);
      faces.add(Face3D([collarCenterIdx, i0, i1], plinthTop, isPlinth: true));
    }

    // 2. Collar Step Bevel Quads (16 quads)
    for (int i = 0; i < 16; i++) {
      final next = (i + 1) % 16;
      final t0 = baseOffset + (i * 5);
      final t1 = baseOffset + (next * 5);
      final b0 = baseOffset + (i * 5) + 1;
      final b1 = baseOffset + (next * 5) + 1;
      faces.add(Face3D([t0, t1, b1, b0], plinthBevel, isPlinth: true));
    }

    // 3. Grand Runic Disc Top Platform (16 radial quads)
    for (int i = 0; i < 16; i++) {
      final next = (i + 1) % 16;
      final in0 = baseOffset + (i * 5) + 1;
      final in1 = baseOffset + (next * 5) + 1;
      final out0 = baseOffset + (i * 5) + 2;
      final out1 = baseOffset + (next * 5) + 2;

      final isCardinal = (i % 4 == 0);
      final isRunic = (i % 2 == 1);
      final Color segColor;
      final bool emissive;
      if (isCardinal) {
        segColor = sealColor;
        emissive = true;
      } else if (isRunic) {
        segColor = rColor;
        emissive = true;
      } else {
        segColor = plinthTop;
        emissive = false;
      }

      faces.add(Face3D(
        [in0, in1, out1, out0],
        segColor,
        isEmissive: emissive,
        isPlinth: true,
      ));
    }

    // 4. Outer Beveled Rim (16 quads)
    for (int i = 0; i < 16; i++) {
      final next = (i + 1) % 16;
      final t0 = baseOffset + (i * 5) + 2;
      final t1 = baseOffset + (next * 5) + 2;
      final b0 = baseOffset + (i * 5) + 3;
      final b1 = baseOffset + (next * 5) + 3;
      faces.add(Face3D([t0, t1, b1, b0], plinthBevel, isPlinth: true));
    }

    // 5. Vertical Cylindrical Base Wall (16 quads)
    for (int i = 0; i < 16; i++) {
      final next = (i + 1) % 16;
      final t0 = baseOffset + (i * 5) + 3;
      final t1 = baseOffset + (next * 5) + 3;
      final b0 = baseOffset + (i * 5) + 4;
      final b1 = baseOffset + (next * 5) + 4;
      faces.add(Face3D([t0, t1, b1, b0], plinthSide, isPlinth: true));
    }

    // 6. Front House Seal Medallion (Diamond crest with emissive glow)
    faces.add(Face3D(
      [sealIdx, sealIdx + 1, sealIdx + 2, sealIdx + 3],
      sealColor,
      isEmissive: true,
      isPlinth: true,
    ));

    // 7. Bottom Ground Cap (16 triangle fan)
    for (int i = 0; i < 16; i++) {
      final next = (i + 1) % 16;
      final i0 = baseOffset + (i * 5) + 4;
      final i1 = baseOffset + (next * 5) + 4;
      faces.add(Face3D([discBottomCenterIdx, i1, i0], plinthSide, isPlinth: true));
    }
  }

  // ---------------------------------------------------------------------------
  // 1. IGNIS THE CRIMSON DRAGON (RUBY) - Complete Volumetric 3D Dragon Figurine
  // ---------------------------------------------------------------------------
  static Mesh3D buildDragonMesh() {
    const crimsonCore = Color(0xFF7A0512);
    const crimsonDark = Color(0xFF4A0008);
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
      // Head & Jaws (0-25)
      const V3(0, 8, 88),         // 0: Snout apex
      const V3(-16, 0, 76),       // 1: Snout top bridge L
      const V3(16, 0, 76),        // 2: Snout top bridge R
      const V3(-14, 22, 66),      // 3: Snout bottom jaw L
      const V3(14, 22, 66),       // 4: Snout bottom jaw R
      const V3(0, -12, 56),       // 5: Mid snout ridge
      const V3(-24, -8, 52),      // 6: Muzzle cheek L
      const V3(24, -8, 52),       // 7: Muzzle cheek R
      const V3(0, -26, 38),       // 8: Forehead center apex
      const V3(-24, -16, 44),     // 9: Glowing Ruby Eye L
      const V3(24, -16, 44),      // 10: Glowing Ruby Eye R
      const V3(-30, -28, 28),     // 11: Brow hornlet L
      const V3(30, -28, 28),      // 12: Brow hornlet R
      const V3(0, -42, 20),       // 13: Crown dorsal crest
      const V3(-26, -38, 12),     // 14: Horn root L
      const V3(26, -38, 12),      // 15: Horn root R
      const V3(-48, -65, -20),    // 16: Horn mid flare L
      const V3(48, -65, -20),     // 17: Horn mid flare R
      const V3(-72, -95, -52),    // 18: Horn sharp tip L
      const V3(72, -95, -52),     // 19: Horn sharp tip R
      const V3(0, 32, 58),        // 20: Chin underside
      const V3(-30, 22, 20),      // 21: Jaw corner L
      const V3(30, 22, 20),       // 22: Jaw corner R
      const V3(-10, 16, 70),      // 23: Razor Fang L
      const V3(10, 16, 70),       // 24: Razor Fang R
      const V3(0, -26, -2),       // 25: Back of skull / Nape

      // Neck & Throat (26-29)
      const V3(0, 46, 26),        // 26: Throat front
      const V3(-32, 18, -8),      // 27: Neck flank L
      const V3(32, 18, -8),       // 28: Neck flank R
      const V3(0, -14, -26),      // 29: Neck dorsal spine

      // Solid 3D Torso, Ribcage & Belly (30-39)
      const V3(0, 70, 16),        // 30: Muscular Pectoral Breastplate
      const V3(-56, 58, -16),     // 31: Shoulder L
      const V3(56, 58, -16),      // 32: Shoulder R
      const V3(0, 74, -12),       // 33: Mid Sternum / Underbelly
      const V3(-46, 52, -22),     // 34: Lateral Rib Flank L
      const V3(46, 52, -22),      // 35: Lateral Rib Flank R
      const V3(0, 22, -36),       // 36: Mid Dorsal Spine Ridge
      const V3(0, 76, -38),       // 37: Pelvis Belly Underside
      const V3(-44, 56, -44),     // 38: Rear Hip / Haunch L
      const V3(44, 56, -44),      // 39: Rear Hip / Haunch R
      const V3(0, 42, -54),       // 40: Rear Spine / Sacrum

      // Forelegs & Front Claws (41-46)
      const V3(-40, 76, 32),      // 41: Left Front Talon Base
      const V3(-46, 82, 50),      // 42: Left Front Outer Talon
      const V3(-32, 82, 48),      // 43: Left Front Inner Talon
      const V3(40, 76, 32),       // 44: Right Front Talon Base
      const V3(46, 82, 50),       // 45: Right Front Outer Talon
      const V3(32, 82, 48),       // 46: Right Front Inner Talon

      // Hind Legs & Rear Claws Seated on Pedestal (47-50)
      const V3(-38, 80, -36),     // 47: Rear Leg Foot L (Planted on disc)
      const V3(-46, 72, -30),     // 48: Rear Leg Knee / Hock L
      const V3(38, 80, -36),      // 49: Rear Leg Foot R (Planted on disc)
      const V3(46, 72, -30),      // 50: Rear Leg Knee / Hock R

      // Expansive 3D Wings (51-60)
      const V3(-96, -24, -42),    // 51: Wing Elbow Joint L
      const V3(96, -24, -42),     // 52: Wing Elbow Joint R
      const V3(-142, -66, -68),   // 53: Wing Apex Tip L
      const V3(142, -66, -68),    // 54: Wing Apex Tip R
      const V3(-125, -14, -54),   // 55: Mid Wing Strut L
      const V3(125, -14, -54),    // 56: Mid Wing Strut R
      const V3(-84, 44, -36),     // 57: Lower Wing Membrane L
      const V3(84, 44, -36),      // 58: Lower Wing Membrane R
      const V3(-104, -32, -46),   // 59: Wing Talon Spur L
      const V3(104, -32, -46),    // 60: Wing Talon Spur R

      // Volumetric 3D Curled Dragon Tail (61-66)
      const V3(18, 64, -50),      // 61: Tail Curve 1
      const V3(46, 72, -28),      // 62: Tail Curve 2
      const V3(58, 78, 6),        // 63: Tail Curve 3 (Front right)
      const V3(65, 78, 38),       // 64: Tail Spade Spearhead Tip
      const V3(52, 78, 26),       // 65: Tail Spade Barb L
      const V3(74, 78, 26),       // 66: Tail Spade Barb R
    ];

    final faces = <Face3D>[
      // Head & Snout
      const Face3D([0, 1, 5], crimsonBright),
      const Face3D([0, 5, 2], crimsonBright),
      const Face3D([0, 3, 1], crimsonMid),
      const Face3D([0, 2, 4], crimsonMid),
      const Face3D([0, 4, 20, 3], crimsonCore),

      // Dragon Fangs
      const Face3D([1, 23, 3], Color(0xFFFFF8E7), isEmissive: true),
      const Face3D([2, 4, 24], Color(0xFFFFF8E7), isEmissive: true),

      // Muzzle Bridge & Cheeks
      const Face3D([1, 6, 5], crimsonMid),
      const Face3D([5, 7, 2], crimsonMid),
      const Face3D([1, 3, 21, 6], crimsonCore),
      const Face3D([2, 7, 22, 4], crimsonCore),

      // Luminescent Gemstone Eyes
      const Face3D([6, 9, 8, 5], eyeAmber, isEye: true),
      const Face3D([5, 8, 10, 7], eyeAmber, isEye: true),

      // Forehead & Brow Crest
      const Face3D([8, 11, 13], crimsonBright),
      const Face3D([8, 13, 12], crimsonBright),
      const Face3D([9, 11, 8], crimsonMid),
      const Face3D([7, 10, 12], crimsonMid),

      // 3D Horns Left & Right
      const Face3D([11, 14, 16], hornDark),
      const Face3D([14, 16, 18], hornTip, isEmissive: true),
      const Face3D([14, 13, 16], dragonGold),
      const Face3D([12, 17, 15], hornDark),
      const Face3D([15, 17, 19], hornTip, isEmissive: true),
      const Face3D([13, 15, 17], dragonGold),

      // Back of Skull & Jaw Closure
      const Face3D([13, 14, 25], crimsonCore),
      const Face3D([13, 25, 15], crimsonCore),
      const Face3D([20, 4, 22], crimsonCore),
      const Face3D([20, 21, 3], crimsonCore),
      const Face3D([21, 26, 20], crimsonMid),
      const Face3D([22, 20, 26], crimsonMid),

      // 3D Tubular Neck (Enclosed all 4 sides)
      const Face3D([26, 27, 21], crimsonMid),
      const Face3D([26, 22, 28], crimsonMid),
      const Face3D([25, 27, 29], crimsonCore),
      const Face3D([25, 29, 28], crimsonCore),
      const Face3D([21, 27, 25], crimsonDark),
      const Face3D([22, 25, 28], crimsonDark),

      // Muscular Pectoral Chest Breastplate (Golden Dragon Plates)
      const Face3D([26, 30, 27], dragonGold),
      const Face3D([26, 28, 30], dragonGold),
      const Face3D([30, 31, 33], dragonGold),
      const Face3D([30, 33, 32], dragonGold),

      // Ribcage Flanks & Underbelly (Solid 3D Enclosure)
      const Face3D([27, 31, 34], crimsonMid),
      const Face3D([28, 35, 32], crimsonMid),
      const Face3D([31, 33, 34], crimsonCore),
      const Face3D([32, 35, 33], crimsonCore),
      const Face3D([33, 37, 34], crimsonMid),
      const Face3D([33, 35, 37], crimsonMid),

      // Dorsal Spine Ridge (Neck to Tail)
      const Face3D([29, 36, 27], crimsonCore),
      const Face3D([29, 28, 36], crimsonCore),
      const Face3D([36, 34, 31], crimsonCore),
      const Face3D([36, 32, 35], crimsonCore),
      const Face3D([36, 40, 34], crimsonCore),
      const Face3D([36, 35, 40], crimsonCore),

      // Pelvis & Rear Haunches
      const Face3D([40, 38, 34], crimsonCore),
      const Face3D([40, 35, 39], crimsonCore),
      const Face3D([37, 38, 40], crimsonMid),
      const Face3D([37, 40, 39], crimsonMid),

      // Forelegs & Front Claws
      const Face3D([31, 41, 30], crimsonMid),
      const Face3D([32, 30, 44], crimsonMid),
      const Face3D([41, 42, 43], dragonGold),
      const Face3D([44, 45, 46], dragonGold),

      // Hind Legs Planted on Pedestal Platform
      const Face3D([38, 48, 47], crimsonMid),
      const Face3D([38, 47, 34], crimsonCore),
      const Face3D([39, 49, 50], crimsonMid),
      const Face3D([39, 35, 49], crimsonCore),

      // Volumetric Arched Wings (Double-sided depth)
      const Face3D([31, 51, 57], crimsonDark),
      const Face3D([51, 53, 55], crimsonBright),
      const Face3D([51, 55, 57], crimsonMid),
      const Face3D([51, 59, 53], dragonGold),
      const Face3D([32, 58, 52], crimsonDark),
      const Face3D([52, 56, 54], crimsonBright),
      const Face3D([52, 58, 56], crimsonMid),
      const Face3D([52, 54, 60], dragonGold),
      const Face3D([14, 27, 25], crimsonCore),
      const Face3D([15, 25, 28], crimsonCore),
      const Face3D([31, 57, 34], crimsonCore),
      const Face3D([32, 35, 58], crimsonCore),
      const Face3D([36, 57, 34], crimsonCore),
      const Face3D([36, 35, 58], crimsonCore),

      // Volumetric 3D Dragon Tail with Spearhead Spade
      const Face3D([40, 61, 38], crimsonCore),
      const Face3D([40, 39, 61], crimsonCore),
      const Face3D([61, 62, 48], crimsonMid),
      const Face3D([61, 50, 62], crimsonMid),
      const Face3D([62, 63, 49], crimsonMid),
      const Face3D([63, 64, 65], dragonGold, isEmissive: true),
      const Face3D([63, 66, 64], dragonGold, isEmissive: true),
    ];

    // Attach sculpted Grand Runic Pedestal Disc directly under dragon
    _attachGrandRunicPedestalDisc(
      vertices,
      faces,
      plinthTop,
      plinthBevel,
      plinthDark,
      crimsonBright,
      const Color(0xFFFF5252),
    );

    return Mesh3D(vertices: vertices, faces: faces);
  }

  // ---------------------------------------------------------------------------
  // 2. ZEPHYR THE TEMPEST GRYPHON (SAPPHIRE) - Complete Volumetric 3D Gryphon
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
      // Avian Raptor Head & Beak (0-16)
      const V3(0, 24, 90),        // 0: Curved raptor beak tip
      const V3(0, -6, 78),        // 1: Beak top bridge
      const V3(-16, 6, 66),       // 2: Beak cere L
      const V3(16, 6, 66),        // 3: Beak cere R
      const V3(0, 14, 70),        // 4: Beak lower cutting edge
      const V3(0, 26, 80),        // 5: Beak razor underhook
      const V3(0, -28, 48),       // 6: Forehead ridge
      const V3(-26, -24, 42),     // 7: Eyebrow crown L
      const V3(26, -24, 42),      // 8: Eyebrow crown R
      const V3(-24, -12, 46),     // 9: Glowing Eye L
      const V3(24, -12, 46),      // 10: Glowing Eye R
      const V3(0, -62, 20),       // 11: Crown feather apex
      const V3(-50, -78, -24),    // 12: Ear tuft L
      const V3(50, -78, -24),     // 13: Ear tuft R
      const V3(-32, -45, 6),      // 14: Ear mid L
      const V3(32, -45, 6),       // 15: Ear mid R
      const V3(0, -30, 0),        // 16: Back of avian skull

      // Neck & Mantle (17-21)
      const V3(0, 36, 46),        // 17: Lower throat
      const V3(-36, 20, 10),      // 18: Feather ruff L
      const V3(36, 20, 10),       // 19: Feather ruff R
      const V3(0, -14, -24),      // 20: Dorsal feather mantle

      // Hybrid Eagle-Lion Torso (21-30)
      const V3(0, 70, 16),        // 21: Raptor Breastplate
      const V3(-56, 60, -18),     // 22: Shoulder L
      const V3(56, 60, -18),      // 23: Shoulder R
      const V3(0, 74, -12),       // 24: Lion Underbelly
      const V3(-46, 52, -22),     // 25: Rib Flank L
      const V3(46, 52, -22),      // 26: Rib Flank R
      const V3(0, 22, -36),       // 27: Feline Dorsal Spine
      const V3(0, 76, -38),       // 28: Pelvis Belly
      const V3(-44, 56, -44),     // 29: Lion Hip / Haunch L
      const V3(44, 56, -44),      // 30: Lion Hip / Haunch R
      const V3(0, 42, -54),       // 31: Rear Spine / Sacrum

      // Forelegs & Raptor Claws (32-37)
      const V3(-40, 76, 32),      // 32: Front Talon Base L
      const V3(-46, 82, 50),      // 33: Outer Talon L
      const V3(-32, 82, 48),      // 34: Inner Talon L
      const V3(40, 76, 32),       // 35: Front Talon Base R
      const V3(46, 82, 50),       // 36: Outer Talon R
      const V3(32, 82, 48),       // 37: Inner Talon R

      // Rear Lion Legs Seated on Disc (38-41)
      const V3(-38, 80, -36),     // 38: Rear Lion Paw L (Planted on disc)
      const V3(-46, 72, -30),     // 39: Rear Lion Knee L
      const V3(38, 80, -36),      // 40: Rear Lion Paw R (Planted on disc)
      const V3(46, 72, -30),      // 41: Rear Lion Knee R

      // Broad Eagle Wings (42-49)
      const V3(-95, -22, -42),    // 42: Wing Elbow L
      const V3(95, -22, -42),     // 43: Wing Elbow R
      const V3(-142, -58, -66),   // 44: Primary Feather Apex L
      const V3(142, -58, -66),    // 45: Primary Feather Apex R
      const V3(-125, -14, -54),   // 46: Secondary Feathers L
      const V3(125, -14, -54),    // 47: Secondary Feathers R
      const V3(-84, 40, -34),     // 48: Lower Wing Plumes L
      const V3(84, 40, -34),      // 49: Lower Wing Plumes R

      // Feline Feathered Tail (50-54)
      const V3(18, 64, -50),      // 50: Tail Root
      const V3(44, 72, -28),      // 51: Tail Mid
      const V3(56, 78, 6),        // 52: Tail Front Sweep
      const V3(60, 78, 28),       // 53: Feathered Fan Tuft Tip
      const V3(48, 78, 20),       // 54: Feathered Fan Flare
    ];

    final faces = <Face3D>[
      // Curved Raptor Beak
      const Face3D([0, 1, 2], beakGold),
      const Face3D([0, 3, 1], beakGold),
      const Face3D([0, 2, 4], beakGold),
      const Face3D([0, 4, 3], beakGold),
      const Face3D([0, 4, 5], Color(0xFFE65100)),

      // Eyebrows & Forehead
      const Face3D([1, 6, 2], stormSilver),
      const Face3D([1, 3, 6], stormSilver),
      const Face3D([6, 7, 2], sapphireMid),
      const Face3D([6, 3, 8], sapphireMid),

      // Glowing Cyan Laser Eyes
      const Face3D([2, 7, 9], eyeCyan, isEye: true),
      const Face3D([3, 10, 8], eyeCyan, isEye: true),

      // Feathered Ear Tufts & Crest
      const Face3D([6, 11, 7], stormSilver),
      const Face3D([6, 8, 11], stormSilver),
      const Face3D([7, 14, 12], sapphireBright),
      const Face3D([8, 13, 15], sapphireBright),
      const Face3D([11, 14, 12], sapphireDark),
      const Face3D([11, 13, 15], sapphireDark),

      // Back of Head & Throat
      const Face3D([4, 17, 2], sapphireDark),
      const Face3D([4, 3, 17], sapphireDark),
      const Face3D([11, 12, 16], sapphireDark),
      const Face3D([11, 16, 13], sapphireDark),
      const Face3D([17, 18, 21], stormSilver),
      const Face3D([17, 21, 19], stormSilver),

      // Enclosed Neck Cylinder
      const Face3D([16, 18, 20], sapphireDark),
      const Face3D([16, 20, 19], sapphireDark),
      const Face3D([18, 22, 20], sapphireDark),
      const Face3D([19, 20, 23], sapphireDark),

      // Avian Breastplate & Lion Torso
      const Face3D([21, 18, 22], sapphireMid),
      const Face3D([21, 23, 19], sapphireMid),
      const Face3D([21, 22, 24], sapphireMid),
      const Face3D([21, 24, 23], sapphireMid),
      const Face3D([22, 25, 24], sapphireDark),
      const Face3D([23, 24, 26], sapphireDark),
      const Face3D([24, 28, 25], sapphireMid),
      const Face3D([24, 26, 28], sapphireMid),

      // Dorsal Spine & Pelvis
      const Face3D([20, 27, 25], sapphireDark),
      const Face3D([20, 26, 27], sapphireDark),
      const Face3D([27, 31, 25], sapphireDark),
      const Face3D([27, 26, 31], sapphireDark),
      const Face3D([31, 29, 25], sapphireMid),
      const Face3D([31, 26, 30], sapphireMid),
      const Face3D([28, 29, 31], sapphireDark),
      const Face3D([28, 31, 30], sapphireDark),

      // Front Eagle Talons
      const Face3D([22, 32, 21], sapphireMid),
      const Face3D([23, 21, 35], sapphireMid),
      const Face3D([32, 33, 34], beakGold),
      const Face3D([35, 36, 37], beakGold),

      // Rear Lion Legs Planted on Pedestal
      const Face3D([29, 39, 38], sapphireMid),
      const Face3D([29, 38, 25], sapphireDark),
      const Face3D([30, 40, 41], sapphireMid),
      const Face3D([30, 26, 40], sapphireDark),

      // Broad Eagle Wings
      const Face3D([22, 42, 48], sapphireDark),
      const Face3D([42, 44, 46], sapphireBright),
      const Face3D([42, 46, 48], stormSilver),
      const Face3D([23, 49, 43], sapphireDark),
      const Face3D([43, 47, 45], sapphireBright),
      const Face3D([43, 49, 47], stormSilver),
      const Face3D([12, 18, 16], sapphireDark),
      const Face3D([13, 16, 19], sapphireDark),
      const Face3D([22, 48, 25], sapphireDark),
      const Face3D([23, 26, 49], sapphireDark),
      const Face3D([27, 48, 25], sapphireDark),
      const Face3D([27, 26, 49], sapphireDark),

      // Feline Feathered Tail
      const Face3D([31, 50, 29], sapphireDark),
      const Face3D([31, 30, 50], sapphireDark),
      const Face3D([50, 51, 39], sapphireDark),
      const Face3D([51, 52, 40], sapphireMid),
      const Face3D([52, 53, 54], stormSilver, isEmissive: true),
    ];

    // Attach sculpted Grand Runic Pedestal Disc directly under gryphon
    _attachGrandRunicPedestalDisc(
      vertices,
      faces,
      plinthTop,
      plinthBevel,
      plinthDark,
      sapphireBright,
      const Color(0xFF00E5FF),
    );

    return Mesh3D(vertices: vertices, faces: faces);
  }

  // ---------------------------------------------------------------------------
  // 3. SYLVA THE TITAN WOLF (EMERALD) - Complete Volumetric 3D Direwolf Figurine
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
      // Lupine Head & Muzzle (0-17)
      const V3(0, 14, 92),        // 0: Nose tip
      const V3(0, -2, 76),        // 1: Snout bridge
      const V3(-18, 12, 68),      // 2: Snout side L
      const V3(18, 12, 68),       // 3: Snout side R
      const V3(0, 28, 64),        // 4: Lower jaw / chin
      const V3(0, -22, 44),       // 5: Forehead center
      const V3(-26, -18, 38),     // 6: Wolf brow L
      const V3(26, -18, 38),      // 7: Wolf brow R
      const V3(-22, -10, 44),     // 8: Glowing Jade Eye L
      const V3(22, -10, 44),      // 9: Glowing Jade Eye R
      const V3(0, -40, 20),       // 10: Skull crown
      const V3(-46, -88, -15),    // 11: Ear tip L
      const V3(46, -88, -15),     // 12: Ear tip R
      const V3(-36, -42, 6),      // 13: Ear base outer L
      const V3(36, -42, 6),       // 14: Ear base outer R
      const V3(-16, -42, 14),     // 15: Ear base inner L
      const V3(16, -42, 14),      // 16: Ear base inner R
      const V3(0, -28, 0),        // 17: Back of wolf skull

      // Snarling Fangs (18-19)
      const V3(-8, 20, 68),       // 18: White Fang L
      const V3(8, 20, 68),        // 19: White Fang R

      // Volumetric Fur Ruff / Collar (20-25)
      const V3(0, 44, 28),        // 20: Throat front
      const V3(-74, 16, -6),      // 21: Fur ruff tip L
      const V3(74, 16, -6),       // 22: Fur ruff tip R
      const V3(-92, 48, -20),     // 23: Lower ruff flare L
      const V3(92, 48, -20),      // 24: Lower ruff flare R
      const V3(0, -10, -26),      // 25: Dorsal ruff spine

      // Athletic Direwolf Torso (26-35)
      const V3(0, 76, 18),        // 26: Deep Muscular Chest
      const V3(-56, 62, -18),     // 27: Shoulder L
      const V3(56, 62, -18),      // 28: Shoulder R
      const V3(0, 72, -14),       // 29: Underbelly
      const V3(-48, 52, -22),     // 30: Rib Flank L
      const V3(48, 52, -22),      // 31: Rib Flank R
      const V3(0, 20, -38),       // 32: Arched Spine Ridge
      const V3(0, 74, -40),       // 33: Pelvis Belly
      const V3(-44, 56, -44),     // 34: Muscular Haunch L
      const V3(44, 56, -44),      // 35: Muscular Haunch R
      const V3(0, 40, -54),       // 36: Rear Spine / Sacrum

      // Forelegs & Front Wolf Paws (37-42)
      const V3(-40, 76, 30),      // 37: Front Paw Base L
      const V3(-44, 82, 48),      // 38: Paw Outer Claw L
      const V3(-30, 82, 46),      // 39: Paw Inner Claw L
      const V3(40, 76, 30),       // 40: Front Paw Base R
      const V3(46, 82, 48),       // 41: Paw Outer Claw R
      const V3(32, 82, 46),       // 42: Paw Inner Claw R

      // Hind Legs Planted on Pedestal (43-46)
      const V3(-36, 80, -36),     // 43: Rear Wolf Paw L (Planted on disc)
      const V3(-46, 72, -30),     // 44: Rear Wolf Hock L
      const V3(36, 80, -36),      // 45: Rear Wolf Paw R (Planted on disc)
      const V3(46, 72, -30),      // 46: Rear Wolf Hock R

      // Bushy Wolf Plume Tail (47-50)
      const V3(14, 62, -48),      // 47: Tail Arch 1
      const V3(38, 74, -28),      // 48: Tail Mid
      const V3(54, 78, 6),        // 49: Tail Front Plume
      const V3(58, 80, 24),       // 50: Plume Tip
    ];

    final faces = <Face3D>[
      // Snout & Nose
      const Face3D([0, 1, 2], noseBlack),
      const Face3D([0, 3, 1], noseBlack),
      const Face3D([0, 2, 4], emeraldDark),
      const Face3D([0, 4, 3], emeraldDark),

      // Snarling White Fangs
      const Face3D([2, 18, 4], Color(0xFFFFFFFF), isEmissive: true),
      const Face3D([3, 4, 19], Color(0xFFFFFFFF), isEmissive: true),

      // Muzzle Bridge & Forehead
      const Face3D([1, 5, 2], emeraldMid),
      const Face3D([1, 3, 5], emeraldMid),
      const Face3D([2, 5, 6], emeraldMid),
      const Face3D([3, 7, 5], emeraldMid),

      // Glowing Jade Eyes
      const Face3D([2, 6, 8], eyeJade, isEye: true),
      const Face3D([3, 9, 7], eyeJade, isEye: true),

      // Upright Alert Ears
      const Face3D([10, 15, 11], mossSilver),
      const Face3D([15, 13, 11], emeraldBright),
      const Face3D([10, 11, 13], emeraldDark),
      const Face3D([10, 12, 16], mossSilver),
      const Face3D([16, 12, 14], emeraldBright),
      const Face3D([10, 14, 12], emeraldDark),

      // Back of Skull & Ruff Collar
      const Face3D([10, 13, 17], emeraldDark),
      const Face3D([10, 17, 14], emeraldDark),
      const Face3D([4, 20, 2], emeraldDark),
      const Face3D([4, 3, 20], emeraldDark),
      const Face3D([6, 13, 21], emeraldBright),
      const Face3D([7, 22, 14], emeraldBright),
      const Face3D([21, 23, 20], mossSilver),
      const Face3D([22, 20, 24], mossSilver),

      // Neck Closure
      const Face3D([17, 21, 25], emeraldDark),
      const Face3D([17, 25, 22], emeraldDark),
      const Face3D([21, 27, 25], emeraldDark),
      const Face3D([22, 25, 28], emeraldDark),
      const Face3D([23, 27, 20], emeraldDark),
      const Face3D([24, 20, 28], emeraldDark),
      const Face3D([23, 30, 27], emeraldDark),
      const Face3D([24, 28, 31], emeraldDark),

      // Chest & Torso (Solid 3D Ribcage)
      const Face3D([20, 26, 27], emeraldMid),
      const Face3D([20, 28, 26], emeraldMid),
      const Face3D([26, 27, 29], emeraldBright),
      const Face3D([26, 29, 28], emeraldBright),
      const Face3D([27, 30, 29], emeraldDark),
      const Face3D([28, 29, 31], emeraldDark),
      const Face3D([29, 33, 30], emeraldMid),
      const Face3D([29, 31, 33], emeraldMid),

      // Dorsal Fur Ridge Spine
      const Face3D([25, 32, 30], emeraldDark),
      const Face3D([25, 31, 32], emeraldDark),
      const Face3D([32, 36, 30], emeraldDark),
      const Face3D([32, 31, 36], emeraldDark),

      // Pelvis & Rear Haunches
      const Face3D([36, 34, 30], emeraldMid),
      const Face3D([36, 31, 35], emeraldMid),
      const Face3D([33, 34, 36], emeraldDark),
      const Face3D([33, 36, 35], emeraldDark),

      // Front Paws
      const Face3D([27, 37, 26], emeraldMid),
      const Face3D([28, 26, 40], emeraldMid),
      const Face3D([37, 38, 39], mossSilver),
      const Face3D([40, 41, 42], mossSilver),

      // Rear Paws Planted on Pedestal
      const Face3D([34, 44, 43], emeraldMid),
      const Face3D([34, 43, 30], emeraldDark),
      const Face3D([35, 45, 46], emeraldMid),
      const Face3D([35, 31, 45], emeraldDark),

      // Bushy Wolf Tail
      const Face3D([36, 47, 34], emeraldDark),
      const Face3D([36, 35, 47], emeraldDark),
      const Face3D([47, 48, 44], emeraldMid),
      const Face3D([48, 49, 45], emeraldBright),
      const Face3D([49, 50, 48], mossSilver, isEmissive: true),
    ];

    // Attach sculpted Grand Runic Pedestal Disc directly under wolf
    _attachGrandRunicPedestalDisc(
      vertices,
      faces,
      plinthTop,
      plinthBevel,
      plinthDark,
      emeraldBright,
      const Color(0xFF69F0AE),
    );

    return Mesh3D(vertices: vertices, faces: faces);
  }

  // ---------------------------------------------------------------------------
  // 4. SOLIS THE GOLDEN CHIMERA (TOPAZ) - Complete Volumetric 3D Chimera
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
      // Lion Head & Muzzle (0-10)
      const V3(0, 12, 84),        // 0: Nose tip
      const V3(0, -4, 72),        // 1: Muzzle bridge
      const V3(-20, 12, 68),      // 2: Muzzle whisker pad L
      const V3(20, 12, 68),       // 3: Muzzle whisker pad R
      const V3(0, 30, 60),        // 4: Lower jaw / chin
      const V3(0, -22, 42),       // 5: Forehead brow
      const V3(-26, -16, 38),     // 6: Brow ridge L
      const V3(26, -16, 38),      // 7: Brow ridge R
      const V3(-22, -8, 45),      // 8: Blazing Solar Eye L
      const V3(22, -8, 45),       // 9: Blazing Solar Eye R
      const V3(0, -38, 24),       // 10: Crown apex
      const V3(0, -26, 0),        // 11: Back of lion skull
      const V3(-8, 22, 66),       // 12: Upper Fang L
      const V3(8, 22, 66),        // 13: Upper Fang R

      // 16-Ray 3D Volumetric Radiant Solar Mane (14-29)
      const V3(0, -96, -6),       // 14: Ray 0 (Zenith)
      const V3(-36, -88, -12),    // 15: Ray 1
      const V3(-68, -72, -16),    // 16: Ray 2
      const V3(-88, -44, -18),    // 17: Ray 3
      const V3(-98, -10, -20),    // 18: Ray 4 (Flank mid L)
      const V3(-92, 26, -22),     // 19: Ray 5
      const V3(-74, 56, -22),     // 20: Ray 6
      const V3(-42, 74, -18),     // 21: Ray 7 (Lower L)
      const V3(0, 80, 8),         // 22: Ray 8 (Chin beard apex)
      const V3(42, 74, -18),      // 23: Ray 9 (Lower R)
      const V3(74, 56, -22),      // 24: Ray 10
      const V3(92, 26, -22),      // 25: Ray 11
      const V3(98, -10, -20),     // 26: Ray 12 (Flank mid R)
      const V3(88, -44, -18),     // 27: Ray 13
      const V3(68, -72, -16),     // 28: Ray 14
      const V3(36, -88, -12),     // 29: Ray 15

      // Muscular Imperial Torso (30-39)
      const V3(0, 72, 16),        // 30: Imperial Gold Pectoral Breastplate
      const V3(-54, 62, -18),     // 31: Shoulder L
      const V3(54, 62, -18),      // 32: Shoulder R
      const V3(0, 72, -14),       // 33: Underbelly
      const V3(-48, 52, -22),     // 34: Rib Flank L
      const V3(48, 52, -22),      // 35: Rib Flank R
      const V3(0, 22, -36),       // 36: Golden Spine Ridge
      const V3(0, 74, -40),       // 37: Pelvis Belly
      const V3(-44, 56, -44),     // 38: Lion Haunch L
      const V3(44, 56, -44),      // 39: Lion Haunch R
      const V3(0, 42, -54),       // 40: Rear Spine / Sacrum

      // Forelegs & Golden Front Paws (41-46)
      const V3(-38, 76, 32),      // 41: Front Paw Base L
      const V3(-42, 82, 48),      // 42: Golden Claw Outer L
      const V3(-28, 82, 46),      // 43: Golden Claw Inner L
      const V3(38, 76, 32),       // 44: Front Paw Base R
      const V3(42, 82, 48),       // 45: Golden Claw Outer R
      const V3(28, 82, 46),       // 46: Golden Claw Inner R

      // Rear Lion Legs Planted on Pedestal (47-50)
      const V3(-36, 80, -36),     // 47: Rear Paw L (Planted on disc)
      const V3(-46, 72, -30),     // 48: Rear Knee L
      const V3(36, 80, -36),      // 49: Rear Paw R (Planted on disc)
      const V3(46, 72, -30),      // 50: Rear Knee R

      // Coiled Serpent Chimera Tail (51-56)
      const V3(18, 64, -50),      // 51: Serpent Tail Base
      const V3(44, 72, -28),      // 52: Serpent Tail Arch
      const V3(56, 78, 6),        // 53: Serpent Coil Forward
      const V3(62, 76, 28),       // 54: Snake Hood Flare
      const V3(64, 74, 46),       // 55: Viper Head / Stinger Apex
      const V3(54, 76, 36),       // 56: Stinger Barb
    ];

    final faces = <Face3D>[
      // Lion Muzzle & Nose
      const Face3D([0, 1, 2], imperialAmber),
      const Face3D([0, 3, 1], imperialAmber),
      const Face3D([0, 2, 4], sunGoldMid),
      const Face3D([0, 4, 3], sunGoldMid),

      // Lion White Fangs
      const Face3D([2, 12, 4], Color(0xFFFFFFFF), isEmissive: true),
      const Face3D([3, 4, 13], Color(0xFFFFFFFF), isEmissive: true),

      // Forehead & Brows
      const Face3D([1, 5, 2], sunGoldMid),
      const Face3D([1, 3, 5], sunGoldMid),
      const Face3D([2, 5, 6], sunGoldDark),
      const Face3D([3, 7, 5], sunGoldDark),

      // Blazing Solar Eyes
      const Face3D([2, 6, 8], solarEye, isEye: true),
      const Face3D([3, 9, 7], solarEye, isEye: true),

      // Back of Head Closure
      const Face3D([10, 6, 11], sunGoldMid),
      const Face3D([10, 11, 7], sunGoldMid),
      const Face3D([4, 22, 2], imperialAmber),
      const Face3D([4, 3, 22], imperialAmber),

      // 16-Ray Solar Sunburst Mane (Volumetric 3D Corona)
      const Face3D([10, 15, 14], sunGoldBright, isEmissive: true),
      const Face3D([10, 14, 29], sunGoldBright, isEmissive: true),
      const Face3D([6, 16, 15], sunGoldMid),
      const Face3D([7, 29, 28], sunGoldMid),
      const Face3D([6, 17, 16], sunGoldBright),
      const Face3D([7, 28, 27], sunGoldBright),
      const Face3D([6, 18, 17], sunGoldMid),
      const Face3D([7, 27, 26], sunGoldMid),
      const Face3D([11, 19, 18], sunGoldDark),
      const Face3D([11, 26, 25], sunGoldDark),
      const Face3D([11, 20, 19], sunGoldMid),
      const Face3D([11, 25, 24], sunGoldMid),
      const Face3D([22, 21, 20], sunGoldBright),
      const Face3D([22, 24, 23], sunGoldBright),

      // Imperial Pectoral Breastplate & Ribcage
      const Face3D([22, 30, 31], sunGoldBright),
      const Face3D([22, 32, 30], sunGoldBright),
      const Face3D([30, 31, 33], sunGoldMid),
      const Face3D([30, 33, 32], sunGoldMid),
      const Face3D([31, 34, 33], sunGoldDark),
      const Face3D([32, 33, 35], sunGoldDark),
      const Face3D([33, 37, 34], sunGoldMid),
      const Face3D([33, 35, 37], sunGoldMid),

      // Golden Spine Ridge (Enclosing back from all angles)
      const Face3D([11, 36, 31], sunGoldDark),
      const Face3D([11, 32, 36], sunGoldDark),
      const Face3D([36, 34, 31], sunGoldDark),
      const Face3D([36, 32, 35], sunGoldDark),
      const Face3D([36, 40, 34], sunGoldDark),
      const Face3D([36, 35, 40], sunGoldDark),

      // Pelvis & Rear Lion Haunches
      const Face3D([40, 38, 34], sunGoldMid),
      const Face3D([40, 35, 39], sunGoldMid),
      const Face3D([37, 38, 40], sunGoldDark),
      const Face3D([37, 40, 39], sunGoldDark),

      // Front Paws
      const Face3D([31, 41, 30], sunGoldMid),
      const Face3D([32, 30, 44], sunGoldMid),
      const Face3D([41, 42, 43], sunGoldBright),
      const Face3D([44, 45, 46], sunGoldBright),

      // Rear Paws Planted on Pedestal Platform
      const Face3D([38, 48, 47], sunGoldMid),
      const Face3D([38, 47, 34], sunGoldDark),
      const Face3D([39, 49, 50], sunGoldMid),
      const Face3D([39, 35, 49], sunGoldDark),

      // Coiled Serpent Chimera Tail with Viper Stinger
      const Face3D([40, 51, 38], imperialAmber),
      const Face3D([40, 39, 51], imperialAmber),
      const Face3D([51, 52, 48], sunGoldDark),
      const Face3D([52, 53, 49], sunGoldMid),
      const Face3D([53, 54, 56], imperialAmber),
      const Face3D([54, 55, 56], sunGoldBright, isEmissive: true),
    ];

    // Attach sculpted Grand Runic Pedestal Disc directly under chimera
    _attachGrandRunicPedestalDisc(
      vertices,
      faces,
      plinthTop,
      plinthBevel,
      plinthDark,
      sunGoldBright,
      const Color(0xFFFFD700),
    );

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
  final List<MascotHotspot> hotspots;

  String get houseName => houseId.isNotEmpty ? '${houseId[0].toUpperCase()}${houseId.substring(1)}' : '';

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
    required this.hotspots,
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
          hotspots: const [
            MascotHotspot(
              label: 'Cranial Crest Horns',
              subtitle: 'Flame Arc Channeling',
              position3D: V3(0, -62, 10),
              icon: Icons.whatshot_rounded,
            ),
            MascotHotspot(
              label: 'Thermal Wings',
              subtitle: 'Mach-2 Gliding Struts',
              position3D: V3(-110, -35, -45),
              icon: Icons.air_rounded,
            ),
            MascotHotspot(
              label: 'Dragon Razor Fangs',
              subtitle: '3,500 PSI Bite Force',
              position3D: V3(0, 16, 75),
              icon: Icons.flash_on_rounded,
            ),
            MascotHotspot(
              label: 'Adamantine Talons',
              subtitle: 'Grand Disc Grip',
              position3D: V3(-44, 76, 40),
              icon: Icons.sports_kabaddi_rounded,
            ),
            MascotHotspot(
              label: 'Spade Tail Whip',
              subtitle: 'Defensive Sweep Array',
              position3D: V3(55, 78, 20),
              icon: Icons.offline_bolt_rounded,
            ),
          ],
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
          hotspots: const [
            MascotHotspot(
              label: 'Raptor Hook Beak',
              subtitle: 'Aerodynamic Cutting Edge',
              position3D: V3(0, 14, 80),
              icon: Icons.flash_on_rounded,
            ),
            MascotHotspot(
              label: 'Storm Feather Crest',
              subtitle: 'Barometric Senses',
              position3D: V3(0, -65, 0),
              icon: Icons.air_rounded,
            ),
            MascotHotspot(
              label: 'Tempest Razor Wings',
              subtitle: 'Sonic Gale Induction',
              position3D: V3(-115, -30, -45),
              icon: Icons.cyclone_rounded,
            ),
            MascotHotspot(
              label: 'Gryphon Talons',
              subtitle: 'Precision Disc Clutch',
              position3D: V3(-40, 76, 40),
              icon: Icons.sports_kabaddi_rounded,
            ),
            MascotHotspot(
              label: 'Aero Feather Tail',
              subtitle: 'Rudder Gyro-Stabilizer',
              position3D: V3(48, 76, -10),
              icon: Icons.change_history_rounded,
            ),
          ],
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
          hotspots: const [
            MascotHotspot(
              label: 'Snarl White Fangs',
              subtitle: 'Alpha Pack Strike',
              position3D: V3(0, 20, 70),
              icon: Icons.flash_on_rounded,
            ),
            MascotHotspot(
              label: 'Titan Ear Radar',
              subtitle: 'Infrasound Frequency Scan',
              position3D: V3(36, -65, -5),
              icon: Icons.hearing_rounded,
            ),
            MascotHotspot(
              label: 'Alpha Ruff Mane',
              subtitle: 'Reinforced Armor Strata',
              position3D: V3(-70, 30, -15),
              icon: Icons.shield_rounded,
            ),
            MascotHotspot(
              label: 'Direwolf Paws',
              subtitle: 'High-Traction Disc Plant',
              position3D: V3(-38, 76, 40),
              icon: Icons.pets_rounded,
            ),
            MascotHotspot(
              label: 'Forest Tail Plume',
              subtitle: 'Momentum Vector Rudder',
              position3D: V3(48, 76, -10),
              icon: Icons.nature_rounded,
            ),
          ],
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
          hotspots: const [
            MascotHotspot(
              label: 'Solar Fangs & Muzzle',
              subtitle: 'Dawn Roar Acoustic Array',
              position3D: V3(0, 22, 70),
              icon: Icons.record_voice_over_rounded,
            ),
            MascotHotspot(
              label: '16-Ray Solar Mane',
              subtitle: 'Corona Thermal Flare',
              position3D: V3(0, -85, -10),
              icon: Icons.wb_sunny_rounded,
            ),
            MascotHotspot(
              label: 'Sovereign Horns',
              subtitle: 'Solar Energy Conduction',
              position3D: V3(-40, -65, -10),
              icon: Icons.auto_awesome_rounded,
            ),
            MascotHotspot(
              label: 'Imperial Paws',
              subtitle: 'Sovereign Altar Anchor',
              position3D: V3(-36, 76, 40),
              icon: Icons.gavel_rounded,
            ),
            MascotHotspot(
              label: 'Serpent Chimera Tail',
              subtitle: 'Electro-Static Defense',
              position3D: V3(48, 76, -10),
              icon: Icons.bolt_rounded,
            ),
          ],
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
  MascotDiagramMode _diagramMode = MascotDiagramMode.solidRender;
  bool _showDiagramCallouts = true;

  // Keyboard navigation focus node
  final FocusNode _stageFocusNode = FocusNode();

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

    // Altar pedestal runic ring rotation & particle physics
    _altarSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..addListener(_updateParticles)
     ..repeat();

    // Turntable 360° auto-spin controller
    _turntableController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        if (!mounted) return;
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
        if (!mounted) return;
        setState(() {
          _rotX = _springAnimX.value;
          _rotY = _springAnimY.value;
        });
      });
    _springAnimX = const AlwaysStoppedAnimation(0.08);
    _springAnimY = const AlwaysStoppedAnimation(0.0);

    _initParticles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _stageFocusNode.requestFocus();
      }
    });
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
    _stageFocusNode.dispose();
    _idleFloatController.dispose();
    _altarSpinController.dispose();
    _turntableController.dispose();
    _roarController.dispose();
    _springBackController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    HapticFeedback.lightImpact();
    setState(() {
      _zoomScale = (_zoomScale + 0.15).clamp(0.72, 1.95);
    });
  }

  void _zoomOut() {
    HapticFeedback.lightImpact();
    setState(() {
      _zoomScale = (_zoomScale - 0.15).clamp(0.72, 1.95);
    });
  }

  KeyEventResult _handleStageKeyNavigation(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _rotY = (_rotY - 0.1) % (math.pi * 2);
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _rotY = (_rotY + 0.1) % (math.pi * 2);
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _rotX = (_rotX + 0.08).clamp(-0.85, 0.85);
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _rotX = (_rotX - 0.08).clamp(-0.85, 0.85);
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.numpadAdd ||
        event.logicalKey == LogicalKeyboardKey.equal) {
      _zoomIn();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.numpadSubtract ||
        event.logicalKey == LogicalKeyboardKey.minus) {
      _zoomOut();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _triggerRoar();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Active house mascot switched to ${_currentMascot.name}',
        TextDirection.ltr,
      );
    } catch (_) {}
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
        content: Semantics(
          liveRegion: true,
          excludeSemantics: true,
          label: '${_currentMascot.name} unleashes battle cry: ${_currentMascot.battleCry}',
          child: Row(
            children: [
              ExcludeSemantics(
                child: Text(_currentMascot.primaryEmoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _currentMascot.battleCry,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
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
        try {
          SemanticsService.sendAnnouncement(
            View.of(context),
            '360 turntable spinning',
            TextDirection.ltr,
          );
        } catch (_) {}
      } else {
        _turntableController.stop();
        _snapToAngle(0.08, 0.0, angleName: 'Front');
        try {
          SemanticsService.sendAnnouncement(
            View.of(context),
            '360 turntable stopped',
            TextDirection.ltr,
          );
        } catch (_) {}
      }
    });
  }

  void _snapToAngle(double targetX, double targetY, {String? angleName}) {
    _springAnimX = Tween<double>(begin: _rotX, end: targetX).animate(
      CurvedAnimation(parent: _springBackController, curve: Curves.easeOutBack),
    );
    _springAnimY = Tween<double>(begin: _rotY, end: targetY).animate(
      CurvedAnimation(parent: _springBackController, curve: Curves.easeOutBack),
    );
    _springBackController.forward(from: 0.0);
    if (angleName != null) {
      try {
        SemanticsService.sendAnnouncement(
          View.of(context),
          '$angleName camera preset applied',
          TextDirection.ltr,
        );
      } catch (_) {}
    }
  }

  void _changeFinish(MascotMaterialFinish finish) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentFinish = finish;
    });
    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Material finish changed to ${finish.name}',
        TextDirection.ltr,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mascot = _currentMascot;

    return SafeArea(
      bottom: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FOUR GREAT HOUSES SELECTOR
            _buildHouseSelectorBar(),
            const SizedBox(height: 14),

            // 2. TRUE 3D VOLUMETRIC MASCOT STAGE
            _buildTrue3DStage(mascot),
            const SizedBox(height: 14),

            // 3. MATERIAL FINISH SELECTOR (House Chroma, Imperial Gold, Dark Obsidian, Astral Crystal)
            _buildMaterialFinishSelector(mascot),
            const SizedBox(height: 14),

            // 4. 3D CAMERA ANGLE PRESETS (Front, 3/4 Hero, Profile, Back, Top)
            _buildCameraAnglePresets(),
            const SizedBox(height: 14),

            // 5. 3D CONTROL HUD (Turntable, Zoom, Reset, Roar)
            _build3DControlHud(mascot),
            const SizedBox(height: 18),

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

            // Generous bottom clearance to prevent bottom-bar/dock overlap
            const SizedBox(height: 110),
          ],
        ),
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
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: houses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final h = houses[index];
          final isSel = _activeHouse == h['id'];
          final color = h['color'] as Color;

          return Semantics(
            button: true,
            selected: isSel,
            excludeSemantics: true,
            label: '${h["name"]} House Mascot',
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _switchMascot(h['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    ExcludeSemantics(
                      child: Text(h['emoji'] as String, style: const TextStyle(fontSize: 16)),
                    ),
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
      height: 440,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.35,
          colors: [
            mascot.glowColor.withValues(alpha: 0.22),
            const Color(0xFF0A0F1D),
            const Color(0xFF030509),
          ],
          stops: const [0.0, 0.58, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: mascot.glowColor.withValues(alpha: 0.18),
            blurRadius: 44,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          children: [
            _buildStageTopBar(mascot),
            Expanded(
              child: Focus(
                focusNode: _stageFocusNode,
                autofocus: true,
                onKeyEvent: _handleStageKeyNavigation,
                child: Semantics(
                  container: true,
                  label: '${mascot.name} 3D Statue Stage',
                  hint: 'Use arrow keys to rotate, plus or minus to zoom, space or enter to roar',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _stageFocusNode.requestFocus(),
                    onTap: () => _stageFocusNode.requestFocus(),
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
                          _rotY = (_rotY + details.focalPointDelta.dx * 0.016) % (math.pi * 2);
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
                          child: ExcludeSemantics(
                            child: CustomPaint(
                              painter: _Particles3DPainter(
                                particles: _particles,
                                glowColor: mascot.glowColor,
                                rotX: _rotX,
                                rotY: _rotY,
                              ),
                            ),
                          ),
                        ),

                        // 2. Sanctuary Floor Light & Ground Dais Aura
                        Positioned(
                          bottom: 22,
                          child: ExcludeSemantics(
                            child: AnimatedBuilder(
                              animation: _altarSpinController,
                              builder: (context, _) {
                                return Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.002)
                                    ..rotateX(1.22)
                                    ..rotateZ(_altarSpinController.value * math.pi * 2),
                                  child: Container(
                                    width: 290,
                                    height: 290,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          mascot.glowColor.withValues(alpha: 0.38),
                                          mascot.glowColor.withValues(alpha: 0.12),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.65, 1.0],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: mascot.glowColor.withValues(alpha: 0.35),
                                          blurRadius: 28,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: CustomPaint(
                                      painter: _AltarRunicPainter(color: mascot.glowColor.withValues(alpha: 0.5)),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // 3. Dynamic 3D Ground Contact Shadow tracking mascot's disc
                        Positioned(
                          bottom: 26,
                          child: ExcludeSemantics(
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.translationValues(
                                math.sin(_rotY) * 24,
                                -_rotX * 16,
                                0.0,
                              ),
                              child: Container(
                                width: 210,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.88),
                                  borderRadius: const BorderRadius.all(Radius.elliptical(210, 44)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.98),
                                      blurRadius: 26,
                                      spreadRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 4. REAL 3D POLYGONAL MESH STATUE & GRAND RUNIC DISC
                        ExcludeSemantics(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([
                              _idleFloatController,
                              _roarController,
                            ]),
                            builder: (context, _) {
                              final floatVal = _idleFloatController.value;
                              // Subtle living breath pulse
                              final breatheScale = 1.0 + (math.sin(floatVal * math.pi * 2) * 0.012);

                              // Roar scale & vibration pulse
                              final roarVal = _roarController.value;
                              final roarScale = 1.0 + (math.sin(roarVal * math.pi) * 0.18);
                              final shakeX = (roarVal > 0.0 && roarVal < 0.7)
                                  ? (math.sin(roarVal * math.pi * 12) * 4.0)
                                  : 0.0;

                              return Transform.translate(
                                offset: Offset(shakeX, 2),
                                child: Transform.scale(
                                  scale: roarScale * _zoomScale * breatheScale,
                                  child: SizedBox(
                                    width: 360,
                                    height: 360,
                                    child: CustomPaint(
                                      painter: _Mascot3DRendererPainter(
                                        mesh: mascot.mesh,
                                        rotX: _rotX,
                                        rotY: _rotY,
                                        glowColor: mascot.glowColor,
                                        primaryColor: mascot.primaryColor,
                                        finish: _currentFinish,
                                        diagramMode: _diagramMode,
                                        showCallouts: _showDiagramCallouts,
                                        hotspots: mascot.hotspots,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // 5. Kinetic Roar Shockwave Ring
                        ExcludeSemantics(
                          child: AnimatedBuilder(
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
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildStageBottomBar(mascot),
          ],
        ),
      ),
    );
  }

  Widget _buildStageTopBar(MascotLoreData mascot) {
    final yawDeg = (((_rotY * 180 / math.pi) % 360).toInt() + 360) % 360;
    final pitchDeg = (_rotX * 180 / math.pi).toInt();
    final zoomPct = (_zoomScale * 100).toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3 || constraints.maxWidth < 460;

          final telemetryHud = Semantics(
            container: true,
            liveRegion: true,
            label: 'CAD Telemetry: Heading $yawDeg degrees, Pitch $pitchDeg degrees, Zoom $zoomPct percent',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: mascot.glowColor.withValues(alpha: 0.22), width: 1.0),
              ),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00E676),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E676).withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'CAD • YAW: $yawDeg°  PITCH: $pitchDeg°  $zoomPct%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          final diagramModes = Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: mascot.glowColor.withValues(alpha: 0.22), width: 1.0),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDiagramModeBtn(
                    label: 'Solid',
                    icon: Icons.view_in_ar_rounded,
                    mode: MascotDiagramMode.solidRender,
                    activeColor: mascot.accentColor,
                  ),
                  const SizedBox(width: 2),
                  _buildDiagramModeBtn(
                    label: 'Blueprint',
                    icon: Icons.grid_4x4_rounded,
                    mode: MascotDiagramMode.holoBlueprint,
                    activeColor: const Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 2),
                  _buildDiagramModeBtn(
                    label: 'X-Ray',
                    icon: Icons.biotech_rounded,
                    mode: MascotDiagramMode.tacticalXRay,
                    activeColor: const Color(0xFFFF4081),
                  ),
                ],
              ),
            ),
          );

          if (isLargeText) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                telemetryHud,
                const SizedBox(height: 6),
                diagramModes,
              ],
            );
          }

          return Row(
            children: [
              Flexible(child: telemetryHud),
              const SizedBox(width: 6),
              diagramModes,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStageBottomBar(MascotLoreData mascot) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3 || constraints.maxWidth < 360;

          final calloutsToggle = Semantics(
            button: true,
            toggled: _showDiagramCallouts,
            excludeSemantics: true,
            label: 'Technical Callouts: ${_showDiagramCallouts ? "Active" : "Hidden"}',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _showDiagramCallouts = !_showDiagramCallouts;
                  });
                  try {
                    SemanticsService.sendAnnouncement(
                      View.of(context),
                      _showDiagramCallouts ? 'Callouts activated' : 'Callouts hidden',
                      TextDirection.ltr,
                    );
                  } catch (_) {}
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _showDiagramCallouts
                          ? mascot.glowColor.withValues(alpha: 0.28)
                          : Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _showDiagramCallouts ? mascot.accentColor : mascot.glowColor.withValues(alpha: 0.20),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showDiagramCallouts ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          size: 13,
                          color: _showDiagramCallouts ? Colors.white : Colors.white60,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _showDiagramCallouts ? 'Callouts: ACTIVE' : 'Callouts: HIDDEN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _showDiagramCallouts ? Colors.white : Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          if (isLargeText) {
            return Row(
              children: [
                Expanded(child: calloutsToggle),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: calloutsToggle),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: mascot.glowColor.withValues(alpha: 0.20), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.threed_rotation_rounded, size: 12, color: mascot.accentColor),
                      const SizedBox(width: 5),
                      const Text(
                        '360° Drag • Pinch',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiagramModeBtn({
    required String label,
    required IconData icon,
    required MascotDiagramMode mode,
    required Color activeColor,
  }) {
    final isSelected = _diagramMode == mode;
    return Semantics(
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      label: '$label Diagram Mode',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _diagramMode = mode;
            });
            try {
              SemanticsService.sendAnnouncement(
                View.of(context),
                '$label diagram mode activated',
                TextDirection.ltr,
              );
            } catch (_) {}
          },
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.32) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? activeColor : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 11, color: isSelected ? Colors.white : Colors.white60),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 9.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
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
        color: const Color(0xFF0A0F1D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mascot.glowColor.withValues(alpha: 0.16), width: 1.0),
      ),
      child: Row(
        children: finishes.map((f) {
          final isSel = _currentFinish == f['finish'];
          final finishEnum = f['finish'] as MascotMaterialFinish;

          return Expanded(
            child: Semantics(
              button: true,
              selected: isSel,
              excludeSemantics: true,
              label: '${f['label']} Material Finish',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _changeFinish(finishEnum),
                  child: Center(
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
                          Flexible(
                            child: Text(
                              f['label'] as String,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: angles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final a = angles[index];
          return Semantics(
            button: true,
            excludeSemantics: true,
            label: '${a['label']} Camera Angle Preset',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (_isAutoRotating) {
                    _isAutoRotating = false;
                    _turntableController.stop();
                  }
                  _snapToAngle(a['x'] as double, a['y'] as double, angleName: a['label'] as String);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1424),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _currentMascot.glowColor.withValues(alpha: 0.16), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Icon(a['icon'] as IconData, size: 14, color: Colors.white60),
                      const SizedBox(width: 6),
                      Text(
                        a['label'] as String,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final isLargeText = textScale >= 1.3 || constraints.maxWidth < 400;
        final isNarrow = constraints.maxWidth < 360;

        final spinBtn = OutlinedButton.icon(
          icon: Icon(
            _isAutoRotating ? Icons.pause_circle_filled_rounded : Icons.rotate_right_rounded,
            size: 18,
            color: _isAutoRotating ? Colors.amberAccent : Colors.white70,
          ),
          label: Text(
            _isAutoRotating ? 'Spinning' : (isNarrow ? 'Spin' : '360° Spin'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _isAutoRotating ? Colors.amberAccent : Colors.white70,
              fontSize: isNarrow ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: _isAutoRotating ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFF0D1424),
            side: BorderSide(
              color: _isAutoRotating ? Colors.amberAccent : mascot.glowColor.withValues(alpha: 0.16),
            ),
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _toggleAutoRotate,
        );

        final zoomOutBtn = IconButton.outlined(
          tooltip: 'Zoom Out',
          icon: const Icon(Icons.remove_rounded, size: 18, color: Colors.white70),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF0D1424),
            side: BorderSide(color: mascot.glowColor.withValues(alpha: 0.16)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _zoomOut,
        );

        final zoomInBtn = IconButton.outlined(
          tooltip: 'Zoom In',
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white70),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF0D1424),
            side: BorderSide(color: mascot.glowColor.withValues(alpha: 0.16)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _zoomIn,
        );

        final resetBtn = IconButton.outlined(
          tooltip: 'Reset Camera View',
          icon: const Icon(Icons.center_focus_strong_rounded, size: 18, color: Colors.white70),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF0D1424),
            side: BorderSide(color: mascot.glowColor.withValues(alpha: 0.16)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (_isAutoRotating) {
              _isAutoRotating = false;
              _turntableController.stop();
            }
            setState(() => _zoomScale = 1.0);
            _snapToAngle(0.08, 0.0, angleName: 'Front');
          },
        );

        final roarBtn = ElevatedButton.icon(
          icon: const Icon(Icons.volume_up_rounded, size: 18, color: Colors.white),
          label: Text(
            'Roar!',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isNarrow ? 11 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: mascot.primaryColor,
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            shadowColor: mascot.glowColor.withValues(alpha: 0.5),
            elevation: 4,
          ),
          onPressed: _triggerRoar,
        );

        if (isLargeText) {
          // Responsive 2-row layout under high font scaling (up to 200%) or narrow screen
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      toggled: _isAutoRotating,
                      excludeSemantics: true,
                      label: _isAutoRotating ? 'Stop 360 Turntable Spin' : 'Start 360 Turntable Spin',
                      child: spinBtn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      button: true,
                      excludeSemantics: true,
                      label: 'Unleash ${mascot.name} Roar',
                      child: roarBtn,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  zoomOutBtn,
                  const SizedBox(width: 12),
                  zoomInBtn,
                  const SizedBox(width: 12),
                  resetBtn,
                ],
              ),
            ],
          );
        }

        // Standard single-row layout
        return Row(
          children: [
            Expanded(
              flex: 4,
              child: Semantics(
                button: true,
                toggled: _isAutoRotating,
                excludeSemantics: true,
                label: _isAutoRotating ? 'Stop 360 Turntable Spin' : 'Start 360 Turntable Spin',
                child: spinBtn,
              ),
            ),
            const SizedBox(width: 6),
            zoomOutBtn,
            const SizedBox(width: 4),
            zoomInBtn,
            const SizedBox(width: 4),
            resetBtn,
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: Semantics(
                button: true,
                excludeSemantics: true,
                label: 'Unleash ${mascot.name} Roar',
                child: roarBtn,
              ),
            ),
          ],
        );
      },
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
        border: Border.all(color: mascot.glowColor.withValues(alpha: 0.22), width: 1.0),
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
                  border: Border.all(color: mascot.accentColor.withValues(alpha: 0.4), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: mascot.glowColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ],
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
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
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
    return InkWell(
      onTap: () => _showMascotAttributeModal(mascot),
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1523),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: mascot.glowColor.withValues(alpha: 0.18), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.query_stats_rounded, color: mascot.accentColor, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mascot Power Attributes',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16),
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
                        Expanded(
                          child: Text(
                            entry.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
      ),
    );
  }

  // ===========================================================================
  // 8. SACRED RELIC OF THE HOUSE ARCHIVES
  // ===========================================================================
  Widget _buildSacredRelicCard(MascotLoreData mascot) {
    return InkWell(
      onTap: () => _showRelicLoreModal(mascot),
      borderRadius: BorderRadius.circular(26),
      child: Container(
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
                const Icon(Icons.touch_app_rounded, color: Colors.amberAccent, size: 18),
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
      ),
    );
  }

  void _showMascotAttributeModal(MascotLoreData mascot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1523),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.query_stats_rounded, color: mascot.accentColor, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${mascot.name.toUpperCase()} POWER ARCHIVES',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: mascot.accentColor),
                        ),
                        Text(
                          '${mascot.houseName.toUpperCase()} House Divine Guardian Lore',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: mascot.glowColor.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW COMBAT ATTRIBUTES ARE UNLOCKED',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.cyanAccent, letterSpacing: 0.8),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '• Physical Power & Strength: Elevated by victories in football, basketball, and track tournaments.\n'
                      '• Arcane Acuity: Heightened through top performance in Brain Blitz trivia and academic report card honours.\n'
                      '• Swift Agility: Powered by on-time attendance and prompt assignment turn-ins.\n'
                      '• Guardian Defense: Maintained by pristine disciplinary conduct with zero demerits.',
                      style: TextStyle(fontSize: 12, height: 1.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on_rounded, size: 20),
                  label: Text('Channel House Power to ${mascot.name}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mascot.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚡ Channeled house energy to ${mascot.name}! Power stats surged.'),
                        backgroundColor: mascot.primaryColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRelicLoreModal(MascotLoreData mascot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1523),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(mascot.sacredRelicIcon, color: Colors.amberAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mascot.sacredRelicTitle.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.amberAccent),
                        ),
                        Text(
                          'Sacred Heirloom of ${mascot.houseName.toUpperCase()} House',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  mascot.sacredRelicDesc,
                  style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: const Text('Venerate House Relic (+5 House Spirit)', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✨ Venerated the ${mascot.sacredRelicTitle}! Sacred blessings bestowed on ${mascot.houseName.toUpperCase()}.'),
                        backgroundColor: Colors.amber.shade800,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
        border: Border.all(color: mascot.glowColor.withValues(alpha: 0.18), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Founding Era Chronicles',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
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
        border: Border.all(color: mascot.glowColor.withValues(alpha: 0.18), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded, color: mascot.accentColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'House Virtues & Sacred Rite',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
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
                    Expanded(
                      child: Text(
                        v,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
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
  final MascotDiagramMode diagramMode;
  final bool showCallouts;
  final List<MascotHotspot> hotspots;

  static final V3 _lightDir = const V3(-0.4, -0.65, 0.7).normalized();

  _Mascot3DRendererPainter({
    required this.mesh,
    required this.rotX,
    required this.rotY,
    required this.glowColor,
    required this.primaryColor,
    required this.finish,
    required this.diagramMode,
    required this.showCallouts,
    required this.hotspots,
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

    // 3. Process and depth-sort visible faces (Painter's Algorithm with Two-Sided Shading)
    final drawableFaces = <_DrawableFace>[];

    for (final face in mesh.faces) {
      if (face.indices.length < 3) continue;

      final p0 = projPts[face.indices[0]];
      final p1 = projPts[face.indices[1]];
      final p2 = projPts[face.indices[2]];

      // 3D Normal vector calculation in camera space
      final v0 = rotVertices[face.indices[0]];
      final v1 = rotVertices[face.indices[1]];
      final v2 = rotVertices[face.indices[2]];

      final edge1 = v1 - v0;
      final edge2 = v2 - v0;
      V3 normal = edge1.cross(edge2).normalized();

      // Two-sided illumination: if polygon winding is clockwise on screen, flip normal towards viewer
      final winding = (p1.dx - p0.dx) * (p2.dy - p0.dy) - (p1.dy - p0.dy) * (p2.dx - p0.dx);
      if (winding > 0.0) {
        normal = normal * -1.0;
      }

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

      // Shaded color per diagram display mode
      final Color shadedColor;
      if (diagramMode == MascotDiagramMode.holoBlueprint) {
        shadedColor = face.isEye
            ? Colors.white
            : (face.isPlinth
                ? const Color(0x14020C1C)
                : glowColor.withValues(alpha: 0.12));
      } else if (diagramMode == MascotDiagramMode.tacticalXRay) {
        shadedColor = face.isEye
            ? Colors.white
            : glowColor.withValues(alpha: face.isPlinth ? 0.16 : 0.28);
      } else {
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

      // Draw sharp metallic facet crease edge per diagram mode
      if (face.isEye) {
        final centerPt = projPts[face.indices[0]];
        final eyeGlow = Paint()
          ..color = face.color.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(centerPt, 5.0, eyeGlow);
      } else {
        if (diagramMode == MascotDiagramMode.holoBlueprint) {
          edgePaint.color = glowColor.withValues(alpha: 0.88);
          edgePaint.strokeWidth = 1.1;
        } else if (diagramMode == MascotDiagramMode.tacticalXRay) {
          edgePaint.color = Colors.white.withValues(alpha: 0.78);
          edgePaint.strokeWidth = 1.0;
        } else {
          edgePaint.color = Colors.white.withValues(alpha: 0.08 + (face.specular * 0.28).clamp(0.0, 0.28));
          edgePaint.strokeWidth = 0.6;
        }
        canvas.drawPath(path, edgePaint);
      }
    }

    // 5. Holographic blueprint vertex coordinate dots
    if (diagramMode == MascotDiagramMode.holoBlueprint) {
      final dotPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      for (final pt in projPts) {
        canvas.drawCircle(pt, 1.6, dotPaint);
      }
    }

    // 6. Tactical X-Ray internal elemental energy reactor core
    if (diagramMode == MascotDiagramMode.tacticalXRay) {
      final corePaint = Paint()
        ..color = glowColor.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawCircle(Offset(center.dx, center.dy + 8), 24.0, corePaint);
    }

    // 7. Interactive 3D Technical Diagram Callout Pins & Leader Lines
    if (showCallouts && hotspots.isNotEmpty) {
      final pinOuterPaint = Paint()..style = PaintingStyle.fill;
      final pinInnerPaint = Paint()..style = PaintingStyle.fill;
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = glowColor.withValues(alpha: 0.90);

      for (int hIdx = 0; hIdx < hotspots.length; hIdx++) {
        final spot = hotspots[hIdx];
        final v = spot.position3D;

        // Project hotspot in 3D camera space
        final x1 = v.x * cosY + v.z * sinY;
        final z1 = -v.x * sinY + v.z * cosY;
        final y2 = v.y * cosX - z1 * sinX;
        final z2 = v.y * sinX + z1 * cosX;

        // Only render callout if in visible front hemisphere
        if (z2 < -60.0) continue;

        final zCam = z2 + cameraDistance;
        final scale = fov / math.max(10.0, zCam);
        final anchor = Offset(center.dx + x1 * scale, center.dy + y2 * scale);

        // Leader line geometry
        final isLeft = x1 < 0;
        final knee = Offset(anchor.dx + (isLeft ? -24 : 24), anchor.dy - 16);
        final tagX = knee.dx + (isLeft ? -45 : 45);
        final tagY = knee.dy.clamp(16.0, size.height - 16.0);

        // Draw glowing anchor pin
        pinOuterPaint.color = glowColor.withValues(alpha: 0.35);
        canvas.drawCircle(anchor, 7.0, pinOuterPaint);
        pinInnerPaint.color = glowColor;
        canvas.drawCircle(anchor, 3.5, pinInnerPaint);
        canvas.drawCircle(anchor, 1.8, Paint()..color = Colors.white);

        // Draw leader dogleg line
        final linePath = Path()
          ..moveTo(anchor.dx, anchor.dy)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(tagX, tagY);
        canvas.drawPath(linePath, linePaint);

        // Draw technical diagram label text
        final textSpan = TextSpan(
          children: [
            TextSpan(
              text: '${spot.label}\n',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(color: Colors.black.withValues(alpha: 0.95), blurRadius: 4),
                ],
              ),
            ),
            TextSpan(
              text: spot.subtitle,
              style: TextStyle(
                color: glowColor.withValues(alpha: 0.95),
                fontSize: 8.0,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black.withValues(alpha: 0.95), blurRadius: 4),
                ],
              ),
            ),
          ],
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: isLeft ? TextAlign.right : TextAlign.left,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 130);

        final textOffset = Offset(
          isLeft ? (tagX - textPainter.width - 4) : (tagX + 4),
          tagY - (textPainter.height / 2),
        );

        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            textOffset.dx - 4,
            textOffset.dy - 2,
            textPainter.width + 8,
            textPainter.height + 4,
          ),
          const Radius.circular(6),
        );
        canvas.drawRRect(badgeRect, Paint()..color = Colors.black.withValues(alpha: 0.85));
        canvas.drawRRect(
          badgeRect,
          Paint()
            ..color = glowColor.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );

        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Mascot3DRendererPainter oldDelegate) {
    return oldDelegate.rotX != rotX ||
        oldDelegate.rotY != rotY ||
        oldDelegate.mesh != mesh ||
        oldDelegate.finish != finish ||
        oldDelegate.diagramMode != diagramMode ||
        oldDelegate.showCallouts != showCallouts ||
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
      ..color = color.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Technical concentric coordinate rings
    canvas.drawCircle(center, radius * 0.94, ringPaint);
    canvas.drawCircle(center, radius * 0.76, ringPaint);
    canvas.drawCircle(center, radius * 0.54, ringPaint..strokeWidth = 0.9);
    canvas.drawCircle(center, radius * 0.32, ringPaint..strokeWidth = 0.7);

    // 16 Azimuth radial coordinate spokes
    final spokePaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;

    for (int i = 0; i < 16; i++) {
      final angle = (i * 22.5) * math.pi / 180;
      final isMajor = (i % 4 == 0);
      spokePaint.strokeWidth = isMajor ? 1.6 : 0.8;
      spokePaint.color = isMajor ? color.withValues(alpha: 0.85) : color.withValues(alpha: 0.35);

      final p1 = Offset(center.dx + math.cos(angle) * (radius * 0.32), center.dy + math.sin(angle) * (radius * 0.32));
      final p2 = Offset(center.dx + math.cos(angle) * (radius * 0.94), center.dy + math.sin(angle) * (radius * 0.94));
      canvas.drawLine(p1, p2, spokePaint);
    }

    // Cardinal coordinate labels: E, S, W, N
    const cardinalLabels = ['E', 'S', 'W', 'N'];
    final textStyle = TextStyle(
      color: color.withValues(alpha: 0.9),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      fontFamily: 'monospace',
    );

    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * math.pi / 180;
      final lx = center.dx + math.cos(angle) * (radius * 0.85);
      final ly = center.dy + math.sin(angle) * (radius * 0.85);

      final tp = TextPainter(
        text: TextSpan(text: cardinalLabels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _AltarRunicPainter oldDelegate) => oldDelegate.color != color;
}
