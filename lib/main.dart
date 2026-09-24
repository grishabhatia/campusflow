import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/update_password_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/student/create_event_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/department/department_home_screen.dart';
import 'screens/registrar/registrar_home_screen.dart';
import 'services/reminder_service.dart';

final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ovkefbochqbqrtwjfraz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92a2VmYm9jaHFicXJ0d2pmcmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0Mjc5MzksImV4cCI6MjA5ODAwMzkzOX0.dj4c50cfHP1GwNFtgRqKgJ7y7AkrLfYiwlLKbYNy_GA',
  );

  // ✅ Startup pe reminder check
  _checkRemindersOnStart();

  // ✅ TESTING MODE: Har 1 minute reminder check
  // Production ke liye: Duration(hours: 6)
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    try {
      debugPrint('⏰ Periodic reminder check running...');
      final reminderService = ReminderService();
      await reminderService.checkAndSendReminders();
    } catch (e) {
      debugPrint('❌ Periodic reminder error: $e');
    }
  });

  runApp(const MyApp());
}

// ✅ Background Reminder Check
Future<void> _checkRemindersOnStart() async {
  try {
    await Future.delayed(const Duration(seconds: 5));

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📧 Running startup reminder check...');

    final reminderService = ReminderService();
    await reminderService.checkAndSendReminders();
  } catch (e) {
    debugPrint('❌ Startup reminder error: $e');
  }
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
      onGenerateRoute: (settings) {
        final routeName = settings.name ?? '';

        if (routeName.contains('update-password') ||
            routeName.contains('access_token') ||
            routeName.contains('error=') ||
            routeName.contains('type=recovery')) {
          return MaterialPageRoute(
            builder: (_) => const UpdatePasswordScreen(),
          );
        }

        switch (routeName) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/student':
            return MaterialPageRoute(
              builder: (_) => const StudentGuard(child: StudentHomeScreen()),
            );
          case '/admin':
            return MaterialPageRoute(
              builder: (_) => const AdminGuard(child: AdminHomeScreen()),
            );
          case '/create-event':
            return MaterialPageRoute(
              builder: (_) => const AuthGuard(child: CreateEventScreen()),
            );
          case '/update-password':
            return MaterialPageRoute(
              builder: (_) => const UpdatePasswordScreen(),
            );
          case '/department-cse':
            return MaterialPageRoute(
              builder: (_) => const DepartmentGuard(
                department: 'CSE',
                child: DepartmentHomeScreen(department: 'CSE'),
              ),
            );
          case '/department-civil':
            return MaterialPageRoute(
              builder: (_) => const DepartmentGuard(
                department: 'Civil',
                child: DepartmentHomeScreen(department: 'Civil'),
              ),
            );
          case '/registrar':
            return MaterialPageRoute(
              builder: (_) => const RegistrarGuard(child: RegistrarHomeScreen()),
            );
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}

// ── Auth Guard ───────────────────────────────────────────────────────────
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAuthenticated) return const SizedBox.shrink();
    return widget.child;
  }
}

// ── Student Guard ────────────────────────────────────────────────────────
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

      setState(() {
        _isStudent = role == 'student' || role == 'admin';
        _isLoading = false;
      });

      if (!_isStudent && mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isStudent) return const SizedBox.shrink();
    return widget.child;
  }
}

// ── Admin Guard ──────────────────────────────────────────────────────────
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
      setState(() => _isLoading = false);
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) return const SizedBox.shrink();
    return widget.child;
  }
}

// ── Department Guard ─────────────────────────────────────────────────────
class DepartmentGuard extends StatefulWidget {
  final String department;
  final Widget child;

  const DepartmentGuard({
    super.key,
    required this.department,
    required this.child,
  });

  @override
  State<DepartmentGuard> createState() => _DepartmentGuardState();
}

class _DepartmentGuardState extends State<DepartmentGuard> {
  bool _isLoading = true;
  bool _isAuthorized = false;

  static const _deptEmails = {
    'CSE': '07vaishnavi.official@gmail.com',
    'Civil': 'grishabhatia2@gmail.com',
  };

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final userEmail = session.user.email ?? '';
    final allowedEmail = _deptEmails[widget.department] ?? '';

    if (userEmail == allowedEmail) {
      setState(() {
        _isAuthorized = true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Access denied'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAuthorized) return const SizedBox.shrink();
    return widget.child;
  }
}

// ── Registrar Guard ──────────────────────────────────────────────────────
class RegistrarGuard extends StatefulWidget {
  final Widget child;
  const RegistrarGuard({super.key, required this.child});

  @override
  State<RegistrarGuard> createState() => _RegistrarGuardState();
}

class _RegistrarGuardState extends State<RegistrarGuard> {
  bool _isLoading = true;
  bool _isRegistrar = false;

  static const _registrarEmail = 'v02816754@gmail.com';

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final userEmail = session.user.email ?? '';

    if (userEmail == _registrarEmail) {
      setState(() {
        _isRegistrar = true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Registrar access only'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isRegistrar) return const SizedBox.shrink();
    return widget.child;
  }
}