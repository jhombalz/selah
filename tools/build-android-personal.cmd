@echo off
setlocal
cd /d "%~dp0.."
if not exist .tools\android-secrets.json (
  echo Missing .tools\android-secrets.json. See docs/android-online-editions.md.
  exit /b 1
)
call .tools\flutter\bin\flutter.bat build apk --release --obfuscate --split-debug-info=.tools/android-symbols --dart-define-from-file=.tools/android-secrets.json
exit /b %errorlevel%
