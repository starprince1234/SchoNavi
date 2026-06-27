# Task 10 Report: 路由 + ChatPage fork 分发 + 锚点条挂载

## Implemented

- `lib/core/router/app_router.dart`
  - `/chat` builder parses `fork`, `msid`, `fid` query params and passes them to `ChatPage` as `forkMode`, `mainSessionId`, `forkId`.
  - `/professor/:id` route left unchanged. The `msid` query parameter is naturally preserved in the URI and will be consumed by `ProfessorPage` in Task 11.

- `lib/features/chat/pages/chat_page.dart`
  - Constructor adds `forkMode` (default false), `mainSessionId`, `forkId` as optional params.
  - `initState` post-frame callback made `async` and dispatches three paths:
    - `forkMode && forkId != null` → `notifier.resume(sessionId: forkId, isFork: true, mainSessionId: mainSessionId)`
    - `forkMode` → `notifier.startFork(sourceSessionId: mainSessionId ?? '', professorId: professorId ?? '')`
    - else → existing `start/bootstrap` path.
  - Sticky `ProfessorAnchorBar` rendered in the Stack when `state.forkAnchor != null` (top + left/right zero, inside `SafeArea(bottom: false)`), tapping navigates to `/professor/${forkAnchor.professorId}`.
  - `ListView` top padding switches to `108.0` when `forkAnchor` is non-null, otherwise `56.0`, to avoid content hiding behind the bar.
  - `ChatMessageBubble` wired with `onRerouteHome: () => context.go('/home')`.

## Tests

- Updated `test/core/router/chat_route_test.dart` with a new case for `/chat?fork=true&msid=s1&pid=p_001`.
- Added `test/features/chat/chat_page_fork_test.dart` verifying fork-mode `ChatPage` renders the `ProfessorAnchorBar`.

### TDD RED/GREEN Evidence

- RED: `flutter test test/features/chat/chat_page_fork_test.dart test/core/router/chat_route_test.dart` initially failed because `ChatPage` had no `forkMode`/`mainSessionId`/`forkId` parameters.
- GREEN after implementation:
  - Focused tests: both pass.
  - Regression suites (`test/features/chat/`, `test/features/home/`, `test/core/router/`): 103 tests pass.
  - `flutter analyze lib/features/chat/pages/chat_page.dart lib/core/router/app_router.dart`: No issues found.

## Self-Review

- Completeness: all four brief requirements satisfied.
- Regression: optional constructor params default to existing behavior (`forkMode = false`); existing chat/home/router tests stay green.
- Quality: async post-frame callback correctly awaits async notifier calls; sticky bar uses `SafeArea`.
- Discipline: no extra routes, no unrelated changes. `lib/shared/widgets/glass_surface.dart` was already modified before this task and was left untouched.

## Fix: /professor msid pass-through

Implemented 2026-06-27 to close code-review finding on Task 10.

### Changes

- `lib/features/professor/pages/professor_page.dart`
  - Added optional `String? mainSessionId` constructor parameter and stored it as a public field.
  - Left FAB unchanged for Task 11.

- `lib/core/router/app_router.dart`
  - `/professor/:id` route now passes `mainSessionId: state.uri.queryParameters['msid']` to `ProfessorPage`.

- `lib/features/chat/pages/chat_page.dart`
  - `ProfessorAnchorBar` onTap now pushes `/professor/${state.forkAnchor!.professorId}?msid=${Uri.encodeComponent(state.forkAnchor!.mainSessionId)}` so fork's `mainSessionId` is preserved.

- Tests
  - Added `test/core/router/professor_route_test.dart` verifying `/professor/:id?msid=someMainSid` passes `mainSessionId` to `ProfessorPage`, and that absence of `msid` yields `null`.
  - Extended `test/features/chat/chat_page_fork_test.dart` to assert the anchor bar tap navigates to a route whose URI contains `msid=`.

### Verification

```bash
$ flutter test test/core/router/ test/features/chat/ test/features/professor/
...
+95: All tests passed!

$ flutter analyze lib/core/router/app_router.dart lib/features/chat/pages/chat_page.dart lib/features/professor/pages/professor_page.dart
No issues found!
```

Commit: `8518e9f fix(chat/professor): /professor/:id 保留 msid 透传`
