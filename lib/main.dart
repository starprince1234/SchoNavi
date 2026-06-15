import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/providers.dart';

const _apiKey = String.fromEnvironment('LLM_API_KEY');
const _baseUrl = String.fromEnvironment(
  'LLM_BASE_URL',
  defaultValue: 'https://api.deepseek.com',
);
const _model = String.fromEnvironment(
  'LLM_MODEL',
  defaultValue: 'deepseek-chat',
);
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(
            apiKey: _apiKey,
            apiBaseUrl: _apiBaseUrl,
            baseUrl: _baseUrl,
            model: _model,
          ),
        ),
      ],
      child: const SchoNaviApp(),
    ),
  );
}
