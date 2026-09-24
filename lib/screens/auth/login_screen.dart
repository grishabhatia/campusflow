import 'package:flutter/material.dart';
import '../../services/supabase_auth_service.dart';

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

  int _loginAttempts = 0;
  DateTime? _blockTime;

  // ✅ Department + Registrar email mapping
  static const _deptEmails = {
    '07vaishnavi.official@gmail.com': 'CSE',
    'grishabhatia2@gmail.com': 'Civil',
    'v02816754@gmail.com': 'Registrar',
  };

  // ✅ Helper: Email se sirf letters extract karo
  String _getDisplayName(String email) {
    final namePart = email.split('@')[0];
    final lettersOnly = namePart.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (lettersOnly.isEmpty) return 'User';
    return lettersOnly[0].toUpperCase() + lettersOnly.substring(1);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ✅ Role + Department + Registrar based navigation
  void _navigateBasedOnUser(String email, String role) {
    debugPrint('👤 Email: $email, Role: $role');

    // ✅ Department/Registrar check karo pehle
    if (_deptEmails.containsKey(email)) {
      final dept = _deptEmails[email]!;
      if (dept == 'CSE') {
        Navigator.pushReplacementNamed(context, '/department-cse');
      } else if (dept == 'Civil') {
        Navigator.pushReplacementNamed(context, '/department-civil');
      } else if (dept == 'Registrar') {
        Navigator.pushReplacementNamed(context, '/registrar');
      }
      return;
    }

    // ✅ Admin/Student
    Navigator.pushReplacementNamed(
      context,
      role == 'admin' ? '/admin' : '/student',
    );
  }

  // ── Email Login ────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (_blockTime != null && DateTime.now().difference(_blockTime!).inMinutes < 5) {
      _err('Too many attempts. Try again after 5 minutes.');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _err('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.login(email, password);
      if (!mounted) return;

      final userId = _auth.currentUserId;
      if (userId == null) throw Exception('User ID is null');

      await _auth.createUserIfNotExists(
        userId: userId,
        email: email,
        name: _getDisplayName(email),
      );
      if (!mounted) return;

      final role = await _auth.getUserRole(userId);
      if (!mounted) return;

      _loginAttempts = 0;
      _navigateBasedOnUser(email, role);
    } catch (e) {
      _loginAttempts++;
      if (_loginAttempts >= 5) {
        _blockTime = DateTime.now();
        _err('Too many failed attempts. Blocked for 5 minutes.');
      } else {
        _err('Login failed: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Google Sign In ─────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithGoogle();
      if (!mounted) return;

      final userId = _auth.currentUserId;
      if (userId != null) {
        final email = _auth.currentUser?.email ?? '';
        await _auth.createUserIfNotExists(
          userId: userId,
          email: email,
          name: _auth.currentUser?.userMetadata?['name'] ?? _getDisplayName(email),
        );
        if (!mounted) return;

        final role = await _auth.getUserRole(userId);
        if (!mounted) return;

        _navigateBasedOnUser(email, role);
      }
    } catch (e) {
      if (mounted) _err('Google Sign In Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Forgot Password ────────────────────────────────────────────────────────
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
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Password reset email sent! Check your inbox.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
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

  // ── Register Dialog ────────────────────────────────────────────────────────
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
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
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
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Registration successful! Please login.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Register Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.event, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                'CampusFlow Smart',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _emailController.text.isNotEmpty
                    ? 'Hello, ${_getDisplayName(_emailController.text)}! 👋'
                    : 'Sign in to continue',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
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
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}