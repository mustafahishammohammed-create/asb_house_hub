import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class StudentBehaviorEvaluationScreen extends StatefulWidget {
  final String scholarNo;
  final String studentName;
  final String houseName;
  final String classLevel;
  final String evaluatorName;

  const StudentBehaviorEvaluationScreen({
    super.key,
    required this.scholarNo,
    required this.studentName,
    required this.houseName,
    this.classLevel = 'Grade 11',
    this.evaluatorName = 'Faculty Lead',
  });

  @override
  State<StudentBehaviorEvaluationScreen> createState() =>
      _StudentBehaviorEvaluationScreenState();
}

class _StudentBehaviorEvaluationScreenState
    extends State<StudentBehaviorEvaluationScreen> {
  final _authService = AuthService();
  final _reasonController = TextEditingController();

  // Mode: 'well_behaved' vs 'misbehaviour'
  bool _isWellBehaved = true;

  // Selected Points
  int _selectedPoints = 15;

  bool _isSubmitting = false;

  final List<int> _positivePointOptions = [5, 10, 15, 25, 50];
  final List<int> _negativePointOptions = [5, 10, 15, 25, 50];

  final List<String> _positiveQuickReasons = [
    '🌟 Academic Excellence & Initiative',
    '🤝 Helping Peers & Mentorship',
    '🏆 Outstanding Sportsmanship',
    '🧹 Campus Cleanliness & Service',
    '🎤 Assembly & House Leadership',
    '✨ Exemplary Classroom Discipline',
  ];

  final List<String> _negativeQuickReasons = [
    '⚠️ Incomplete Classwork / Homework',
    '⏰ Late to Class / Session',
    '👔 School Uniform Non-Compliance',
    '🗣️ Classroom Disruption & Noise',
    '🚫 Hallway Misconduct & Running',
    '❌ Disrespectful Conduct',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select a reason for this conduct record.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _authService.recordStudentConduct(
        scholarNo: widget.scholarNo,
        studentName: widget.studentName,
        houseName: widget.houseName,
        type: _isWellBehaved ? 'merit' : 'demerit',
        points: _selectedPoints,
        reason: reason,
        teacherName: widget.evaluatorName,
        classLevel: widget.classLevel,
      );

      if (!mounted) return;

      final houseColor = HouseColors.getHouseColor(widget.houseName);
      final deltaText = _isWellBehaved ? '+$_selectedPoints' : '-$_selectedPoints';

      // Show success celebration dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(
                _isWellBehaved
                    ? Icons.stars_rounded
                    : Icons.warning_amber_rounded,
                color: _isWellBehaved ? Colors.green : Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                _isWellBehaved ? 'Merit Awarded!' : 'Demerit Recorded',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_isWellBehaved ? Colors.green : Colors.red)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_isWellBehaved ? Colors.green : Colors.red)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$deltaText Points',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _isWellBehaved ? Colors.green : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isWellBehaved
                          ? 'Added to ${widget.houseName.toUpperCase()} House overall total'
                          : 'Deducted from ${widget.houseName.toUpperCase()} House overall total',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Student: ${widget.studentName} (Scholar #${widget.scholarNo})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Reason: $reason',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Recorded by: ${widget.evaluatorName}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: houseColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Pop evaluation screen
              },
              child: const Text('Complete & Return', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit conduct record: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final houseColor = HouseColors.getHouseColor(widget.houseName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Student Conduct & House Evaluation',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [houseColor, HouseColors.getHouseDarkColor(widget.houseName)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: houseColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : 'S',
                      style: TextStyle(
                        color: houseColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'VERIFIED DIGITAL ID 🟢',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.studentName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Scholar #${widget.scholarNo} • ${widget.houseName.toUpperCase()} House • ${widget.classLevel}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Evaluation Mode Switcher (Misbehaviour vs Well Behaved)
            const Text(
              'Select Conduct Evaluation',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Well Behaved (Merit) Button
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isWellBehaved = true;
                        _reasonController.clear();
                        _selectedPoints = 15;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _isWellBehaved
                            ? const Color(0xFF059669)
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isWellBehaved ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: _isWellBehaved
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            color: _isWellBehaved ? Colors.white : const Color(0xFF059669),
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Well Behaved',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: _isWellBehaved ? Colors.white : null,
                            ),
                          ),
                          Text(
                            'Reward House Points (+)',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isWellBehaved ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Misbehaviour (Demerit) Button
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isWellBehaved = false;
                        _reasonController.clear();
                        _selectedPoints = 10;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: !_isWellBehaved
                            ? const Color(0xFFDC2626)
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: !_isWellBehaved ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: !_isWellBehaved
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.gavel_rounded,
                            color: !_isWellBehaved ? Colors.white : const Color(0xFFDC2626),
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Misbehaviour',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: !_isWellBehaved ? Colors.white : null,
                            ),
                          ),
                          Text(
                            'Deduct House Points (-)',
                            style: TextStyle(
                              fontSize: 11,
                              color: !_isWellBehaved ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Quick Reasons Chips
            Text(
              _isWellBehaved
                  ? '🌟 Select Commendation / Reason'
                  : '⚠️ Select Infraction / Reason',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_isWellBehaved ? _positiveQuickReasons : _negativeQuickReasons).map((reason) {
                final isSelected = _reasonController.text == reason;
                final activeColor = _isWellBehaved ? const Color(0xFF059669) : const Color(0xFFDC2626);
                return ActionChip(
                  label: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  backgroundColor: isSelected
                      ? activeColor
                      : (isDark ? const Color(0xFF1E293B) : Colors.grey[100]),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _reasonController.text = reason;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom Description Input
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _isWellBehaved
                    ? 'What was done? (Commendation Details)'
                    : 'What was done? (Misbehaviour Incident Details)',
                hintText: _isWellBehaved
                    ? 'e.g. Exhibited exceptional teamwork and assisted peers during the science exhibition.'
                    : 'e.g. Student was found roaming the corridors during period 3 without a valid hall pass.',
                filled: true,
                fillColor: isDark ? const Color(0xFF1A2338) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            // Points Selector
            Text(
              _isWellBehaved
                  ? '➕ Select Points to Award (${widget.houseName.toUpperCase()} House)'
                  : '➖ Select Points to Deduct (${widget.houseName.toUpperCase()} House)',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Row(
              children: (_isWellBehaved ? _positivePointOptions : _negativePointOptions).map((pts) {
                final isSelected = _selectedPoints == pts;
                final pointColor = _isWellBehaved ? const Color(0xFF059669) : const Color(0xFFDC2626);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _selectedPoints = pts),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? pointColor
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? pointColor : Colors.grey.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: pointColor.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _isWellBehaved ? '+$pts' : '-$pts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? Colors.white : pointColor,
                              ),
                            ),
                            Text(
                              'Pts',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white70 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Action Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isWellBehaved ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isWellBehaved ? Icons.check_circle_rounded : Icons.remove_circle_rounded,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isWellBehaved
                                ? 'Submit & Award +$_selectedPoints Pts'
                                : 'Submit & Deduct -$_selectedPoints Pts',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Live Recent Conduct Log for this Student
            Text(
              'Past Conduct History for Scholar #${widget.scholarNo}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _authService.getStudentConductStream(widget.scholarNo),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final docs = snapshot.data ?? [];
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2338) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: const Center(
                      child: Text(
                        'No previous infractions or conduct records on file.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length > 3 ? 3 : docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMerit = data['type'] == 'merit';
                    final points = data['points'] ?? 0;
                    final reason = data['reason'] ?? 'Conduct Record';
                    final teacher = data['teacher_name'] ?? 'Faculty';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (isMerit ? Colors.green : Colors.red)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isMerit ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                            color: isMerit ? Colors.green : Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reason,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                Text(
                                  'By $teacher',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            isMerit ? '+$points Pts' : '$points Pts',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isMerit ? Colors.green : Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
