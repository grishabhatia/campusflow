import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';  // ✅ Add this for debugPrint

class SupabaseAuthService {
  // ✅ Add this getter
  SupabaseClient get supabase => Supabase.instance.client;

  Future<void> login(String email, String password) async {
    await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> register(String email, String password, String name) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': 'student'},
    );

    if (response.user != null) {
      await supabase.from('users').insert({
        'id': response.user!.id,
        'email': email,
        'name': name,
        'role': 'student',
        'organization': '',
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      throw Exception('Registration failed: User not created');
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  String? get currentUserId => supabase.auth.currentUser?.id;

  Future<String> getUserRole(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return response?['role'] ?? 'student';
    } catch (e) {
      return 'student';
    }
  }

  Future<void> createUserIfNotExists(String userId, String email, String name) async {
    try {
      final existing = await supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('users').insert({
          'id': userId,
          'email': email,
          'name': name,
          'role': 'student',
          'organization': '',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error creating user: $e');  // ✅ ab kaam karega
    }
  }
}