import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:flow/services/app_updates.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

const apkBytes = [1, 3, 5, 7];
final source = Uri.parse("https://idc-learn.top/ledger-updates/latest.json");

Map<String, Object> release({int code = 368}) => {
  "version": "0.26.3",
  "versionCode": code,
  "apk": "ledger-368.apk",
  "sha256": sha256.convert(apkBytes).toString(),
  "sizeBytes": apkBytes.length,
  "notes": "测试更新",
};

void main() {
  test("directory becomes an HTTPS manifest URL", () {
    expect(parseUpdateSource("https://idc-learn.top/ledger-updates"), source);
    expect(parseUpdateSource(source.toString()), source);
    expect(
      () => parseUpdateSource("http://idc-learn.top"),
      throwsFormatException,
    );
  });

  test("offer only a newer version and resolve relative APK paths", () async {
    var code = 367;
    final api = AppUpdateClient(
      MockClient((request) async {
        expect(request.followRedirects, isFalse);
        return http.Response.bytes(
          utf8.encode(jsonEncode(release(code: code))),
          200,
        );
      }),
    );
    expect(await api.check(source, 367), isNull);
    code = 368;
    final update = await api.check(source, 367);
    expect(update?.apk, source.resolve("ledger-368.apk"));
    expect(update?.versionCode, 368);
  });

  test("refuse insecure redirects and oversized APK declarations", () async {
    final api = AppUpdateClient(
      MockClient(
        (_) async => http.Response(
          "",
          302,
          headers: {"location": "http://idc-learn.top/latest.json"},
        ),
      ),
    );
    await expectLater(api.check(source, 367), throwsFormatException);
    final oversized = release()
      ..["sizeBytes"] = AppUpdateManifest.maxApkBytes + 1;
    expect(
      () => AppUpdateManifest.parse(jsonEncode(oversized), source),
      throwsFormatException,
    );
  });

  test("reject corrupted downloads and reuse a verified file", () async {
    final folder = await Directory.systemTemp.createTemp("ledger_update_");
    addTearDown(() => folder.delete(recursive: true));
    final apk = File("${folder.path}/update.apk");
    final update = AppUpdateManifest.parse(jsonEncode(release()), source);
    var requests = 0;
    final api = AppUpdateClient(
      MockClient((_) async {
        requests++;
        return http.Response.bytes(
          requests == 1 ? [9, 9, 9, 9] : apkBytes,
          200,
        );
      }),
    );
    await expectLater(api.download(update, apk, (_) {}), throwsFormatException);
    expect(apk.existsSync(), isFalse);
    expect(File("${apk.path}.part").existsSync(), isFalse);
    final progress = <double>[];
    await api.download(update, apk, progress.add);
    expect(apk.readAsBytesSync(), apkBytes);
    expect(progress.last, 1);
    await api.download(update, apk, progress.add);
    expect(requests, 2);
  });

  test(
    "resume an interrupted download using the verified byte range",
    () async {
      final folder = await Directory.systemTemp.createTemp("ledger_resume_");
      addTearDown(() => folder.delete(recursive: true));
      final apk = File("${folder.path}/update.apk");
      final update = AppUpdateManifest.parse(jsonEncode(release()), source);
      final ranges = <String?>[];
      final api = AppUpdateClient(
        MockClient((request) async {
          ranges.add(request.headers["range"]);
          return switch (ranges.length) {
            1 => http.Response.bytes(apkBytes.take(2).toList(), 200),
            _ => http.Response.bytes(
              apkBytes.skip(2).toList(),
              206,
              headers: {"content-range": "bytes 2-3/4"},
            ),
          };
        }),
      );

      await expectLater(
        api.download(update, apk, (_) {}),
        throwsA(isA<HttpException>()),
      );
      expect(apk.existsSync(), isFalse);
      final progress = <double>[];
      await api.download(update, apk, progress.add);

      expect(ranges, [null, "bytes=2-"]);
      expect(progress.first, 0.5);
      expect(apk.readAsBytesSync(), apkBytes);
      expect(File("${apk.path}.part.identity").existsSync(), isFalse);
    },
  );

  test("pause leaves the completed bytes for a later download", () async {
    final folder = await Directory.systemTemp.createTemp("ledger_pause_");
    addTearDown(() => folder.delete(recursive: true));
    final apk = File("${folder.path}/update.apk");
    final update = AppUpdateManifest.parse(jsonEncode(release()), source);
    final cancellation = UpdateDownloadCancellation();
    final api = AppUpdateClient(
      MockClient.streaming((_, _) async {
        final chunks = [apkBytes.take(2).toList(), apkBytes.skip(2).toList()];
        return http.StreamedResponse(Stream.fromIterable(chunks), 200);
      }),
    );

    await expectLater(
      api.download(update, apk, (progress) {
        if (progress >= 0.5) cancellation.cancel();
      }, cancellation: cancellation),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect(apk.existsSync(), isFalse);
    expect(
      File("${apk.path}.part").readAsBytesSync(),
      apkBytes.take(2).toList(),
    );
  });

  test("restart when a server sends an inconsistent content range", () async {
    final folder = await Directory.systemTemp.createTemp("ledger_range_");
    addTearDown(() => folder.delete(recursive: true));
    final apk = File("${folder.path}/update.apk");
    final update = AppUpdateManifest.parse(jsonEncode(release()), source);
    final ranges = <String?>[];
    final api = AppUpdateClient(
      MockClient((request) async {
        ranges.add(request.headers["range"]);
        return switch (ranges.length) {
          1 => http.Response.bytes(apkBytes.take(2).toList(), 200),
          2 => http.Response.bytes(
            [9, 9],
            206,
            headers: {"content-range": "bytes 1-2/4"},
          ),
          _ => http.Response.bytes(apkBytes, 200),
        };
      }),
    );

    await expectLater(
      api.download(update, apk, (_) {}),
      throwsA(isA<HttpException>()),
    );
    await api.download(update, apk, (_) {});

    expect(ranges, [null, "bytes=2-", null]);
    expect(apk.readAsBytesSync(), apkBytes);
  });
}
