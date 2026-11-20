import "dart:async";
import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;
import "package:path_provider/path_provider.dart";

/// Accepts an HTTPS update directory or a complete manifest URL.
Uri parseUpdateSource(String value) {
  final uri = _httpsUri(Uri.tryParse(value.trim()));
  if (uri.path.toLowerCase().endsWith(".json")) return uri;
  if (uri.hasQuery) throw const FormatException("请输入完整的 JSON 地址");
  final path = uri.path.endsWith("/") ? uri.path : "${uri.path}/";
  return uri.replace(path: "${path}latest.json");
}

Uri _httpsUri(Uri? uri) {
  if (uri == null ||
      uri.scheme != "https" ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException("请输入有效的 HTTPS 地址");
  }
  return uri;
}

/// Metadata published alongside one signed APK.
class AppUpdateManifest {
  static const int maxApkBytes = 256 * 1024 * 1024;

  const AppUpdateManifest._({
    required this.version,
    required this.versionCode,
    required this.apk,
    required this.sha256Hex,
    required this.sizeBytes,
    required this.notes,
  });

  final String version;
  final int versionCode;
  final Uri apk;
  final String sha256Hex;
  final int sizeBytes;
  final String notes;

  factory AppUpdateManifest.parse(String body, Uri source) {
    final json = jsonDecode(body);
    if (json
        case {
          "version": final String version,
          "versionCode": final int versionCode,
          "apk": final String apk,
          "sha256": final String sha256Hex,
          "sizeBytes": final int sizeBytes,
        }
        when version.trim().isNotEmpty &&
            version.length <= 40 &&
            versionCode > 0 &&
            versionCode <= 2100000000 &&
            apk.trim().isNotEmpty &&
            RegExp(r"^[a-fA-F0-9]{64}$").hasMatch(sha256Hex) &&
            sizeBytes > 0 &&
            sizeBytes <= maxApkBytes) {
      final notes = json["notes"];
      if (notes != null && (notes is! String || notes.length > 4000)) {
        throw const FormatException("更新说明格式无效");
      }
      return AppUpdateManifest._(
        version: version,
        versionCode: versionCode,
        apk: _httpsUri(source.resolve(apk)),
        sha256Hex: sha256Hex.toLowerCase(),
        sizeBytes: sizeBytes,
        notes: notes as String? ?? "",
      );
    }
    throw const FormatException("服务器的更新文件格式不正确");
  }
}

/// Fetches the manifest and checks file integrity before requesting installation.
class AppUpdateClient {
  AppUpdateClient(this._client);

  final http.Client _client;
  static const _timeout = Duration(seconds: 25);
  static const _maxManifestBytes = 24 * 1024;
  static const _redirectCodes = {301, 302, 303, 307, 308};

  Future<(http.StreamedResponse, Uri)> _open(
    Uri uri, {
    int offset = 0,
    UpdateDownloadCancellation? cancellation,
  }) async {
    for (var redirects = 0; redirects <= 5; redirects++) {
      final request =
          http.AbortableRequest(
              "GET",
              _httpsUri(uri),
              abortTrigger: cancellation?._trigger.future,
            )
            ..followRedirects = false
            ..headers["Accept-Encoding"] = "identity"
            ..headers["Cache-Control"] = "no-cache";
      if (offset > 0) request.headers["Range"] = "bytes=$offset-";
      final response = await _client.send(request).timeout(_timeout);
      if (response.statusCode == 200 ||
          (offset > 0 && {206, 416}.contains(response.statusCode))) {
        return (response, uri);
      }

      final location = response.headers["location"];
      await response.stream.listen(null).cancel();
      if (!_redirectCodes.contains(response.statusCode) || location == null) {
        throw HttpException("服务器返回 HTTP ${response.statusCode}");
      }
      uri = _httpsUri(uri.resolve(location));
    }
    throw const HttpException("更新地址跳转次数过多");
  }

  Future<AppUpdateManifest?> check(Uri source, int installedVersionCode) async {
    final (response, resolvedUri) = await _open(source);
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(_timeout)) {
      if (bytes.length + chunk.length > _maxManifestBytes) {
        throw const FormatException("更新文件过大");
      }
      bytes.addAll(chunk);
    }

    final update = AppUpdateManifest.parse(utf8.decode(bytes), resolvedUri);
    return update.versionCode > installedVersionCode ? update : null;
  }

  Future<void> download(
    AppUpdateManifest update,
    File destination,
    void Function(double) onProgress, {
    UpdateDownloadCancellation? cancellation,
  }) async {
    cancellation?._throwIfCancelled(update.apk);
    if (await destination.exists() && await _matches(update, destination)) {
      onProgress(1);
      return;
    }

    final partial = File("${destination.path}.part");
    final identity = File("${partial.path}.identity");
    final expectedIdentity = "${update.sha256Hex}:${update.sizeBytes}";
    await destination.parent.create(recursive: true);
    var received = await partial.exists() ? await partial.length() : 0;
    if (received > 0 &&
        (!await identity.exists() ||
            await identity.readAsString() != expectedIdentity ||
            received > update.sizeBytes)) {
      await partial.delete();
      received = 0;
    }
    if (received == update.sizeBytes) {
      if (await _matches(update, partial)) {
        await partial.rename(destination.path);
        if (await identity.exists()) await identity.delete();
        onProgress(1);
        return;
      }
      await partial.delete();
      received = 0;
    }

    var (response, _) = await _open(
      update.apk,
      offset: received,
      cancellation: cancellation,
    );
    final expectedRange =
        "bytes $received-${update.sizeBytes - 1}/${update.sizeBytes}";
    if (response.statusCode == 416 ||
        (response.statusCode == 206 &&
            response.headers["content-range"] != expectedRange)) {
      await response.stream.listen(null).cancel();
      (response, _) = await _open(update.apk, cancellation: cancellation);
    }
    if (response.statusCode == 200) received = 0;

    try {
      await identity.writeAsString(expectedIdentity);
      final output = await partial.open(
        mode: received == 0 ? FileMode.write : FileMode.append,
      );
      try {
        onProgress(received / update.sizeBytes);
        await for (final chunk in response.stream.timeout(_timeout)) {
          cancellation?._throwIfCancelled(update.apk);
          received += chunk.length;
          if (received > update.sizeBytes) {
            throw const FormatException("安装包大小与发布信息不符");
          }
          await output.writeFrom(chunk);
          onProgress(received / update.sizeBytes);
        }
      } finally {
        await output.close();
      }
      cancellation?._throwIfCancelled(update.apk);
      if (received < update.sizeBytes) {
        throw const HttpException("下载中断，可以从上次的位置继续");
      }
      if (!await _matches(update, partial)) {
        throw const FormatException("安装包校验失败，请检查服务器文件");
      }
      await partial.rename(destination.path);
      await identity.delete();
    } on FormatException {
      if (await partial.exists()) await partial.delete();
      if (await identity.exists()) await identity.delete();
      rethrow;
    }
  }

  Future<bool> _matches(AppUpdateManifest update, File file) async =>
      await file.length() == update.sizeBytes &&
      (await sha256.bind(file.openRead()).first).toString() == update.sha256Hex;
}

/// Allows an interrupted download to leave its verified release identity on disk.
class UpdateDownloadCancellation {
  final _trigger = Completer<void>();

  void cancel() {
    if (!_trigger.isCompleted) _trigger.complete();
  }

  void _throwIfCancelled(Uri apk) {
    if (_trigger.isCompleted) throw http.RequestAbortedException(apk);
  }
}

enum UpdateInstallResult { installerOpened, permissionSettingsOpened }

class AndroidAppUpdates {
  static const _channel = MethodChannel("cn.yuanxun.ledger/update");
  static bool _installing = false;

  static Future<UpdateInstallResult> downloadAndInstall(
    AppUpdateManifest update,
    void Function(double) onProgress, {
    UpdateDownloadCancellation? cancellation,
  }) async {
    if (_installing) throw StateError("正在处理另一个更新");
    _installing = true;
    final client = http.Client();
    try {
      final cache = await getTemporaryDirectory();
      final apk = File("${cache.path}/ledger-updates/update.apk");
      await AppUpdateClient(
        client,
      ).download(update, apk, onProgress, cancellation: cancellation);
      cancellation?._throwIfCancelled(update.apk);
      final result = await _channel.invokeMethod<String>("install", {
        "versionCode": update.versionCode,
      });
      return switch (result) {
        "installer" => UpdateInstallResult.installerOpened,
        "permission" => UpdateInstallResult.permissionSettingsOpened,
        _ => throw StateError("安卓安装程序返回了未知结果"),
      };
    } finally {
      client.close();
      _installing = false;
    }
  }
}

Future<AppUpdateManifest?> checkAppUpdate(Uri source, int versionCode) async {
  final client = http.Client();
  try {
    return await AppUpdateClient(client).check(source, versionCode);
  } finally {
    client.close();
  }
}
