@echo off
setlocal
pushd "%~dp0.."
call .tools\flutter\bin\flutter.bat build web --no-web-resources-cdn %*
if errorlevel 1 goto failed
node tools\prepare-web-offline.cjs
if errorlevel 1 goto failed
popd
exit /b 0
:failed
popd
exit /b 1
