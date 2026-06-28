# Drift Web runtime

The Web build needs two generated runtime files at the Web root:

- `web/drift_worker.dart.js`
- `web/sqlite3.wasm`

After `flutter pub get`, run:

```powershell
dart run tool/prepare_drift_web.dart
flutter build web
```

The preparation script resolves the installed `sqlite3` package through
`.dart_tool/package_config.json`, copies its matching WASM binary, and compiles
the repository's Drift worker source. Run it in CI before every Web build so
the worker and package versions cannot drift apart.
