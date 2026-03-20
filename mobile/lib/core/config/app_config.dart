import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl =>
      const String.fromEnvironment('SUPABASE_URL').isNotEmpty
      ? const String.fromEnvironment('SUPABASE_URL')
      : dotenv.env['SUPABASE_URL']!;

  static String get supabaseAnonKey =>
      const String.fromEnvironment('SUPABASE_ANON_KEY').isNotEmpty
      ? const String.fromEnvironment('SUPABASE_ANON_KEY')
      : dotenv.env['SUPABASE_ANON_KEY']!;

  static String get backendUrl =>
      const String.fromEnvironment('BACKEND_URL').isNotEmpty
      ? const String.fromEnvironment('BACKEND_URL')
      : dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';
}
