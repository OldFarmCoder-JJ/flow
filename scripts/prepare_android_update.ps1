[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Apk,
    [Parameter(Mandatory)]
    [string] $OutputDirectory,
    [Parameter(Mandatory)]
    [string] $Aapt,
    [string] $Notes = ''
)

$ErrorActionPreference = 'Stop'
$apkFile = Get-Item -LiteralPath $Apk
$badging = & $Aapt dump badging $apkFile.FullName
if ($LASTEXITCODE -ne 0) {
    throw 'Could not read the APK metadata.'
}
$package = $badging | Where-Object { $_ -like 'package:*' } | Select-Object -First 1
if ($package -notmatch "^package: name='cn\.yuanxun\.ledger' versionCode='(\d+)' versionName='([^']+)'") {
    throw 'The APK must be a release of cn.yuanxun.ledger.'
}
$code = [int]$Matches[1]
$version = $Matches[2]
if ($apkFile.Length -gt 256MB -or $Notes.Length -gt 4000) {
    throw 'The APK or release notes exceed the updater size limit.'
}

$out = New-Item -ItemType Directory -Force -Path $OutputDirectory
$name = "yuanxun-ledger-$code.apk"
$apkOutput = Join-Path $out.FullName $name
$manifestOutput = Join-Path $out.FullName 'latest.json'
$hash = (Get-FileHash -LiteralPath $apkFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

if (Test-Path -LiteralPath $apkOutput) {
    $publishedHash = (Get-FileHash -LiteralPath $apkOutput -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($publishedHash -ne $hash) {
        throw 'An APK with this version code already exists in the output directory.'
    }
} else {
    Copy-Item -LiteralPath $apkFile.FullName -Destination $apkOutput
}

$manifest = [ordered]@{
    version = $version
    versionCode = $code
    apk = $name
    sha256 = $hash
    sizeBytes = $apkFile.Length
    notes = $Notes
}
[IO.File]::WriteAllText(
    $manifestOutput,
    ($manifest | ConvertTo-Json),
    [Text.UTF8Encoding]::new($false)
)
Get-Item -LiteralPath $apkOutput, $manifestOutput
