# Kreedum Construction - one-time project setup (Windows PowerShell)
# Run from this folder:  powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "`n[1/5] Generating Android project files (existing files are kept)..." -ForegroundColor Cyan
flutter create --org com --project-name kreedum_construction --platforms android .

Write-Host "`n[2/5] Fetching packages..." -ForegroundColor Cyan
flutter pub get

Write-Host "`n[3/5] Generating app icons..." -ForegroundColor Cyan
dart run flutter_launcher_icons

Write-Host "`n[4/5] Generating splash screen..." -ForegroundColor Cyan
dart run flutter_native_splash:create

Write-Host "`n[5/5] Adding release signing config..." -ForegroundColor Cyan
$gradle = 'android/app/build.gradle.kts'
if (Test-Path $gradle) {
    $g = Get-Content $gradle -Raw
    if ($g -notmatch 'key\.properties') {
        $imports = "import java.io.FileInputStream`r`nimport java.util.Properties`r`n`r`n"
        $signing = @'
    signingConfigs {
        create("release") {
            val props = Properties()
            val propsFile = rootProject.file("key.properties")
            if (propsFile.exists()) {
                props.load(FileInputStream(propsFile))
                keyAlias = props["keyAlias"] as String
                keyPassword = props["keyPassword"] as String
                storeFile = file(props["storeFile"] as String)
                storePassword = props["storePassword"] as String
            }
        }
    }

'@
        $g = $imports + $g
        $g = $g.Replace('    buildTypes {', $signing + '    buildTypes {')
        $g = $g.Replace('signingConfig = signingConfigs.getByName("debug")',
            'signingConfig = if (rootProject.file("key.properties").exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")')
        Set-Content -Path $gradle -Value $g -NoNewline
        Write-Host "Signing config added to $gradle"
    } else {
        Write-Host "Signing config already present."
    }
} else {
    Write-Warning "android/app/build.gradle.kts not found - add release signing manually (see README)."
}

Write-Host "`nDone. Next:" -ForegroundColor Green
Write-Host "  1. Put real contact details in lib/config/app_config.dart"
Write-Host "  2. flutter run                      (test on a phone/emulator)"
Write-Host "  3. See README.md > 'Publish to Google Play' for the release build"
