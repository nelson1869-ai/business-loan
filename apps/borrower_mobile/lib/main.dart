import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/app/app.dart';
import 'package:borrower_mobile/core/config/env_config.dart';

void main() {
  EnvConfig.validateForStartup();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: BorrowerApp(),
    ),
  );
}
