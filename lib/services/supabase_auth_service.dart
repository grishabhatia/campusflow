import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  SupabaseClient get supabase => Supabase.instance.client;

  // ── Current User Getters ──────────────────────────────────────────────────
  User? get currentUser => supabase.auth.currentUser;
  String? get currentUserId => supabase.auth.currentUser?.id;
  String? get currentUserEmail => supabase.auth.currentUser?.email;

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
        'id':           response.user!.id,
        'email':        email,
        'name':         name,
        'role':         'student',
        'organization': '',
        'created_at':   DateTime.now().toIso8601String(),
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
        redirectTo: 'https://mriirscampusflow.netlify.app', // ✅ UPDATED
      );
    } catch (e) {
      debugPrint('❌ Google Sign In error: $e');
      rethrow;
    }
  }

  // ── Forgot Password ────────────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://mriirscampusflow.netlify.app/update-password', // ✅ ADDED
      );
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

  // ── Get User Role ──────────────────────────────────────────────────────────
  Future<String> getUserRole(String userId) async {
    try {
      debugPrint('🔍 Getting role for userId: $userId');

      final response = await supabase
          .from('users')
          .select('role, email')
          .eq('id', userId)
          .maybeSingle();

      debugPrint('📋 User record: $response');

      if (response == null) {
        debugPrint('⚠️ User not found in DB for id: $userId');
        return 'student';
      }

      final role = response['role'] as String? ?? 'student';
      debugPrint('👤 Role: $role | Email: ${response['email']}');
      return role;
    } catch (e) {
      debugPrint('❌ getUserRole error: $e');
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
      final uid  = userId ?? user?.id;
      if (uid == null) return;

      final existing = await supabase
          .from('users')
          .select('id, role')
          .eq('id', uid)
          .maybeSingle();

      debugPrint('📋 Existing user check: $existing');

      if (existing == null) {
        final resolvedName = name
            ?? user?.userMetadata?['full_name']
            ?? user?.userMetadata?['name']
            ?? email?.split('@')[0]
            ?? 'User';

        final resolvedEmail = email ?? user?.email ?? '';

        await supabase.from('users').insert({
          'id':           uid,
          'email':        resolvedEmail,
          'name':         resolvedName,
          'role':         'student',
          'organization': '',
          'created_at':   DateTime.now().toIso8601String(),
        });
        debugPrint('✅ New Google user created: $resolvedName ($resolvedEmail)');
      } else {
        debugPrint('✅ User already exists — role: ${existing['role']}');
      }
    } catch (e) {
      debugPrint('❌ createUserIfNotExists error: $e');
    }
  }

  // ── Auth State Changes ─────────────────────────────────────────────────────
  Stream<AuthState> get authStateChanges =>
      supabase.auth.onAuthStateChange;
}