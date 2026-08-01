import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/app/router.dart';
import 'package:borrower_mobile/app/theme/theme.dart';

class BorrowerApp extends ConsumerWidget {
  const BorrowerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Lending Nelson Borrower Portal',
      debugShowCheckedModeBanner: false,
      theme: BorrowerAppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
