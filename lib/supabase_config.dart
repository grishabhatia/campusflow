import 'package:supabase/supabase.dart';

class SupabaseConfig {
  static const String url = 'https://ovkefbochqbqrtwjfraz.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92a2VmYm9jaHFicXJ0d2pmcmF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0Mjc5MzksImV4cCI6MjA5ODAwMzkzOX0.dj4c50cfHP1GwNFtgRqKgJ7y7AkrLfYiwlLKbYNy_GA'; 

  static SupabaseClient get client => SupabaseClient(
        url,
        anonKey,
        storage: LocalStorage(), 
      );

  static void initialize() {}
}