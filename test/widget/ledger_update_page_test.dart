import "dart:convert";

import "package:flow/prefs/local_preferences.dart";
import "package:flow/routes/preferences/app_update_page.dart";
import "package:flow/services/app_updates.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await LocalPreferences.initialize();
    PackageInfo.setMockInitialValues(
      appName: "Ledger",
      packageName: "cn.yuanxun.ledger",
      version: "1",
      buildNumber: "1",
      buildSignature: "",
    );
  });
  testWidgets("manual update works with a previously disabled source", (
    tester,
  ) async {
    await LocalPreferences().updateSource.set("");
    final requests = <Uri>[];
    Future<AppUpdateManifest?> nextRelease(Uri source, int buildNumber) async {
      requests.add(source);
      expect(buildNumber, 1);
      return AppUpdateManifest.parse(
        jsonEncode({
          "version": "2",
          "versionCode": 2,
          "apk": "v2.apk",
          "sizeBytes": 10,
          "sha256": "a" * 64,
        }),
        source,
      );
    }

    await tester.pumpWidget(
      MaterialApp(home: AppUpdatePage(check: nextRelease)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text("下载并安装"), findsOneWidget);
    expect(requests.single.toString(), LocalPreferences.defaultUpdateSource);
    expect(LocalPreferences().effectiveUpdateSource, "");
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      LocalPreferences().effectiveUpdateSource,
      LocalPreferences.defaultUpdateSource,
    );
  });
}
