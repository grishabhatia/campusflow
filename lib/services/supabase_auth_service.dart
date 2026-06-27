import 'package:supabase/supabase.dart';
import '../supabase_config.dart';

class SupabaseAuthService {
  final supabase = SupabaseConfig.client;

  // 🔥 SignUp me data field add karo
  Future<void> register(String email, String password, String name) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': 'student'},
    );
  }

  // Baaki sab same rahega...
}