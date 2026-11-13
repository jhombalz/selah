@echo off
setlocal
cd /d "%~dp0.."
call .tools\flutter\bin\flutter.bat build apk --release --obfuscate --split-debug-info=.tools/android-symbols
exit /b %errorlevel%
