package mn.flow.flow

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread

internal fun MainActivity.registerLedgerUpdater(messenger: BinaryMessenger) {
  MethodChannel(messenger, "cn.yuanxun.ledger/update").setMethodCallHandler { call, result ->
    if (call.method != "install") {
      result.notImplemented()
      return@setMethodCallHandler
    }

    val expectedVersion = call.argument<Number>("versionCode")?.toLong()
    if (expectedVersion == null || expectedVersion <= 0) {
      result.error("invalid_version", "更新版本无效", null)
      return@setMethodCallHandler
    }

    val apk = File(cacheDir, "ledger-updates/update.apk")
    thread(name = "verify-ledger-update") {
      val verificationError = try {
        verifyLedgerUpdate(apk, expectedVersion)
        null
      } catch (_: Exception) {
        "安装包的包名、版本或签名不匹配"
      }

      runOnUiThread {
        if (verificationError != null) {
          result.error("invalid_apk", verificationError, null)
        } else if (isFinishing || isDestroyed) {
          result.error("activity_closed", "请返回更新页重新安装", null)
        } else {
          try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
              !packageManager.canRequestPackageInstalls()
            ) {
              startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:$packageName")
              })
              result.success("permission")
            } else {
              val uri = FileProvider.getUriForFile(this, "$packageName.provider", apk)
              startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
              })
              result.success("installer")
            }
          } catch (_: Exception) {
            result.error("installer_unavailable", "无法打开安卓安装程序", null)
          }
        }
      }
    }
  }
}

@Suppress("DEPRECATION")
private fun MainActivity.verifyLedgerUpdate(apk: File, expectedVersion: Long) {
  val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
    PackageManager.GET_SIGNING_CERTIFICATES
  } else {
    PackageManager.GET_SIGNATURES
  }
  val installed = packageManager.getPackageInfo(packageName, flags)
  val downloaded = requireNotNull(packageManager.getPackageArchiveInfo(apk.path, flags))
  require(downloaded.packageName == packageName)
  require(downloaded.ledgerVersionCode() == expectedVersion)
  require(downloaded.ledgerVersionCode() > installed.ledgerVersionCode())
  val signers = installed.ledgerSigners()
  require(signers.isNotEmpty() && signers == downloaded.ledgerSigners())
}

@Suppress("DEPRECATION")
private fun PackageInfo.ledgerVersionCode(): Long =
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) longVersionCode else versionCode.toLong()

@Suppress("DEPRECATION")
private fun PackageInfo.ledgerSigners(): Set<Signature> =
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
    signingInfo?.apkContentsSigners?.toSet().orEmpty()
  } else {
    signatures?.toSet().orEmpty()
  }
