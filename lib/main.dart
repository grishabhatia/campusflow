import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/student/create_event_screen.dart';
import 'screens/admin/admin_home_screen.dart';

final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ovkefbochqbqrtwjfraz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92a2VmYm9jaHFicXJ0d2pmcmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0Mjc5MzksImV4cCI6MjA5ODAwMzkzOX0.dj4c50cfHP1GwNFtgRqKgJ7y7AkrLfYiwlLKbYNy_GA',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusFlow Smart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/student': (_) => const StudentGuard(child: StudentHomeScreen()),
        '/admin': (_) => const AdminGuard(child: AdminHomeScreen()),
        '/create-event': (_) => const AuthGuard(child: CreateEventScreen()),
      },
    );
  }
}

// ── Auth Guard (Sirf session check) ──────────────────────────────────────
class AuthGuard extends StatefulWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _isAuthenticated = session != null;
      _isLoading = false;
    });

    if (!_isAuthenticated && mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAuthenticated) return const SizedBox.shrink();
    return widget.child;
  }
}

// ── Student Guard ──────────────────────────────────────────────────────────
class StudentGuard extends StatefulWidget {
  final Widget child;
  const StudentGuard({super.key, required this.child});

  @override
  State<StudentGuard> createState() => _StudentGuardState();
}

class _StudentGuardState extends State<StudentGuard> {
  bool _isLoading = true;
  bool _isStudent = false;

  @override
  void initState() {
    super.initState();
    _checkStudent();
  }

  Future<void> _checkStudent() async {
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      final role = response?['role'] as String? ?? 'student';
      debugPrint('👤 StudentGuard - Role: $role');
      
      setState(() {
        // ✅ Admin bhi student access kar sakta hai
        _isStudent = role == 'student' || role == 'admin';
        _isLoading = false;
      });

      if (!_isStudent && mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('❌ Student check error: $e');
      setState(() => _isLoading = false);
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isStudent) return const SizedBox.shrink();
    return widget.child;
  }
}

// ── Admin Guard ─────────────────────────────────────────────────────────────
class AdminGuard extends StatefulWidget {
  final Widget child;
  const AdminGuard({super.key, required this.child});

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      final role = response?['role'] as String? ?? 'student';
      debugPrint('👤 AdminGuard - Role: $role');
      
      setState(() {
        _isAdmin = role == 'admin';
        _isLoading = false;
      });

      if (!_isAdmin && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Admin access only'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, '/student');
      }
    } catch (e) {
      debugPrint('❌ Admin check error: $e');
      setState(() => _isLoading = false);
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) return const SizedBox.shrink();
    return widget.child;
  }
}