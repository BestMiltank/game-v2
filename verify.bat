@echo off
setlocal
set "ENGINE=D:\code tools\godot_4.7.2\Godot_v4.7.2-stable_win64_console.exe"
set "STAGE=%~dp0."
set "RUNLOG=%TEMP%\action-yard-%RANDOM%-%RANDOM%.log"
call :run --headless --editor --import --quit
if errorlevel 1 exit /b 1
for %%T in (cast_attacks authored_hammer hammer_leg_probe) do (
  call :run --headless --script res://tests/%%T.gd
  if errorlevel 1 exit /b 1
)
call :run --script res://tests/pixel_parity.gd
if errorlevel 1 exit /b 1
call :run --script res://tests/arena_input.gd
exit /b %errorlevel%

:run
"%ENGINE%" --path "%STAGE%" %* > "%RUNLOG%" 2>&1
if errorlevel 1 goto fail
findstr /c:"SCRIPT ERROR:" /c:"ERROR:" "%RUNLOG%" >nul
if not errorlevel 1 goto fail
findstr /c:"PARITY:" /c:"TESTS:" /c:"CONTACT:" /c:"INPUT:" "%RUNLOG%"
exit /b 0
:fail
type "%RUNLOG%"
exit /b 1
