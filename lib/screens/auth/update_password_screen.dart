import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordSet = false;

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    // ✅ Validation
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill both fields', Colors.red);
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('Password must be at least 6 characters', Colors.red);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('Passwords do not match', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Update password in Supabase
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      setState(() {
        _isLoading = false;
        _isPasswordSet = true;
      });

      _showMessage('✅ Password updated successfully!', Colors.green);

      // ✅ 2 seconds baad login screen pe bhejo
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('❌ Error: ${e.toString()}', Colors.red);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Set New Password'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Color(0xFF1565C0)),
            const SizedBox(height: 20),
            const Text(
              'Create New Password',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your new password below',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // ── New Password ──────────────────────────────────────────────
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
                hintText: 'Minimum 6 characters',
              ),
            ),
            const SizedBox(height: 16),

            // ── Confirm Password ──────────────────────────────────────────
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Update Button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update Password',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),

            // ── Success Message ───────────────────────────────────────────
            if (_isPasswordSet) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Password updated! Redirecting to login...',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}