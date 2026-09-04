import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  SupabaseClient get supabase => Supabase.instance.client;

  // ── Email/Password Login ───────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── Email/Password Register ────────────────────────────────────────────────
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

  // ── Google Sign In ─────────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'https://stupendous-selkie-756c5b.netlify.app',
      );
    } catch (e) {
      debugPrint('❌ Google Sign In error: $e');
      rethrow;
    }
  }

  // ── Forgot Password ────────────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
      debugPrint('✅ Password reset email sent to $email');
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      rethrow;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  // ── Current User ID ────────────────────────────────────────────────────────
  String? get currentUserId => supabase.auth.currentUser?.id;

  // ── Current User Email ─────────────────────────────────────────────────────
  String? get currentUserEmail => supabase.auth.currentUser?.email;

  // ── Get User Role ──────────────────────────────────────────────────────────
  Future<String> getUserRole(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return response?['role'] ?? 'student';
    } catch (e) {
      debugPrint('getUserRole error: $e');
      return 'student';
    }
  }

  // ── Create user in DB if not exists ───────────────────────────────────────
  Future<void> createUserIfNotExists({
    String? userId,
    String? email,
    String? name,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      final uid = userId ?? user?.id;
      if (uid == null) return;

      final existing = await supabase
          .from('users')
          .select('id')
          .eq('id', uid)
          .maybeSingle();

      if (existing == null) {
        final resolvedName = name ??
            user?.userMetadata?['full_name'] ??
            user?.userMetadata?['name'] ??
            email?.split('@')[0] ??
            'Student';

        final resolvedEmail = email ?? user?.email ?? '';

        await supabase.from('users').insert({
          'id': uid,
          'email': resolvedEmail,
          'name': resolvedName,
          'role': 'student',
          'organization': '',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ New user created in DB: $resolvedName');
      }
    } catch (e) {
      debugPrint('createUserIfNotExists error: $e');
    }
  }

  // ── Listen to auth state changes ───────────────────────────────────────────
  Stream<AuthState> get authStateChanges =>
      supabase.auth.onAuthStateChange;
}