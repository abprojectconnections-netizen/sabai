import 'package:flutter/material.dart';

import '../data/auth_api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.onAuthenticated,
    required this.onContinueAsGuest,
    super.key,
  });

  final ValueChanged<AuthSession> onAuthenticated;
  final VoidCallback onContinueAsGuest;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authApi = AuthApi();
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isRegistering && !_acceptedTerms) {
      setState(() => _errorMessage = 'กรุณายอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final String email = _emailController.text.trim();
      final AuthSession session = _isRegistering
          ? await _authApi.register(
              displayName: _nameController.text.trim(),
              email: email,
              password: _passwordController.text,
            )
          : await _authApi.login(email: email, password: _passwordController.text);
      if (mounted) widget.onAuthenticated(session);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _setMode(bool registering) {
    setState(() {
      _isRegistering = registering;
      _errorMessage = null;
      _acceptedTerms = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F7F3), Color(0xFFF9F7F0), Color(0xFFE9F0EC)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: isWide ? _buildWideLayout() : _buildCompactLayout(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLayout() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _buildFormPanel(),
        ),
      );

  Widget _buildWideLayout() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildWelcomePanel()),
          const SizedBox(width: 22),
          SizedBox(width: 450, child: _buildFormPanel()),
        ],
      );

  Widget _buildWelcomePanel() => Container(
        constraints: const BoxConstraints(minHeight: 640),
        padding: const EdgeInsets.all(38),
        decoration: BoxDecoration(
          color: const Color(0xFF10403D),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _brandMark(light: true),
            const SizedBox(height: 92),
            const Icon(Icons.explore_rounded, color: Color(0xFFE3A23C), size: 42),
            const SizedBox(height: 18),
            const Text(
              'ทุกการเดินทาง\nเริ่มจากความสบายใจ',
              style: TextStyle(
                  color: Colors.white, fontSize: 34, height: 1.25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            const Text(
              'รวมแผนทริป ที่พัก และประสบการณ์ท้องถิ่นไว้ในที่เดียว',
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 30),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _WelcomePill(icon: Icons.auto_awesome, label: 'วางแผนด้วย AI'),
                _WelcomePill(icon: Icons.bookmark_outline, label: 'เก็บทริปไว้ได้'),
                _WelcomePill(icon: Icons.support_agent, label: 'ช่วยเหลือระหว่างทาง'),
              ],
            ),
            const SizedBox(height: 48),
            const Text('Sabai Travel · เที่ยวได้สบายใจกว่า',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      );

  Widget _buildFormPanel() => Container(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4E8E2)),
          boxShadow: const [
            BoxShadow(color: Color(0x140F302D), blurRadius: 28, offset: Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _brandMark(),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey(_isRegistering),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRegistering ? 'สร้างบัญชีของคุณ' : 'ยินดีต้อนรับกลับ',
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF16241F)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegistering
                        ? 'สมัครสมาชิกเพื่อบันทึกและจัดการทุกทริป'
                        : 'เข้าสู่ระบบเพื่อเดินทางต่อจากแผนของคุณ',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64716C)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('เข้าสู่ระบบ')),
                ButtonSegment(value: true, label: Text('สมัครสมาชิก')),
              ],
              selected: {_isRegistering},
              onSelectionChanged: (selection) => _setMode(selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isRegistering) ...[
                    _inputField(
                      controller: _nameController,
                      label: 'ชื่อที่ใช้แสดง',
                      hint: 'ชื่อของคุณ',
                      icon: Icons.person_outline_rounded,
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'กรุณากรอกชื่อ' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _inputField(
                    controller: _emailController,
                    label: 'อีเมล',
                    hint: 'name@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final String email = value?.trim() ?? '';
                      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                          ? null
                          : 'กรุณากรอกอีเมลให้ถูกต้อง';
                    },
                  ),
                  const SizedBox(height: 14),
                  _inputField(
                    controller: _passwordController,
                    label: 'รหัสผ่าน',
                    hint: _isRegistering ? 'อย่างน้อย 8 ตัวอักษร' : 'กรอกรหัสผ่านของคุณ',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    validator: (value) {
                      final String password = value ?? '';
                      if (password.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                      if (_isRegistering && password.length < 8) {
                        return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                      }
                      return null;
                    },
                    suffix: IconButton(
                      tooltip: _obscurePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                  if (_isRegistering) ...[
                    const SizedBox(height: 14),
                    _inputField(
                      controller: _confirmPasswordController,
                      label: 'ยืนยันรหัสผ่าน',
                      hint: 'กรอกรหัสผ่านอีกครั้ง',
                      icon: Icons.lock_reset_outlined,
                      obscureText: true,
                      validator: (value) =>
                          value == _passwordController.text ? null : 'รหัสผ่านไม่ตรงกัน',
                    ),
                    const SizedBox(height: 8),
                    const Text('ใช้รหัสผ่านที่คาดเดายากและไม่ซ้ำกับบริการอื่น',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64716C))),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _acceptedTerms,
                      onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: const Text('ฉันยอมรับข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัว',
                          style: TextStyle(fontSize: 11.5, height: 1.4)),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _errorMessage =
                            'ระบบกู้คืนรหัสผ่านยังไม่เปิดใช้งาน กรุณาติดต่อทีมสนับสนุน'),
                        child: const Text('ลืมรหัสผ่าน?'),
                      ),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    _ErrorBanner(message: _errorMessage!),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10403D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isRegistering ? 'สร้างบัญชี' : 'เข้าสู่ระบบ',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('หรือ', style: TextStyle(fontSize: 11, color: Color(0xFF75817B)))),
              Expanded(child: Divider())
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : widget.onContinueAsGuest,
              icon: const Icon(Icons.explore_outlined),
              label: const Text('ทดลองใช้แบบผู้เยี่ยมชม'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10403D),
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFFD8E1DC)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('การเข้าสู่ระบบปลอดภัยด้วยการเชื่อมต่อ HTTPS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Color(0xFF75817B))),
          ],
        ),
      );

  Widget _brandMark({bool light = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: light ? Colors.white.withOpacity(.12) : const Color(0xFFE6F0EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.explore_rounded,
                color: light ? const Color(0xFFE3A23C) : const Color(0xFF10403D)),
          ),
          const SizedBox(width: 10),
          Text('Sabai Travel',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: light ? Colors.white : const Color(0xFF10403D))),
        ],
      );

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffix,
  }) =>
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        autocorrect: false,
        enableSuggestions: !obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFFFAFBF9),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDCE3DE))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDCE3DE))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF10403D), width: 1.5)),
        ),
      );
}

class _WelcomePill extends StatelessWidget {
  const _WelcomePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withOpacity(.16)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: const Color(0xFFE7B763)),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1EC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF0D0C5)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFF9A422C)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFF7C3524)))),
        ]),
      );
}
