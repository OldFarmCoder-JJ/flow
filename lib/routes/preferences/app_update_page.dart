import "dart:async";
import "dart:io";

import "package:flow/prefs/local_preferences.dart";
import "package:flow/services/app_updates.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;
import "package:package_info_plus/package_info_plus.dart";

/// Checks the configured release channel and starts installation.
class AppUpdatePage extends StatefulWidget {
  const AppUpdatePage({
    super.key,
    this.initialUpdate,
    this.check = checkAppUpdate,
  });

  /// Loads the next release for the installed build.
  final Future<AppUpdateManifest?> Function(Uri, int) check;

  final AppUpdateManifest? initialUpdate;

  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  late bool _automatic = LocalPreferences().effectiveUpdateSource.isNotEmpty;
  late final String _source =
      switch (LocalPreferences().effectiveUpdateSource) {
        final value when value.isNotEmpty => value,
        _ => LocalPreferences.defaultUpdateSource,
      };

  @override
  void initState() {
    super.initState();
    if (widget.initialUpdate == null) unawaited(_check());
  }

  late final Future<PackageInfo> _installed = PackageInfo.fromPlatform();
  late AppUpdateManifest? _available = widget.initialUpdate;
  bool _busy = false;
  bool _downloaded = false;
  bool _canContinue = false;
  UpdateDownloadCancellation? _downloadCancellation;
  double? _progress;
  String? _notice;

  @override
  void dispose() {
    _downloadCancellation?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _available = null;
      _notice = null;
      _downloaded = false;
      _canContinue = false;
    });

    try {
      final source = parseUpdateSource(_source);
      final installed = await _installed;
      final update = await widget.check(
        source,
        int.parse(installed.buildNumber),
      );
      if (!mounted) return;
      setState(() {
        _available = update;
        _notice = update == null ? "已是最新版本" : "发现新版本 ${update.version}";
      });
    } catch (error) {
      if (mounted) setState(() => _notice = _describe(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install(AppUpdateManifest update) async {
    final cancellation = UpdateDownloadCancellation();
    _downloadCancellation = cancellation;
    setState(() {
      _busy = true;
      _progress = 0;
      _notice = null;
    });

    try {
      final result = await AndroidAppUpdates.downloadAndInstall(update, (
        progress,
      ) {
        if (!mounted) return;
        // Rebuild at most once per percentage point during a large download.
        if ((progress * 100).floor() == ((_progress ?? 0) * 100).floor()) {
          return;
        }
        setState(() => _progress = progress);
      }, cancellation: cancellation);
      if (!mounted) return;
      setState(() {
        _downloaded = true;
        _canContinue = false;
        _notice = result == UpdateInstallResult.permissionSettingsOpened
            ? "开启「允许安装应用」后返回，再点「安装更新」"
            : "请在安卓安装界面确认更新";
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _canContinue =
              error is http.ClientException ||
              error is HttpException ||
              error is TimeoutException;
          _notice = switch (error) {
            http.RequestAbortedException() => "已暂停，稍后可以继续下载",
            http.ClientException() || TimeoutException() => "网络连接中断，可以继续下载",
            _ => _describe(error),
          };
        });
      }
    } finally {
      _downloadCancellation = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  String _describe(Object error) => switch (error) {
    FormatException(:final message) => message,
    HttpException(:final message) => message,
    PlatformException(:final message) => message ?? "无法打开安卓安装程序",
    TimeoutException() => "连接超时，请稍后重试",
    FileSystemException() => "无法保存安装包，请检查可用空间",
    _ => "无法获取更新，请检查网络后重试",
  };

  @override
  Widget build(BuildContext context) {
    final update = _available;
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(title: const Text("应用更新")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FutureBuilder<PackageInfo>(
              future: _installed,
              builder: (context, snapshot) {
                final info = snapshot.data;
                return Text(
                  info == null
                      ? "当前版本"
                      : "当前版本 ${info.version}（${info.buildNumber}）",
                );
              },
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text("自动检查更新"),
              contentPadding: EdgeInsets.zero,
              value: _automatic,
              onChanged: _busy
                  ? null
                  : (value) async {
                      try {
                        await LocalPreferences().updateSource.set(
                          value ? _source : "",
                        );
                        if (mounted) setState(() => _automatic = value);
                      } catch (error) {
                        if (mounted) setState(() => _notice = "设置保存失败，请重试");
                      }
                    },
            ),
            if (update == null)
              OutlinedButton(
                onPressed: _busy ? null : _check,
                child: Text(_busy ? "正在检查更新" : "检查更新"),
              ),
            if (_busy && progress == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (_notice case final notice?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(liveRegion: true, child: Text(notice)),
              ),
            if (update != null) ...[
              const SizedBox(height: 12),
              Text(
                "版本 ${update.version} · ${(update.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB",
              ),
              if (update.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(update.notes),
                ),
              FilledButton(
                onPressed: _busy ? null : () => _install(update),
                child: Text(
                  _downloaded
                      ? "安装更新"
                      : _canContinue
                      ? "继续下载"
                      : "下载并安装",
                ),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                progress >= 1 ? "正在核验安装包" : "下载中 ${(progress * 100).floor()}%",
              ),
              if (progress < 1)
                TextButton(
                  onPressed: _downloadCancellation?.cancel,
                  child: const Text("暂停下载"),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
