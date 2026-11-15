import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// Replaces tabs that need an account until the user signs in.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('กรุณาเข้าสู่ระบบเพื่อดูข้อมูลนี้'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            ),
            child: const Text('เข้าสู่ระบบ / สมัครสมาชิก'),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    final ok = _register
        ? await state.register(_email.text.trim(), _password.text, _name.text.trim())
        : await state.login(_email.text.trim(), _password.text);
    if (ok && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_register) ...[
              TextFormField(
                key: const Key('nameField'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'ชื่อที่แสดง'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              key: const Key('emailField'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'อีเมล'),
              validator: (v) => (v ?? '').contains('@') ? null : 'อีเมลไม่ถูกต้อง',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('passwordField'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
              validator: (v) => (v ?? '').length >= 8 ? null : 'รหัสผ่านอย่างน้อย 8 ตัวอักษร',
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('submitButton'),
              onPressed: state.busy ? null : _submit,
              child: Text(_register ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ'),
            ),
            TextButton(
              onPressed: () {
                state.clearError();
                setState(() => _register = !_register);
              },
              child: Text(_register ? 'มีบัญชีแล้ว? เข้าสู่ระบบ' : 'ยังไม่มีบัญชี? สมัครสมาชิก'),
            ),
          ],
        ),
      ),
    );
  }
}
