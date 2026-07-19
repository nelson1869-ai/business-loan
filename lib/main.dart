import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Starts the application inside Riverpod's root provider container.
///
/// File: `lib/main.dart`
///
/// Data Flow Diagram:
/// ```text
///  +------------------+     +------------------+
///  |    main.dart     | --> |     app.dart     |
///  +------------------+     +------------------+
/// ```
void main() {
  runApp(const ProviderScope(child: LendingNelsonApp()));
}
