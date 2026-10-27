import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class DosConHiloAdminApp extends ConsumerWidget {
  const DosConHiloAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Dos con Hilo · Administración',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      routerConfig: appRouter,
      builder: (context, child) {
        if (!AppConfig.isConfigured) {
          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                MaterialBanner(
                  content: const Text(
                    'Modo de demostración: configura Supabase para habilitar datos y acceso.',
                  ),
                  leading: const Icon(Icons.info_outline),
                  actions: const [SizedBox.shrink()],
                  backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                ),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            ),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
