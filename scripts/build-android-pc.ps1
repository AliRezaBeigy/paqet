# Build paqet for Android on your PC (Windows).
# Requires: Go 1.25+ (CGO), Android NDK, and git.
# Optional: ANDROID_NDK_HOME. If you pass a path (e.g. E:\SDK), NDK is auto-detected under <path>\ndk\<version>.

param(
    [string]$NdkPath = $env:ANDROID_NDK_HOME
)
if (-not $NdkPath) { $NdkPath = $env:ANDROID_NDK_ROOT }

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$RepoRoot\go.mod")) {
    Write-Error "Run from repo root or scripts folder. Repo root: $RepoRoot"
}

# If user passed SDK root (e.g. E:\SDK), find NDK under ndk\
if ($NdkPath -and (Test-Path "$NdkPath\ndk")) {
    $ndkDir = Get-ChildItem -Path "$NdkPath\ndk" -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($ndkDir) {
        $NdkPath = $ndkDir.FullName
        Write-Host "Using NDK: $NdkPath" -ForegroundColor Cyan
    }
}

$ndk = $NdkPath
if (-not $ndk) {
    Write-Host "ANDROID_NDK_HOME (or ANDROID_NDK_ROOT) is not set." -ForegroundColor Yellow
    Write-Host "Example: .\scripts\build-android-pc.ps1 -NdkPath E:\SDK"
    Write-Host "Or: `$env:ANDROID_NDK_HOME = `"E:\SDK\ndk\29.0.14206865`""
    exit 1
}

$ndkBin = "$ndk\toolchains\llvm\prebuilt\windows-x86_64\bin"
if (-not (Test-Path $ndkBin)) {
    Write-Host "NDK bin not found at: $ndkBin" -ForegroundColor Yellow
    exit 1
}

$buildDir = "$RepoRoot\build\android"
$libpcapDir = "$buildDir\libpcap-android"
$abi = "arm64-v8a"
$libpcapInclude = "$libpcapDir\include"
# libpcap-android has API subfolders (24, 25, ... 35); use 24 for broad compatibility
$libpcapLib = "$libpcapDir\$abi\24"

# Get prebuilt libpcap for Android (no make/flex/bison needed)
if (-not (Test-Path "$libpcapLib\libpcap.a")) {
    Write-Host "Fetching prebuilt libpcap for Android..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
    if (-not (Test-Path $libpcapDir)) {
        git clone --depth 1 https://github.com/seladb/libpcap-android.git $libpcapDir
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    if (-not (Test-Path "$libpcapLib\libpcap.a")) {
        Write-Host "Prebuilt libpcap not found at $libpcapLib\libpcap.a" -ForegroundColor Yellow
        exit 1
    }
}

# Use API 24+ so getifaddrs/freeifaddrs exist (prebuilt libpcap expects them)
$androidApi = "24"
$clang = "$ndkBin\aarch64-linux-android$androidApi-clang"
if (-not (Test-Path $clang)) {
    if (Test-Path "$clang.cmd") { $clang = "$clang.cmd" } else { $clang = "$clang.exe" }
}
if (-not (Test-Path $clang)) {
    Write-Host "NDK clang not found: $ndkBin\aarch64-linux-android$androidApi-clang" -ForegroundColor Yellow
    exit 1
}

$ndkSysroot = "$ndk\toolchains\llvm\prebuilt\windows-x86_64\sysroot"
$ndkLib = "$ndkSysroot\usr\lib\aarch64-linux-android\$androidApi"
$env:CGO_ENABLED = "1"
$env:GOOS = "android"
$env:GOARCH = "arm64"
$env:CC = $clang
$env:CGO_CFLAGS = "-I$libpcapInclude --sysroot=$ndkSysroot"
$env:CGO_LDFLAGS = "-L$libpcapLib -L$ndkLib -lpcap -lc -llog"

$outBinary = "$buildDir\paqet_android_arm64"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
Write-Host "Building paqet for android/arm64..." -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    go build -trimpath -o $outBinary ./cmd/main.go
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Done. Binary: $outBinary" -ForegroundColor Green
} finally {
    Pop-Location
}
