import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: DespensaVivaApp()));
}

class DespensaVivaApp extends StatelessWidget {
  const DespensaVivaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DespensaViva',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return switch (authState.status) {
      AuthStatus.unknown => const SplashScreen(),
      AuthStatus.authenticated => const HomeScreen(),
      AuthStatus.unauthenticated || AuthStatus.error => const AuthScreen(),
    };
  }
}