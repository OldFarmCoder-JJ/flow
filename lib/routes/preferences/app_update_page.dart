import "dart:async";
import "dart:io";

import "package:flow/prefs/local_preferences.dart";
import "package:flow/services/app_updates.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;
import "package:package_info_plus/package_info_plus.dart";

/// Configures the update source, checks for releases and starts installation.
class AppUpdatePage extends StatefulWidget {
  const AppUpdatePage({super.key, this.initialUpdate});

  final AppUpdateManifest? initialUpdate;

  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  late final _address = TextEditingController(
    text: LocalPreferences().updateSource.value,
  );
  final _formKey = GlobalKey<FormState>();
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
    _address.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _available = null;
      _notice = null;
      _downloaded = false;
      _canContinue = false;
    });

    try {
      final saved = LocalPreferences().updateSource;
      if (_address.text.trim().isEmpty) {
        await saved.set("");
        if (mounted) setState(() => _notice = "已关闭自动检查更新");
        return;
      }
      final source = parseUpdateSource(_address.text);
      await saved.set(source.toString());
      final installed = await _installed;
      final update = await checkAppUpdate(
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
    _ => "无法获取更新，请检查网络和服务器地址",
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
            Form(
              key: _formKey,
              child: TextFormField(
                enabled: !_busy,
                controller: _address,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: "HTTPS 更新地址",
                  helperText: "可填目录地址或 latest.json 完整地址。留空可关闭检查。",
                  helperMaxLines: 3,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  try {
                    parseUpdateSource(value);
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
                onChanged: (_) {
                  if (_available != null || _notice != null) {
                    setState(() {
                      _available = null;
                      _notice = null;
                      _downloaded = false;
                      _canContinue = false;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _check,
              child: const Text("保存并检查更新"),
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
