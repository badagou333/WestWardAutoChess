@echo off
setlocal
if defined GODOT_BIN (
  "%GODOT_BIN%" --path "%~dp0." %*
) else (
  godot --path "%~dp0." %*
)
if errorlevel 1 (
  echo Please install Godot 4 and set GODOT_BIN to its executable path.
  pause
)
