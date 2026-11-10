@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  翠鸟攻击展示（原向/镜像） - Windows 启动脚本
rem  双击 launch.bat 直接运行
rem  参数会原样传给 Godot，例如 launch.bat --headless --script res://tests/test.gd
rem  设置 GODOT_BIN 可手动指定引擎路径
rem  设置 GODOT_CONSOLE=1 可用 console 版启动以查看日志
rem ============================================================

rem 项目目录 = 本脚本所在目录
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

if not exist "%PROJECT_DIR%\project.godot" (
    echo [错误] 在 %PROJECT_DIR% 下找不到 project.godot
    echo        请把 launch.bat 放在 Godot 项目根目录。
    pause
    exit /b 1
)

set "GODOT_BIN="

rem ---------- 1) 优先使用环境变量 GODOT_BIN ----------
if defined GODOT_BIN (
    if exist "%GODOT_BIN%" (
        echo [信息] 使用环境变量 GODOT_BIN: %GODOT_BIN%
    ) else (
        echo [警告] GODOT_BIN 指向的文件不存在，改为自动查找
        set "GODOT_BIN="
    )
)

rem ---------- 2) 再查 PATH 里的 godot ----------
if not defined GODOT_BIN (
    for %%G in (godot.exe godot4.exe) do (
        if not defined GODOT_BIN (
            for /f "delims=" %%P in ('where %%G 2^>nul') do (
                if not defined GODOT_BIN set "GODOT_BIN=%%P"
            )
        )
    )
)

rem ---------- 3) 已知安装位置直查 ----------
if not defined GODOT_BIN (
    if exist "C:\software\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe" (
        set "GODOT_BIN=C:\software\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
    )
)

rem ---------- 4) 最后扫描常见安装根目录 ----------
if not defined GODOT_BIN (
    for %%R in ("C:\software" "%ProgramFiles%" "%LOCALAPPDATA%\Programs") do (
        if not defined GODOT_BIN (
            for /f "delims=" %%F in ('dir /b /s "%%~R\Godot*\Godot_v*_win64.exe" 2^>nul ^| findstr /i /v "_console.exe"') do (
                if not defined GODOT_BIN set "GODOT_BIN=%%F"
            )
        )
    )
)

if not defined GODOT_BIN (
    echo.
    echo [错误] 没有找到 Godot 4 可执行文件。
    echo   办法一: 设置环境变量 GODOT_BIN 指向 Godot 的 exe
    echo   办法二: 把 Godot 4.7 标准版解压到 C:\software\Godot-4.7.2
    echo.
    pause
    exit /b 1
)

rem ---------- 5) 想看引擎日志时换成 console 版 ----------
if "%GODOT_CONSOLE%"=="1" (
    set "CONSOLE_BIN=!GODOT_BIN:_win64.exe=_win64_console.exe!"
    if exist "!CONSOLE_BIN!" set "GODOT_BIN=!CONSOLE_BIN!"
)

echo [信息] Godot : !GODOT_BIN!
echo [信息] 项目  : %PROJECT_DIR%
echo [信息] 启动中...
echo.

rem 无参数 = 双击启动，游戏独立运行，关闭本窗口不影响游戏
rem 有参数 = 命令行调试，同步执行并保留引擎输出
if "%~1"=="" (
    start "" "!GODOT_BIN!" --path "%PROJECT_DIR%"
    timeout /t 2 >nul
    exit /b 0
)

"!GODOT_BIN!" --path "%PROJECT_DIR%" %*
exit /b %ERRORLEVEL%
