import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _isLoggedIn = session != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn) {
      return const StudentHomeScreen();
    }

    return const LoginScreen();
  }
}