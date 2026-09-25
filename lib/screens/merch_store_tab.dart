import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../services/voucher_security_service.dart';

class MerchProduct {
  final String id;
  final String name;
  final String price;
  final double rating;
  final String imageUrl;
  final String
  category; // 'Hoodies', 'Tees', 'Accessories', 'Limited Edition 🔥'
  final String house; // 'all', 'ruby', 'sapphire', 'emerald', 'topaz'
  final String description;
  final bool isHero;

  const MerchProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.imageUrl,
    required this.category,
    required this.house,
    required this.description,
    this.isHero = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'rating': rating,
    'imageUrl': imageUrl,
    'category': category,
    'house': house,
    'description': description,
    'isHero': isHero,
  };

  factory MerchProduct.fromJson(Map<String, dynamic> json) => MerchProduct(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    price: json['price'] as String? ?? '',
    rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
    imageUrl: json['imageUrl'] as String? ?? '',
    category: json['category'] as String? ?? '',
    house: json['house'] as String? ?? 'all',
    description: json['description'] as String? ?? '',
    isHero: json['isHero'] as bool? ?? false,
  );
}

class CartItem {
  final MerchProduct product;
  final String size;
  int _qty;

  CartItem({required this.product, required this.size, int qty = 1})
      : _qty = qty.clamp(1, 99);

  int get qty => _qty;
  set qty(int value) => _qty = value.clamp(1, 99);

  int get pointsPrice {
    final parsed =
        int.tryParse(product.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return parsed * _qty;
  }

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'size': size,
    'qty': _qty,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    product: MerchProduct.fromJson(json['product'] as Map<String, dynamic>),
    size: json['size'] as String? ?? 'M',
    qty: ((json['qty'] as num?)?.toInt() ?? 1).clamp(1, 99),
  );
}

class OrderRecord {
  final String receiptId;
  final List<CartItem> items;
  final int totalPts;
  final DateTime date;
  final String qrData;

  OrderRecord({
    required this.receiptId,
    required this.items,
    required this.totalPts,
    required this.date,
    required this.qrData,
  });

  Map<String, dynamic> toJson() => {
    'receiptId': receiptId,
    'items': items.map((i) => i.toJson()).toList(),
    'totalPts': totalPts,
    'date': date.toIso8601String(),
    'qrData': qrData,
  };

  factory OrderRecord.fromJson(Map<String, dynamic> json) => OrderRecord(
    receiptId: json['receiptId'] as String? ?? '',
    items: (json['items'] as List<dynamic>? ?? [])
        .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
        .toList(),
    totalPts: json['totalPts'] as int? ?? 0,
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    qrData: json['qrData'] as String? ?? '',
  );
}

// Global static storage so cart and wallet orders NEVER get lost when switching tabs
class GlobalWalletStore {
  static final List<CartItem> cart = [];
  static final List<OrderRecord> orders = [];
  static final Set<String> favoriteIds = {'hero_champion', 'drop_varsity'};

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJsonList = prefs.getStringList('saved_wallet_orders');
      if (ordersJsonList != null) {
        orders.clear();
        for (var str in ordersJsonList) {
          try {
            final order = OrderRecord.fromJson(
              jsonDecode(str) as Map<String, dynamic>,
            );
            if (order.receiptId == 'ASB-984210' ||
                order.receiptId == 'ASB-771923') {
              continue;
            }
            orders.add(order);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static Future<void> saveOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = orders.map((o) => jsonEncode(o.toJson())).toList();
      await prefs.setStringList('saved_wallet_orders', jsonList);
    } catch (_) {}
  }

  static Future<void> clearAllBills() async {
    orders.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_wallet_orders');
    } catch (_) {}
  }
}

class MerchStoreTab extends StatefulWidget {
  final String userHouse; // e.g. 'ruby'
  final Color houseColor;
  final Color houseDark;
  final String? scholarNo;
  final String? studentName;

  const MerchStoreTab({
    super.key,
    required this.userHouse,
    required this.houseColor,
    required this.houseDark,
    this.scholarNo,
    this.studentName,
  });

  @override
  State<MerchStoreTab> createState() => _MerchStoreTabState();
}

class _MerchStoreTabState extends State<MerchStoreTab> {
  late String _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<MerchProduct> _allProducts = [
    const MerchProduct(
      id: 'hero_champion',
      name: 'The Premium Champion Hoodie',
      price: '450 Pts (BHD 14.500)',
      rating: 4.9,
      imageUrl:
          'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?auto=format&fit=crop&w=800&q=80',
      category: 'Hoodies',
      house: 'all',
      description:
          'Engineered with a premium heavy-weight cotton fleece blend. Features double-stitched reinforced seams, custom house embroidery patch on the sleeve, and zero-shrink thermal treatment.',
      isHero: true,
    ),
    const MerchProduct(
      id: 'drop_varsity',
      name: 'Championship Gold Varsity Jacket',
      price: '650 Pts (BHD 22.000)',
      rating: 5.0,
      imageUrl:
          'https://images.unsplash.com/photo-1551028719-00167b16eac5?auto=format&fit=crop&w=800&q=80',
      category: 'Limited Edition 🔥',
      house: 'all',
      description:
          'Ultra-rare collector piece. Wool-blend body with genuine leather sleeves, custom 3D house embroidery, and gold-plated snap buttons. Hand-numbered inside lining.',
    ),
    const MerchProduct(
      id: 'drop_earbuds',
      name: 'House Hub Pro Wireless Earbuds Case',
      price: '250 Pts (BHD 7.500)',
      rating: 4.9,
      imageUrl:
          'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=600&q=80',
      category: 'Limited Edition 🔥',
      house: 'all',
      description:
          'Armor-grade matte silicone protective case stamped with your house crest. Includes heavy-duty aluminum carabiner and wireless charging compatibility.',
    ),
    const MerchProduct(
      id: 'ruby_hoodie',
      name: 'Ruby House Elite Hoodie',
      price: '380 Pts (BHD 12.000)',
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1509967419530-da38b4704bc6?auto=format&fit=crop&w=600&q=80',
      category: 'Hoodies',
      house: 'ruby',
      description:
          'Rep the Red Dragon! Crafted from ultra-soft French terry fabric with bold Ruby House lettering across the chest and reflective safety accents.',
    ),
    const MerchProduct(
      id: 'sapphire_hoodie',
      name: 'Sapphire Crest Pullover',
      price: '380 Pts (BHD 12.000)',
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=600&q=80',
      category: 'Hoodies',
      house: 'sapphire',
      description:
          'Deep ocean blue heavy-weight hoodie featuring the Sapphire Crest embroidered in metallic silver thread. Snug ribbed cuffs and spacious pouch pocket.',
    ),
    const MerchProduct(
      id: 'emerald_tee',
      name: 'Emerald Performance Tee',
      price: '180 Pts (BHD 6.500)',
      rating: 4.7,
      imageUrl:
          'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=600&q=80',
      category: 'Tees',
      house: 'emerald',
      description:
          'Breathable micro-mesh athletic t-shirt designed for inter-house sports tournaments. Moisture-wicking technology keeps you cool under intense heat.',
    ),
    const MerchProduct(
      id: 'topaz_tee',
      name: 'Topaz Solar Graphic Tee',
      price: '180 Pts (BHD 6.500)',
      rating: 4.9,
      imageUrl:
          'https://images.unsplash.com/photo-1583743814966-8936f5b7be1a?auto=format&fit=crop&w=600&q=80',
      category: 'Tees',
      house: 'topaz',
      description:
          'Vibrant golden ringed tee with 100% organic ring-spun combed cotton. Soft wash feel with anti-fade UV protection print.',
    ),
    const MerchProduct(
      id: 'asb_cap',
      name: 'Official ASB Varsity Cap',
      price: '140 Pts (BHD 4.500)',
      rating: 4.6,
      imageUrl:
          'https://images.unsplash.com/photo-1588850561407-ed78c282e89b?auto=format&fit=crop&w=600&q=80',
      category: 'Accessories',
      house: 'all',
      description:
          'Structured 6-panel snapback hat with 3D raised ASB embroidery. Adjustable brass buckle closure fits all grades perfectly.',
    ),
    const MerchProduct(
      id: 'hydro_bottle',
      name: 'Insulated Hydro Flask (1L)',
      price: '160 Pts (BHD 5.500)',
      rating: 4.9,
      imageUrl:
          'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
      category: 'Accessories',
      house: 'all',
      description:
          'Double-wall vacuum insulation keeps drinks ice cold for 24 hours. Includes laser-etched school crest and leak-proof straw lid.',
    ),
    const MerchProduct(
      id: 'duffel_bag',
      name: 'ASB Elite Gym Duffel Bag',
      price: '320 Pts (BHD 15.000)',
      rating: 4.9,
      imageUrl:
          'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
      category: 'Accessories',
      house: 'all',
      description:
          'Water-resistant ballistic nylon sports duffel with dedicated ventilated sneaker compartment and reinforced padded carry handles.',
    ),
  ];

  int _userPoints = 120;
  bool _pointsLoaded = false;
  bool _isProcessingOrder = false;

  @override
  void initState() {
    super.initState();
    GlobalWalletStore.init().then((_) {
      if (mounted) setState(() {});
    });
    _selectedCategory =
        'For You (${widget.userHouse[0].toUpperCase()}${widget.userHouse.substring(1)})';
    _loadUserPoints();
  }

  Future<void> _loadUserPoints() async {
    try {
      final sNo = widget.scholarNo?.trim();
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (sNo != null && sNo.isNotEmpty && sNo != '---') {
        final doc = await FirebaseFirestore.instance
            .collection('house_contributors')
            .doc(sNo)
            .get();
        if (doc.exists && doc.data() != null) {
          final pts = (doc.data()?['total_contributed'] as num?)?.toInt() ?? 0;
          if (mounted) {
            setState(() {
              _userPoints = pts < 0 ? 0 : pts;
              _pointsLoaded = true;
            });
            return;
          }
        }
      }

      if (uid != null) {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (uDoc.exists && uDoc.data() != null) {
          final pts =
              (uDoc.data()?['points_contributed'] as num?)?.toInt() ?? 0;
          if (mounted) {
            setState(() {
              _userPoints = pts < 0 ? 0 : pts;
              _pointsLoaded = true;
            });
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _pointsLoaded = true);
    }
  }

  void _showInsufficientPointsDialog(int requiredPts) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: Colors.amber[800], size: 28),
            const SizedBox(width: 10),
            const Text(
              'Points Required',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This purchase requires $requiredPts House Points.\nYour current balance is $_userPoints Pts (${requiredPts - _userPoints} points short).',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.houseColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.houseColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: widget.houseColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Earn points by submitting competition certificates, answering arena quizzes, or getting faculty merits!',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.houseColor,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Back to Store',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _verifyAndDeductPoints(
    int totalPts,
    String receiptId,
    String description,
  ) async {
    if (totalPts <= 0) return false;
    if (_userPoints < totalPts) {
      AppHaptics.error();
      _showInsufficientPointsDialog(totalPts);
      return false;
    }

    final sNo = widget.scholarNo?.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      final firestore = FirebaseFirestore.instance;
      final contribRef = (sNo != null && sNo.isNotEmpty && sNo != '---')
          ? firestore.collection('house_contributors').doc(sNo)
          : null;
      final uRef = (uid != null && uid.isNotEmpty)
          ? firestore.collection('users').doc(uid)
          : null;

      await firestore.runTransaction((tx) async {
        // Step 1: All reads FIRST
        DocumentSnapshot? contribSnap;
        DocumentSnapshot? userSnap;

        if (contribRef != null) {
          contribSnap = await tx.get(contribRef);
        }
        if (uRef != null) {
          userSnap = await tx.get(uRef);
        }

        // Check contributor balance if record exists
        int contribPts = 0;
        if (contribSnap != null && contribSnap.exists) {
          final data = contribSnap.data() as Map<String, dynamic>?;
          contribPts = (data?['total_contributed'] as num?)?.toInt() ?? 0;
          if (contribPts < totalPts) {
            throw Exception('Insufficient verified points ($contribPts < $totalPts)');
          }
        }

        // Check user profile balance if user doc exists
        int userPts = 0;
        if (userSnap != null && userSnap.exists) {
          final uData = userSnap.data() as Map<String, dynamic>?;
          userPts = (uData?['points_contributed'] as num?)?.toInt() ?? 0;
          if (userPts < totalPts && contribSnap == null) {
            throw Exception('Insufficient verified points in user profile ($userPts < $totalPts)');
          }
        }

        // Step 2: All writes SECOND (atomic execution)
        if (contribRef != null) {
          if (contribSnap != null && contribSnap.exists) {
            final nextContrib = (contribPts - totalPts).clamp(0, 999999);
            tx.update(contribRef, {
              'total_contributed': nextContrib,
              'last_updated': FieldValue.serverTimestamp(),
            });
          } else {
            final nextContrib = (_userPoints - totalPts).clamp(0, 999999);
            tx.set(contribRef, {
              'scholar_no': sNo,
              'student_name': widget.studentName ?? 'Scholar $sNo',
              'house_name': widget.userHouse.toLowerCase(),
              'class_level': 'Senior Tier',
              'total_contributed': nextContrib,
              'merits_count': 0,
              'demerits_count': 0,
              'last_updated': FieldValue.serverTimestamp(),
            });
          }
        }

        if (uRef != null && userSnap != null && userSnap.exists) {
          final nextUserPts = (userPts - totalPts).clamp(0, 999999);
          tx.update(uRef, {
            'points_contributed': nextUserPts,
            'last_updated': FieldValue.serverTimestamp(),
          });
        }
      });

      // Step 3: Deduct local points ONLY after Firestore transaction commits successfully
      if (mounted) {
        setState(() {
          _userPoints = (_userPoints - totalPts).clamp(0, 999999);
        });
      } else {
        _userPoints = (_userPoints - totalPts).clamp(0, 999999);
      }

      // Step 4: Dispatch in-app notification if user doc exists
      if (uid != null) {
        try {
          await firestore.collection('users').doc(uid).collection('notifications').add({
            'title': '🛍️ Merch Pass Redeemed (-$totalPts Pts)',
            'body':
                'Successfully ordered $description! Digital pass #$receiptId generated and saved to your Digital Wallet.',
            'timestamp': FieldValue.serverTimestamp(),
            'is_read': false,
            'type': 'store_purchase',
          });
        } catch (_) {}
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Points redemption transaction failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFavorite(String productId) {
    AppHaptics.tap();
    setState(() {
      if (GlobalWalletStore.favoriteIds.contains(productId)) {
        GlobalWalletStore.favoriteIds.remove(productId);
      } else {
        GlobalWalletStore.favoriteIds.add(productId);
      }
    });
  }

  void _addToCart(MerchProduct product, {String size = 'M', int qty = 1}) {
    final safeQty = qty.clamp(1, 99);
    AppHaptics.light();
    setState(() {
      final existingIndex = GlobalWalletStore.cart.indexWhere(
        (item) => item.product.id == product.id && item.size == size,
      );
      if (existingIndex != -1) {
        GlobalWalletStore.cart[existingIndex].qty =
            (GlobalWalletStore.cart[existingIndex].qty + safeQty).clamp(1, 99);
      } else {
        GlobalWalletStore.cart.add(
          CartItem(product: product, size: size, qty: safeQty),
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.shopping_bag_rounded, color: widget.houseColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${safeQty}x ${product.name} ($size) added to bag!'),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Instant 1-Click Buy directly into Apple Wallet
  void _instantBuyToWallet(
    MerchProduct product, {
    String size = 'M',
    int qty = 1,
  }) async {
    if (_isProcessingOrder) return;
    _isProcessingOrder = true;
    try {
      final safeQty = qty.clamp(1, 99);
      final parsedPrice =
          int.tryParse(product.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final totalPts = parsedPrice * safeQty;
      final receiptId =
          'ASB-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

      final allowed = await _verifyAndDeductPoints(
        totalPts,
        receiptId,
        '${safeQty}x ${product.name} ($size)',
      );
      if (!allowed) return;

    AppHaptics.success();
    final itemsList = [CartItem(product: product, size: size, qty: safeQty)];
    final qrData = VoucherSecurityService.generateVoucherPayload(
      billNo: receiptId,
      points: totalPts,
      scholarNo: widget.scholarNo ?? '2310910',
      items: itemsList
          .map((i) => '${i.qty}x ${i.product.name} (${i.size})')
          .toList(),
    );

    final newOrder = OrderRecord(
      receiptId: receiptId,
      items: itemsList,
      totalPts: totalPts,
      date: DateTime.now(),
      qrData: qrData,
    );

    setState(() {
      GlobalWalletStore.orders.add(newOrder);
    });
    GlobalWalletStore.saveOrders();

    // Save order to Firestore database
    FirebaseFirestore.instance
        .collection('orders')
        .doc(receiptId)
        .set({
          'receipt_id': receiptId,
          'user_id': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
          'scholar_no': widget.scholarNo ?? '',
          'student_name': widget.studentName ?? '',
          'house': widget.userHouse.toLowerCase(),
          'total_pts': totalPts,
          'items': itemsList
              .map(
                (i) => {
                  'name': i.product.name,
                  'size': i.size,
                  'qty': i.qty,
                  'pts': i.pointsPrice,
                },
              )
              .toList(),
          'created_at': FieldValue.serverTimestamp(),
          'status': 'verified',
        })
        .catchError((_) {});

    if (!mounted) return;
    _showDigitalWalletPass(newOrder);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      } else {
        _isProcessingOrder = false;
      }
    }
  }

  void _showDigitalWalletPass(OrderRecord order) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: 420,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: const Color(0xFF111827), // Sleek dark wallet aesthetic
            border: Border.all(
              color: widget.houseColor.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.houseColor.withValues(alpha: 0.25),
                blurRadius: 24,
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Apple Wallet Pass Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: widget.houseColor,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'OFFICIAL HOUSE PASS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.apple,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 26,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // White QR Card Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Bill #${order.receiptId}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.userHouse.toUpperCase()} HOUSE STORE CLAIM',
                        style: TextStyle(
                          color: widget.houseColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: order.qrData.trim().isNotEmpty
                            ? order.qrData
                            : 'ASB-ORDER-${order.receiptId}',
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        errorStateBuilder: (cxt, err) {
                          return Container(
                            width: 180,
                            height: 180,
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 64,
                                  color: widget.houseColor,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Claim Pass Active',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ITEMS PURCHASED:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...order.items.map(
                              (it) => Text(
                                '• ${it.qty}x ${it.product.name} (${it.size})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Order breakdown info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ITEMS CLAIMED',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.items.fold<int>(0, (acc, i) => acc + i.qty)} Items',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'TOTAL POINTS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.totalPts} Pts',
                            style: TextStyle(
                              color: widget.houseColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Interactive Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Save Pass to Wallet / Print Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.houseColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.greenAccent,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Pass saved to digital wallet! Present QR code at store counter.',
                                ),
                              ),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF1F2937),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text(
                      'Close Pass Card',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrdersLockerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setLockerState) {
          final orders = GlobalWalletStore.orders;
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wallet_rounded, color: widget.houseColor),
                    const SizedBox(width: 10),
                    Text(
                      'MY DIGITAL WALLET & PASSES (${orders.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Your digital wallet has no saved passes yet.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Claim or buy merch items to generate QR passes.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: orders.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final order =
                                orders[orders.length -
                                    1 -
                                    index]; // latest first
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: widget.houseColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.verified_rounded,
                                              color: Colors.amber,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Pass #${order.receiptId}',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          'READY AT STORE 🟢',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    order.items
                                        .map(
                                          (e) =>
                                              "${e.qty}x ${e.product.name} (${e.size})",
                                        )
                                        .join(", "),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${order.totalPts} Pts Paid',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: widget.houseColor,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.qr_code_rounded,
                                          size: 16,
                                        ),
                                        label: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'View Pass ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: widget.houseColor,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(0, 36),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _showDigitalWalletPass(order);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProductDetailSheet(MerchProduct product) {
    String selectedSize = 'M';
    int selectedQty = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isFav = GlobalWalletStore.favoriteIds.contains(product.id);

          return Container(
            height: MediaQuery.of(context).size.height * 0.90,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Loyalty Discount Badge
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: widget.houseColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: widget.houseColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.diamond_rounded,
                                color: widget.houseColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'ASB ELITE MEMBER: 10% House Loyalty Discount Applied!',
                                  style: TextStyle(
                                    color: widget.houseColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // High-res image showcase
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                height: 320,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  height: 320,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${product.rating} (128 Reviews)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                child: IconButton(
                                  onPressed: () {
                                    _toggleFavorite(product.id);
                                    setSheetState(() {});
                                  },
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFav ? Colors.red : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              product.price,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: widget.houseColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'SELECT SIZE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: ['XS', 'S', 'M', 'L', 'XL'].map((size) {
                            final isSelected = selectedSize == size;
                            return GestureDetector(
                              onTap: () =>
                                  setSheetState(() => selectedSize = size),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 12),
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? widget.houseColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? widget.houseColor
                                        : Colors.grey.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: widget.houseColor.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    size,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'QUANTITY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Colors.grey,
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_rounded,
                                      size: 18,
                                    ),
                                    onPressed: selectedQty > 1
                                        ? () =>
                                              setSheetState(() => selectedQty--)
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      '$selectedQty',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        setSheetState(() => selectedQty++),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'FABRIC & DETAILS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Verified Student Reviews Section
                        const Text(
                          'VERIFIED STUDENT REVIEWS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Sarah K. (Grade 11 ${widget.userHouse.toUpperCase()})',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '"Quality is insane! The embroidery patch on the sleeve looks so premium. Ready for pickup at counter same day!"',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 18,
                          ),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Add to Bag',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.houseColor.withValues(
                              alpha: 0.15,
                            ),
                            foregroundColor: widget.houseColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _addToCart(
                              product,
                              size: selectedSize,
                              qty: selectedQty,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.wallet_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Buy & Save to Wallet ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.houseColor,
                            foregroundColor: Colors.white,
                            elevation: 6,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _instantBuyToWallet(
                              product,
                              size: selectedSize,
                              qty: selectedQty,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCartReviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setCartState) {
          final cart = GlobalWalletStore.cart;
          final totalPts = cart.fold<int>(
            0,
            (acc, item) => acc + item.pointsPrice,
          );
          final totalItems = cart.fold<int>(0, (acc, item) => acc + item.qty);

          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SHOPPING BAG ($totalItems ITEMS)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: cart.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Your shopping bag is empty.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: cart.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 24),
                          itemBuilder: (context, index) {
                            final item = cart[index];
                            return Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: item.product.imageUrl,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: widget.houseColor
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Size: ${item.size}',
                                              style: TextStyle(
                                                color: widget.houseColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              item.product.price,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (item.qty > 1) {
                                            item.qty = (item.qty - 1).clamp(1, 99);
                                          } else {
                                            cart.removeAt(index);
                                          }
                                        });
                                        setCartState(() {});
                                      },
                                    ),
                                    Text(
                                      '${item.qty}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: widget.houseColor,
                                      ),
                                      onPressed: () {
                                        setState(() => item.qty = (item.qty + 1).clamp(1, 99));
                                        setCartState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                ),
                if (cart.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Estimated Points Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$totalPts Pts',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: widget.houseColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Available Balance: $_userPoints Pts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _userPoints >= totalPts
                                    ? Colors.green[700]
                                    : Colors.redAccent,
                              ),
                            ),
                            if (_userPoints < totalPts)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '-${totalPts - _userPoints} Pts Needed',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isProcessingOrder ? null : () async {
                              if (_isProcessingOrder) return;
                              setState(() => _isProcessingOrder = true);
                              setCartState(() {});
                              try {
                                final receiptId =
                                    'ASB-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                                final itemsList = List<CartItem>.from(cart);

                              final allowed = await _verifyAndDeductPoints(
                                totalPts,
                                receiptId,
                                '${itemsList.length} Merch Bag Items',
                              );
                              if (!allowed) return;

                              final qrData = VoucherSecurityService.generateVoucherPayload(
                                billNo: receiptId,
                                points: totalPts,
                                scholarNo: widget.scholarNo ?? '2310910',
                                items: itemsList
                                    .map(
                                      (i) =>
                                          '${i.qty}x ${i.product.name} (${i.size})',
                                    )
                                    .toList(),
                              );
                              final newOrder = OrderRecord(
                                receiptId: receiptId,
                                items: itemsList,
                                totalPts: totalPts,
                                date: DateTime.now(),
                                qrData: qrData,
                              );
                              setState(() {
                                GlobalWalletStore.orders.add(newOrder);
                                GlobalWalletStore.cart.clear();
                              });
                              GlobalWalletStore.saveOrders();

                              // Save order to Firestore database
                              FirebaseFirestore.instance
                                  .collection('orders')
                                  .doc(receiptId)
                                  .set({
                                    'receipt_id': receiptId,
                                    'user_id':
                                        FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid ??
                                        'anonymous',
                                    'scholar_no': widget.scholarNo ?? '',
                                    'student_name': widget.studentName ?? '',
                                    'house': widget.userHouse.toLowerCase(),
                                    'total_pts': totalPts,
                                    'items': itemsList
                                        .map(
                                          (i) => {
                                            'name': i.product.name,
                                            'size': i.size,
                                            'qty': i.qty,
                                            'pts': i.pointsPrice,
                                          },
                                        )
                                        .toList(),
                                    'created_at': FieldValue.serverTimestamp(),
                                    'status': 'verified',
                                  })
                                  .catchError((_) {});

                              if (!context.mounted) return;
                              Navigator.pop(context);
                              Future.delayed(
                                const Duration(milliseconds: 200),
                                () {
                                  if (mounted) {
                                    _showDigitalWalletPass(newOrder);
                                  }
                                },
                              );
                              } finally {
                                if (mounted) {
                                  setState(() => _isProcessingOrder = false);
                                  setCartState(() {});
                                } else {
                                  _isProcessingOrder = false;
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.houseColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Confirm Order & Open Wallet Pass ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userHouseLabel =
        '${widget.userHouse[0].toUpperCase()}${widget.userHouse.substring(1)}';
    final categories = [
      'For You ($userHouseLabel)',
      '💳 Digital Wallet (${GlobalWalletStore.orders.length})',
      'Limited Edition 🔥',
      'Favorites ❤️',
      'All Houses',
      'Hoodies',
      'Tees',
      'Accessories',
    ];

    // Filter products
    List<MerchProduct> filtered = _allProducts.where((p) => !p.isHero).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (p) =>
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    } else if (_selectedCategory == 'Favorites ❤️') {
      filtered = _allProducts
          .where((p) => GlobalWalletStore.favoriteIds.contains(p.id))
          .toList();
    } else if (_selectedCategory.startsWith('For You')) {
      filtered = filtered
          .where(
            (p) =>
                p.house == widget.userHouse.toLowerCase() || p.house == 'all',
          )
          .toList();
    } else if (_selectedCategory == 'All Houses') {
      // keep all non-hero
    } else {
      filtered = filtered
          .where((p) => p.category == _selectedCategory)
          .toList();
    }

    final heroProduct = _allProducts.firstWhere(
      (p) => p.isHero,
      orElse: () => _allProducts.first,
    );
    final totalCartItems = GlobalWalletStore.cart.fold<int>(
      0,
      (acc, item) => acc + item.qty,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'wallet_btn',
            onPressed: _showOrdersLockerSheet,
            backgroundColor: const Color(0xFF111827),
            foregroundColor: Colors.white,
            elevation: 8,
            icon: const Icon(Icons.wallet_rounded, color: Colors.amber),
            label: Text(
              'My Wallet (${GlobalWalletStore.orders.length})',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'bag_btn',
            onPressed: _showCartReviewSheet,
            backgroundColor: widget.houseColor,
            foregroundColor: Colors.white,
            elevation: 8,
            icon: const Icon(Icons.shopping_bag_rounded),
            label: Text(
              '$totalCartItems Bag',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drop of the Week Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.houseColor, widget.houseDark],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.houseColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.amber,
                    size: 38,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'LIVE WEEKLY DROP',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Ends in 02d : 14h',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rep Your Allegiance: Premium $userHouseLabel Collection',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Student Points Wallet Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.houseColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.houseColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.houseColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      color: widget.houseColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR HOUSE POINTS WALLET',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: widget.houseColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _pointsLoaded
                              ? '$_userPoints Pts Available to Redeem'
                              : 'Syncing Points Balance...',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.houseColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Store Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search official school hoodies, drops, caps...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: widget.houseColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Category Switcher Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected =
                      _selectedCategory == cat && _searchQuery.isEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () {
                        if (cat.startsWith('💳 Digital Wallet')) {
                          _showOrdersLockerSheet();
                        } else {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _selectedCategory = cat;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.houseColor
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isSelected
                                ? widget.houseColor
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: widget.houseColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // Featured Hero Product (Only shown when not searching and not inside sub-category)
            if (_searchQuery.isEmpty &&
                _selectedCategory.startsWith('For You')) ...[
              GestureDetector(
                onTap: () => _showProductDetailSheet(heroProduct),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: heroProduct.imageUrl,
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Official ASB Flagship Uniform',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: IconButton(
                              onPressed: () => _toggleFavorite(heroProduct.id),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                              icon: Icon(
                                GlobalWalletStore.favoriteIds.contains(
                                      heroProduct.id,
                                    )
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color:
                                    GlobalWalletStore.favoriteIds.contains(
                                      heroProduct.id,
                                    )
                                    ? Colors.red
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'FLAGSHIP RELEASE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.grey,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        heroProduct.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  heroProduct.price,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: widget.houseColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${heroProduct.rating}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            _addToCart(heroProduct),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          minimumSize: const Size(50, 40),
                                          backgroundColor: widget.houseColor
                                              .withValues(alpha: 0.15),
                                          foregroundColor: widget.houseColor,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Add',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _instantBuyToWallet(heroProduct),
                                          icon: const Icon(
                                            Icons.wallet_rounded,
                                            size: 16,
                                          ),
                                          label: const FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Buy to Wallet ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            minimumSize: const Size(90, 40),
                                            backgroundColor: widget.houseColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            Text(
              _searchQuery.isNotEmpty
                  ? '🔍 Search Results (${filtered.length})'
                  : '✨ Explore Collection',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No apparel found matching "$_searchQuery"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final prod = filtered[index];
                  final isFav = GlobalWalletStore.favoriteIds.contains(prod.id);
                  return _MerchCard(
                    product: prod,
                    houseColor: widget.houseColor,
                    isFav: isFav,
                    onFavToggle: () => _toggleFavorite(prod.id),
                    onTap: () => _showProductDetailSheet(prod),
                    onAdd: () => _addToCart(prod),
                    onInstantBuy: () => _instantBuyToWallet(prod),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _MerchCard extends StatefulWidget {
  final MerchProduct product;
  final Color houseColor;
  final bool isFav;
  final VoidCallback onFavToggle;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onInstantBuy;

  const _MerchCard({
    required this.product,
    required this.houseColor,
    required this.isFav,
    required this.onFavToggle,
    required this.onTap,
    required this.onAdd,
    required this.onInstantBuy,
  });

  @override
  State<_MerchCard> createState() => _MerchCardState();
}

class _MerchCardState extends State<_MerchCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 1.02),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${widget.product.rating}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: InkWell(
                          onTap: widget.onFavToggle,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: widget.isFav ? Colors.red : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.product.price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: widget.houseColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: widget.onAdd,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: widget.houseColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.add_shopping_cart_rounded,
                                color: widget.houseColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: widget.onInstantBuy,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.houseColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.wallet_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'To Wallet ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
