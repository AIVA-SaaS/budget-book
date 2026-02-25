# Frontend - Flutter (Web + Mobile Unified)

## Stack
- Flutter 3.x, Dart 3.x
- flutter_bloc for state management
- dio for HTTP client
- go_router for navigation
- get_it + injectable for dependency injection
- flutter_secure_storage for token storage
- fl_chart for charts (pie, line, bar)
- web_socket_channel for real-time sync
- intl for localization

## Architecture: Feature-First Clean Architecture
```
features/{feature}/
  data/
    datasources/{feature}_remote_datasource.dart
    repositories/{feature}_repository_impl.dart
  domain/
    entities/{entity}.dart
    repositories/{feature}_repository.dart
  presentation/
    bloc/{feature}_bloc.dart
    bloc/{feature}_event.dart
    bloc/{feature}_state.dart
    pages/{page_name}_page.dart
    widgets/{widget_name}.dart
```

## Conventions
- All pages end with `_page.dart`, all widgets with descriptive names
- BLoC files always in trio: `_bloc.dart`, `_event.dart`, `_state.dart`
- Events and states use sealed classes
- Repository interfaces in `domain/`, implementations in `data/`
- API calls only in `datasources/`; never in BLoC or widgets
- Use `Either<Failure, T>` pattern for error handling in repositories (via dartz)
- Widget composition over inheritance
- Responsive layout: use `LayoutBuilder` and breakpoints for web vs mobile

## Core Module (`lib/core/`)
- `network/` - Dio client, interceptors (auth token injection, error handling)
- `di/` - GetIt service locator configuration
- `router/` - GoRouter route definitions
- `theme/` - Material 3 theme, colors, text styles
- `constants/` - API endpoints, app strings, colors
- `widgets/` - Shared reusable widgets
- `storage/` - Secure storage for tokens

## Localization
- Primary: Korean (`app_ko.arb`)
- Secondary: English (`app_en.arb`)
- All user-facing strings via `AppLocalizations.of(context)`

## Testing
- Widget tests for all pages and complex widgets
- BLoC tests for all blocs (test event -> state transitions)
- Run tests: `flutter test`
- Run specific: `flutter test test/features/auth/`

## Real-time Sync
- Connect to WebSocket at `{API_BASE}/ws` via STOMP
- Listen to `/topic/couple/{coupleId}` for partner's changes
- On receiving event, refresh relevant BLoC state
- Reconnect with exponential backoff on disconnect
