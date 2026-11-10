import 'package:flutter/widgets.dart';
import 'package:srk_mobile_core/srk_mobile_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSrkSupabase();
  runApp(const SrkMobileApp(role: SrkAppRole.electrician));
}
