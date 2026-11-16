import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/extensions/services/source_access_bridge.dart';
import 'package:manga_reader_app/features/extensions/widgets/source_access_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SourceAccessActions Tests', () {
    testWidgets('menu open and login invokes mock channel and callback AFTER await controlled Completer', (WidgetTester tester) async {
      final loginCompleter = Completer<bool>();
      int onChangedCallCount = 0;
      bool bridgeOpenWebViewCalled = false;

      final testBridge = _MockSourceAccessBridge(
        isSupported: true,
        onOpenWebView: (sourceId) {
          bridgeOpenWebViewCalled = true;
          return loginCompleter.future;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceAccessActions(
              sourceId: 'test-source-id',
              sourceName: 'Test Manga Source',
              bridge: testBridge,
              onChanged: () async {
                onChangedCallCount++;
              },
            ),
          ),
        ),
      );

      // Verify the widget is rendered
      final iconButtonFinder = find.byType(PopupMenuButton<SourceAccessMenuAction>);
      expect(iconButtonFinder, findsOneWidget);

      // Open the popup menu
      await tester.tap(iconButtonFinder);
      await tester.pumpAndSettle();

      // Check menu items are visible
      expect(find.text('Войти / открыть сайт'), findsOneWidget);
      expect(find.text('Настройки источника'), findsOneWidget);
      expect(find.text('Проверить сессию'), findsOneWidget);
      expect(find.text('Очистить cookies сайта'), findsOneWidget);

      // Tap 'Войти / открыть сайт'
      await tester.tap(find.text('Войти / открыть сайт'));
      await tester.pump();

      // Bridge openWebView was invoked
      expect(bridgeOpenWebViewCalled, isTrue);
      // Callback should NOT be called before Completer finishes
      expect(onChangedCallCount, 0);

      // Now complete the WebView future
      loginCompleter.complete(true);
      await tester.pumpAndSettle();

      // Callback MUST have been called AFTER await completed
      expect(onChangedCallCount, 1);
    });

    testWidgets('clear cookies cancel does not invoke channel and does not run onChanged', (WidgetTester tester) async {
      bool clearCookiesInvoked = false;
      int onChangedCallCount = 0;

      final testBridge = _MockSourceAccessBridge(
        isSupported: true,
        onClearCookies: (sourceId, confirmed) async {
          clearCookiesInvoked = true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceAccessActions(
              sourceId: 'test-source-id',
              sourceName: 'Test Manga Source',
              bridge: testBridge,
              onChanged: () async {
                onChangedCallCount++;
              },
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<SourceAccessMenuAction>));
      await tester.pumpAndSettle();

      // Select 'Очистить cookies сайта'
      await tester.tap(find.text('Очистить cookies сайта'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear with warning about not affecting other domains / library / downloads
      expect(find.text('Очистка cookies и кэша сайта'), findsOneWidget);
      expect(
        find.textContaining('Другие домены, библиотека и скачанное не трогаются.'),
        findsOneWidget,
      );

      // Tap Cancel button
      final cancelButton = find.widgetWithText(TextButton, 'Отмена');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(clearCookiesInvoked, isFalse);
      expect(onChangedCallCount, 0);
    });

    testWidgets('clear cookies confirm invokes exact sourceID and confirmed: true and runs onChanged', (WidgetTester tester) async {
      String? invokedSourceId;
      bool? invokedConfirmed;
      int onChangedCallCount = 0;

      final testBridge = _MockSourceAccessBridge(
        isSupported: true,
        onClearCookies: (sourceId, confirmed) async {
          invokedSourceId = sourceId;
          invokedConfirmed = confirmed;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceAccessActions(
              sourceId: 'exact-source-42',
              sourceName: 'Exact Source',
              bridge: testBridge,
              onChanged: () async {
                onChangedCallCount++;
              },
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<SourceAccessMenuAction>));
      await tester.pumpAndSettle();

      // Select 'Очистить cookies сайта'
      await tester.tap(find.text('Очистить cookies сайта'));
      await tester.pumpAndSettle();

      // Tap Confirm button 'Очистить'
      final confirmButton = find.widgetWithText(TextButton, 'Очистить');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(invokedSourceId, equals('exact-source-42'));
      expect(invokedConfirmed, isTrue);
      expect(onChangedCallCount, 1);
    });

    testWidgets('cookie presence does NOT display authorized/logged in status label in check session dialog', (WidgetTester tester) async {
      final testBridge = _MockSourceAccessBridge(
        isSupported: true,
        onGetInfo: (sourceId) async {
          return const SourceAccessInfo(
            sourceId: 'test-source-id',
            name: 'Cookie Source',
            homeUrl: 'https://source.example.com',
            supportsSettings: false,
            hasCookies: true,
            loginVerified: false,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceAccessActions(
              sourceId: 'test-source-id',
              sourceName: 'Cookie Source',
              bridge: testBridge,
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<SourceAccessMenuAction>));
      await tester.pumpAndSettle();

      // Tap 'Проверить сессию'
      await tester.tap(find.text('Проверить сессию'));
      await tester.pumpAndSettle();

      // Dialog title
      expect(find.text('Статус сессии источника'), findsOneWidget);

      // Status text requirements:
      // "Cookies: сохранены" or "Cookies: есть"
      // "Вход проверяется загрузкой контента"
      expect(find.textContaining('Cookies: есть'), findsOneWidget);
      expect(find.textContaining('Вход проверяется загрузкой контента'), findsOneWidget);

      // Crucial: Must NEVER show authorized / "Авторизован" based only on cookies!
      expect(find.text('Авторизован'), findsNothing);
      expect(find.text('Вы вошли в систему'), findsNothing);
      expect(find.text('Сессия активна'), findsNothing);
    });

    testWidgets('settings disabled / shows message when settings unsupported', (WidgetTester tester) async {
      final testBridge = _MockSourceAccessBridge(
        isSupported: true,
        onGetInfo: (sourceId) async {
          return const SourceAccessInfo(
            sourceId: 'test-source-id',
            name: 'No Settings Source',
            homeUrl: 'https://source.example.com',
            supportsSettings: false,
            hasCookies: false,
            loginVerified: false,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceAccessActions(
              sourceId: 'test-source-id',
              sourceName: 'No Settings Source',
              bridge: testBridge,
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<SourceAccessMenuAction>));
      await tester.pumpAndSettle();

      // Tap 'Настройки источника'
      await tester.tap(find.text('Настройки источника'));
      await tester.pumpAndSettle();

      // Should show snackbar or message stating settings are not supported
      expect(find.textContaining('Настройки не поддерживаются'), findsOneWidget);
    });

    testWidgets('settings open invokes onOpenSettings and onChanged AFTER await completion', (WidgetTester tester) async {
      final settingsCompleter = Completer<bool>();
      int onChangedCallCount = 0;
      bool bridgeOpenSettingsCalled = false;

      final testBridge = _MockSourceAccessBridge(
        isSupported: true,
        onGetInfo: (sourceId) async {
          return const SourceAccessInfo(
            sourceId: 'test-source-id',
            name: 'Settings Source',
            homeUrl: 'https://source.example.com',
            supportsSettings: true,
            hasCookies: false,
            loginVerified: false,
          );
        },
        onOpenSettings: (sourceId) {
          bridgeOpenSettingsCalled = true;
          return settingsCompleter.future;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceAccessActions(
              sourceId: 'test-source-id',
              sourceName: 'Settings Source',
              bridge: testBridge,
              onChanged: () async {
                onChangedCallCount++;
              },
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<SourceAccessMenuAction>));
      await tester.pumpAndSettle();

      // Tap 'Настройки источника'
      await tester.tap(find.text('Настройки источника'));
      await tester.pump();

      // Bridge openSettings was invoked
      expect(bridgeOpenSettingsCalled, isTrue);
      // Callback should NOT be called before Completer finishes
      expect(onChangedCallCount, 0);

      // Now complete the settings future
      settingsCompleter.complete(true);
      await tester.pumpAndSettle();

      // Callback MUST have been called AFTER await completed
      expect(onChangedCallCount, 1);
    });

    testWidgets('shows unsupported snackbar/message on non-Android platform without throwing', (WidgetTester tester) async {
      final testBridge = _MockSourceAccessBridge(
        isSupported: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceAccessActions(
              sourceId: 'test-source-id',
              sourceName: 'Desktop Source',
              bridge: testBridge,
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<SourceAccessMenuAction>));
      await tester.pumpAndSettle();

      // Tap 'Войти / открыть сайт'
      await tester.tap(find.text('Войти / открыть сайт'));
      await tester.pumpAndSettle();

      // Should show unsupported platform message
      expect(find.textContaining('поддерживается только на Android'), findsOneWidget);
    });

    testWidgets('error during openWebView displays actionable snackbar with retry', (WidgetTester tester) async {
      int attempts = 0;
      final testBridge = _MockSourceAccessBridge(
        isSupported: true,
        onOpenWebView: (sourceId) async {
          attempts++;
          if (attempts == 1) {
            throw Exception('Platform channel failed');
          }
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceAccessActions(
              sourceId: 'test-source-id',
              sourceName: 'Error Source',
              bridge: testBridge,
            ),
          ),
        ),
      );

      // Open menu and tap login
      await tester.tap(find.byType(PopupMenuButton<SourceAccessMenuAction>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Войти / открыть сайт'));
      await tester.pumpAndSettle();

      // Check snackbar with error and retry button
      expect(find.textContaining('Ошибка открытия сайта'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
    });

    testWidgets('popup menu renders on 320px screen width without RenderFlex overflow exception', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testBridge = _MockSourceAccessBridge(isSupported: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceAccessActions(
              sourceId: 'test-source-id',
              sourceName: 'Very Long Source Title For Mobile Viewport',
              bridge: testBridge,
            ),
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<SourceAccessMenuAction>));
      await tester.pumpAndSettle();

      // Ensure menu items are displayed without any layout overflow errors
      expect(find.text('Войти / открыть сайт'), findsOneWidget);
      expect(find.text('Настройки источника'), findsOneWidget);
      expect(find.text('Проверить сессию'), findsOneWidget);
      expect(find.text('Очистить cookies сайта'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _MockSourceAccessBridge extends SourceAccessBridge {
  final Future<SourceAccessInfo> Function(String sourceId)? onGetInfo;
  final Future<bool> Function(String sourceId)? onOpenWebView;
  final Future<bool> Function(String sourceId)? onOpenSettings;
  final Future<void> Function(String sourceId, bool confirmed)? onClearCookies;

  _MockSourceAccessBridge({
    super.isSupported = true,
    this.onGetInfo,
    this.onOpenWebView,
    this.onOpenSettings,
    this.onClearCookies,
  }) : super.forTesting(
          channel: const MethodChannel('mock_channel'),
        );

  @override
  Future<SourceAccessInfo> getInfo(String sourceId) {
    if (onGetInfo != null) return onGetInfo!(sourceId);
    return Future.value(SourceAccessInfo(
      sourceId: sourceId,
      name: 'Mock Source',
      homeUrl: 'https://mock.example.com',
      supportsSettings: true,
      hasCookies: false,
      loginVerified: false,
    ));
  }

  @override
  Future<bool> openWebView(String sourceId) {
    if (onOpenWebView != null) return onOpenWebView!(sourceId);
    return Future.value(true);
  }

  @override
  Future<bool> openSettings(String sourceId) {
    if (onOpenSettings != null) return onOpenSettings!(sourceId);
    return Future.value(true);
  }

  @override
  Future<void> clearCookies(String sourceId, {required bool confirmed}) {
    if (onClearCookies != null) return onClearCookies!(sourceId, confirmed);
    return Future.value();
  }
}
