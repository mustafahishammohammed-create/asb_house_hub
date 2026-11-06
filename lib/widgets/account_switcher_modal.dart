import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet for viewing and switching between saved sibling/family accounts.
class AccountSwitcherModal extends StatefulWidget {
  final Color houseColor;
  final String currentHouse;
  final Future<void> Function(SavedAccount) onSwitchAccount;
  final Future<void> Function() onSignOutCurrent;
  final Future<void> Function() onSignOutAll;
  final VoidCallback? onAddSiblingPressed;

  const AccountSwitcherModal({
    super.key,
    required this.houseColor,
    required this.currentHouse,
    required this.onSwitchAccount,
    required this.onSignOutCurrent,
    required this.onSignOutAll,
    this.onAddSiblingPressed,
  });

  static Future<void> show(
    BuildContext context, {
    required Color houseColor,
    required String currentHouse,
    required Future<void> Function(SavedAccount) onSwitchAccount,
    required Future<void> Function() onSignOutCurrent,
    required Future<void> Function() onSignOutAll,
    VoidCallback? onAddSiblingPressed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => AccountSwitcherModal(
        houseColor: houseColor,
        currentHouse: currentHouse,
        onSwitchAccount: onSwitchAccount,
        onSignOutCurrent: onSignOutCurrent,
        onSignOutAll: onSignOutAll,
        onAddSiblingPressed: onAddSiblingPressed,
      ),
    );
  }

  @override
  State<AccountSwitcherModal> createState() => _AccountSwitcherModalState();
}

class _AccountSwitcherModalState extends State<AccountSwitcherModal> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final savedAccounts = AuthService.getSavedAccounts();
    final cachedProfile = AuthService.getCachedProfile();
    final currentScholar = (cachedProfile?['scholar_no'] ??
            AuthService.getCachedScholarNo() ??
            '')
        .toString()
        .trim();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.houseColor,
                        HouseColors.getHouseDarkColor(widget.currentHouse),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.switch_account_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Switch Account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Shared device profiles for siblings & family',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Close dialog',
                  child: IconButton(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (savedAccounts.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'No saved sibling accounts on this device yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ),
            ] else ...[
              ...savedAccounts.map((account) {
                final isActive = account.scholarNo.toLowerCase() ==
                    currentScholar.toLowerCase();
                final accColor = HouseColors.getHouseColor(account.houseName);
                final accEmoji = HouseColors.getHouseEmoji(account.houseName);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? accColor.withValues(alpha: isDark ? 0.15 : 0.08)
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isActive
                          ? accColor
                          : Colors.grey.withValues(alpha: 0.25),
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: accColor.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: isActive
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await widget.onSwitchAccount(account);
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: accColor.withValues(alpha: 0.2),
                                child: Text(
                                  account.fullName.isNotEmpty
                                      ? account.fullName[0].toUpperCase()
                                      : 'S',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: accColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  accEmoji,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        account.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isActive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.green,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 10,
                                              color: Colors.green,
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              'ACTIVE',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 9,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        account.houseName.toUpperCase(),
                                        style: TextStyle(
                                          color: accColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '#${account.scholarNo}',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (account.classLevel != null &&
                                        account.classLevel!.isNotEmpty &&
                                        account.classLevel != '--') ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '• ${account.classLevel}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!isActive) ...[
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accColor.withValues(alpha: 0.15),
                                foregroundColor: accColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await widget.onSwitchAccount(account);
                              },
                              child: const Text(
                                'Switch',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Semantics(
                            button: true,
                            label: 'Remove account from this device',
                            child: IconButton(
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: 'Remove account from this device',
                              onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: const Row(
                                    children: [
                                      Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: Colors.redAccent,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Remove Account?'),
                                    ],
                                  ),
                                  content: Text(
                                    'Are you sure you want to remove ${account.fullName} (#${account.scholarNo}) from this device?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogCtx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(dialogCtx, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await AuthService.removeSavedAccount(
                                  account.scholarNo,
                                );
                                final remaining =
                                    AuthService.getSavedAccounts();
                                if (isActive) {
                                  if (remaining.isNotEmpty) {
                                    if (context.mounted) Navigator.pop(context);
                                    await widget.onSwitchAccount(remaining.first);
                                  } else {
                                    if (context.mounted) Navigator.pop(context);
                                    await widget.onSignOutCurrent();
                                  }
                                } else {
                                  setState(() {});
                                }
                              }
                            },
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.houseColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text(
                'Add Sibling / Another Account',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                if (widget.onAddSiblingPressed != null) {
                  widget.onAddSiblingPressed!();
                } else {
                  AddSiblingModal.show(
                    context,
                    houseColor: widget.houseColor,
                    onAccountAdded: widget.onSwitchAccount,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  label: const Text(
                    'Sign Out Current',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await widget.onSignOutCurrent();
                  },
                ),
                TextButton.icon(
                  icon: const Icon(
                    Icons.power_settings_new_rounded,
                    color: Colors.grey,
                    size: 18,
                  ),
                  label: const Text(
                    'Sign Out All',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Sign Out All Accounts?'),
                        content: const Text(
                          'This will disconnect all sibling and student accounts from this device.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: const Text('Sign Out All'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await AuthService.clearAllSavedAccounts();
                      if (context.mounted) Navigator.pop(context);
                      await widget.onSignOutAll();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet for authenticating and adding a new sibling account.
class AddSiblingModal extends StatefulWidget {
  final Color houseColor;
  final Future<void> Function(SavedAccount) onAccountAdded;

  const AddSiblingModal({
    super.key,
    required this.houseColor,
    required this.onAccountAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required Color houseColor,
    required Future<void> Function(SavedAccount) onAccountAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => AddSiblingModal(
        houseColor: houseColor,
        onAccountAdded: onAccountAdded,
      ),
    );
  }

  @override
  State<AddSiblingModal> createState() => _AddSiblingModalState();
}

class _AddSiblingModalState extends State<AddSiblingModal> {
  final _formKey = GlobalKey<FormState>();
  final _scholarController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String _detectedHouse = '';

  @override
  void dispose() {
    _scholarController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitSiblingForm() async {
    if (_isLoading) return;
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final scholarText = _scholarController.text.trim();
    final passwordText = _passwordController.text;

    try {
      final newAccount = await _authService.addSiblingAccount(
        scholarNo: scholarText,
        password: passwordText,
      );

      if (!mounted) return;
      Navigator.pop(context);

      await widget.onAccountAdded(newAccount);
    } catch (e) {
      if (!mounted) return;
      final rawMsg = e.toString().replaceAll('Exception: ', '');
      String friendlyMessage;
      if (rawMsg.toLowerCase().contains('user-not-found') ||
          rawMsg.toLowerCase().contains('account not found') ||
          rawMsg.toLowerCase().contains('no student account found')) {
        friendlyMessage = 'Account not found for scholar #$scholarText.';
      } else if (rawMsg.toLowerCase().contains('wrong-password') ||
          rawMsg.toLowerCase().contains('password wrong') ||
          rawMsg.toLowerCase().contains('incorrect password')) {
        friendlyMessage = 'Password wrong for scholar #$scholarText.';
      } else if (rawMsg.toLowerCase().contains('timeout') ||
          rawMsg.toLowerCase().contains('network')) {
        friendlyMessage = 'Network connection timed out. Please check your internet connection.';
      } else {
        friendlyMessage = rawMsg
            .replaceAll('[firebase_auth/', '')
            .replaceAll(']', '')
            .trim();
      }
      setState(() {
        _isLoading = false;
        _errorMessage = friendlyMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previewColor = _detectedHouse.isNotEmpty
        ? HouseColors.getHouseColor(_detectedHouse)
        : widget.houseColor;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter): _submitSiblingForm,
            const SingleActivator(LogicalKeyboardKey.numpadEnter): _submitSiblingForm,
          },
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            previewColor,
                            HouseColors.getHouseDarkColor(
                              _detectedHouse.isNotEmpty
                                  ? _detectedHouse
                                  : 'emerald',
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.group_add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Sibling Account',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Link another student profile on this device',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _scholarController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Sibling Scholar Number',
                    hintText: 'e.g. 123456',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: previewColor,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: previewColor, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    final trimmed = val.trim();
                    final inferred = AuthService.inferHouseFromScholarNo(trimmed);
                    setState(() {
                      _detectedHouse = inferred ?? '';
                    });
                  },
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter sibling scholar number.';
                    }
                    return null;
                  },
                ),
                if (_detectedHouse.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: previewColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: previewColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          HouseColors.getHouseEmoji(_detectedHouse),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_detectedHouse.toUpperCase()} House Detected • ${HouseColors.getHouseMascotName(_detectedHouse)}',
                            style: TextStyle(
                              color: previewColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submitSiblingForm(),
                  decoration: InputDecoration(
                    labelText: 'Sibling Password',
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: previewColor,
                    ),
                    suffixIcon: Semantics(
                      button: true,
                      label: _obscurePassword ? 'Show password' : 'Hide password',
                      child: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey,
                        ),
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: previewColor, width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter password.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: previewColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _submitSiblingForm,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Authenticate & Link Sibling',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
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
