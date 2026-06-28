import 'package:flutter/material.dart';

import 'bootstrap/app_bootstrap.dart';
import 'core/config/app_config.dart';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppBootstrap(
      initialAppConfig: AppConfig.resolve(
        apiKey: _apiKey,
        apiBaseUrl: _apiBaseUrl,
        baseUrl: _baseUrl,
        model: _model,
      ),
    ),
  );
}
