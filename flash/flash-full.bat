@echo off
setlocal
rem ============================================================
rem  Balong E5372 (hi6920cs): flash FULL update image
rem  with Linux 3.10 kernel inside (stock webui mod1.5.2 kept)
rem  Writer: balong_flash (c) forth32 2015, GNU GPLv3
rem ============================================================
cd /d "%~dp0"

set BIN=%~dp0..\port\E5372_Update_21.290.23.00.00_kernel-3.10.bin

echo ================================================================
echo   Balong E5372  -  FULL update (kernel 3.10 + webui mod1.5.2)
echo ================================================================
echo.
echo  WARNING: this writes every partition. Do NOT power off while
echo  flashing. If unsure, use flash-kernel.bat instead.
echo.
echo  STEP 1. Put the device into GODLOAD (download) mode:
echo      - power the device OFF
echo      - hold the MENU key, then apply power
echo      - screen shows "Force Download" - press MENU again
echo      (or over a terminal: AT^GODLOAD)
echo.
echo  STEP 2. In Device Manager find the modem serial port.
echo.

set /p COMPORT=COM port number (e.g. 9): 

if "%COMPORT%"=="" goto usage
if not exist "%BIN%" goto nobin

echo.
echo  STEP 3. Press ENTER to flash the full image...
pause

balong_flash.exe -p%COMPORT% -m "%BIN%"
if errorlevel 1 goto fail

echo.
echo  DONE. The device restarts with the full custom image.
pause
exit /b 0

:fail
echo.
echo  FAILED (exit code %errorlevel%).
echo  Check: GODLOAD mode active, correct COM port, no other program
echo  holding the port. Try again.
pause
exit /b 1

:nobin
echo  ERROR: full image not found: %BIN%
pause
exit /b 1

:usage
echo  Usage: double-click this file, then type the COM port number.
pause
exit /b 1