import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/student/create_event_screen.dart';
import 'screens/admin/admin_home_screen.dart';

// ✅ Global supabase client — isko kisi bhi file me import kar sakte ho
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/student': (context) => const StudentHomeScreen(),
        '/admin': (context) => const AdminHomeScreen(),
        '/create-event': (context) => const CreateEventScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}