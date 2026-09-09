@echo off
setlocal
rem ============================================================
rem  Balong E5372 (hi6920cs): flash Linux 3.10 kernel component
rem  Writer: balong_flash (c) forth32 2015, GNU GPLv3
rem ============================================================
cd /d "%~dp0"

echo ================================================================
echo   Balong E5372  -  kernel 3.10  (component only, REST stays stock)
echo ================================================================
echo.
echo  STEP 1. Put the device into GODLOAD (download) mode:
echo      - power the device OFF
echo      - hold the MENU key, then apply power
echo      - screen shows "Force Download" - press MENU again
echo      (or over a terminal: AT^GODLOAD)
echo.
echo  STEP 2. In Device Manager find the modem serial port
echo      (a "Huawei ... COMx" port appears in GODLOAD mode).
echo.

set /p COMPORT=COM port number (e.g. 9): 

if "%COMPORT%"=="" goto usage
if not exist "%~dp0fw\05-00000105-Kernel_R1.fw" goto nofw

echo.
echo  STEP 3. Flashing the kernel component only.
echo  Device MUST stay connected during the whole flash.
echo  Press ENTER to start...
pause

balong_flash.exe -p%COMPORT% -n "%~dp0fw"
if errorlevel 1 goto fail

echo.
echo  DONE. The device restarts. Kernel 3.10 is written, the rest of
echo  the firmware (webui) is untouched.
echo.
echo  Recovery: in GODLOAD mode re-flash the STOCK component
echo  from stock_firmware\unpacked\ using the same command.
pause
exit /b 0

:fail
echo.
echo  FAILED (exit code %errorlevel%).
echo  Check: GODLOAD mode active, correct COM port, no other program
echo  holding the port. Try again.
pause
exit /b 1

:nofw
echo  ERROR: file not found: %~dp0fw\05-00000105-Kernel_R1.fw
pause
exit /b 1

:usage
echo  Usage: double-click this file, then type the COM port number.
pause
exit /b 1