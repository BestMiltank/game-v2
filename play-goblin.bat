@echo off
setlocal
call "%~dp0play.bat" res://scenes/goblin_trial.tscn %*
exit /b %errorlevel%
