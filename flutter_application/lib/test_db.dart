import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Supabase başlatmadan önce gerekli

  // Supabase başlatma
  await Supabase.initialize(
    url: "https://fczqhqaeofgbzjikdjcb.supabase.co",  
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjenFocWFlb2ZnYnpqaWtkamNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE5OTA1OTUsImV4cCI6MjA1NzU2NjU5NX0.r06RWhjtCfRPsm1R-6wIksz4pZYueJ3osQWgDagO0hw",
  );

  print("✅ Supabase başarıyla başlatıldı!");
}
