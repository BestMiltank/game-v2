@echo off
setlocal
set "ENGINE=D:\code tools\godot_4.7.2\Godot_v4.7.2-stable_win64_console.exe"
"%ENGINE%" --headless --editor --import --quit --path "%~dp0."
if errorlevel 1 exit /b 1
"%ENGINE%" --path "%~dp0." %*
exit /b %errorlevel%
