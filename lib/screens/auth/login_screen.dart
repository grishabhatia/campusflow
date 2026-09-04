import 'package:flutter/material.dart';
import '../../services/supabase_auth_service.dart';
import '../student/student_home_screen.dart';
import '../admin/admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = SupabaseAuthService();
  bool _isLoading = false;

  // ✅ Rate Limiting Variables
  int _loginAttempts = 0;
  DateTime? _blockTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'CampusFlow Smart',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Login'),
                  ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
              label: const Text(
                'Sign in with Google',
                style: TextStyle(fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Colors.grey, width: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: _showRegisterDialog,
                  child: const Text('Register'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _login() async {
    // ✅ Rate Limiting Check
    if (_blockTime != null && DateTime.now().difference(_blockTime!).inMinutes < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too many attempts. Try again after 5 minutes.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (!mounted) return;

      _loginAttempts = 0; // ✅ Reset on success

      final userId = _auth.currentUserId;
      if (userId == null) throw Exception('User ID is null');

      await _auth.createUserIfNotExists(
        userId: userId,
        email: _emailController.text.trim(),
        name: 'User',
      );
      final role = await _auth.getUserRole(userId);

      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/student');
      }
    } catch (e) {
      _loginAttempts++;
      if (_loginAttempts >= 5) {
        _blockTime = DateTime.now();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Too many failed attempts. Blocked for 5 minutes.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Error: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign In Error: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email to receive a password reset link.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _auth.resetPassword(emailController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset email sent! Check your inbox.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showRegisterDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Register'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _auth.register(
                  emailController.text.trim(),
                  passwordController.text.trim(),
                  nameController.text.trim(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Registration successful! Please login.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Register Error: $e')),
                );
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }
}