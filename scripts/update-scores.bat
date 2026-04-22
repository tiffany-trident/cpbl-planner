@echo off
REM update-scores.bat - daily CPBL score fetcher and git pusher
REM Triggered by Windows Task Scheduler. See docs/scoreupdate.md plan D.

setlocal EnableDelayedExpansion

REM === Config (edit if Git is installed elsewhere) ===
set "REPO=C:\Trident\AI Work\baseball plan"
set "GIT=C:\Program Files\Git\cmd\git.exe"
REM ===================================================

set "LOGDIR=%REPO%\logs"
set "LOG=%LOGDIR%\update-scores.log"
set "PS1=%REPO%\scripts\update-scores.ps1"

if not exist "%LOGDIR%" mkdir "%LOGDIR%"

cd /d "%REPO%"
if errorlevel 1 (
  echo [FATAL] cannot cd to %REPO% >> "%LOG%"
  exit /b 1
)

for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do set "TS=%%t"

echo. >> "%LOG%"
echo ===== !TS! ===== >> "%LOG%"

if not exist "%GIT%" (
  echo [FATAL] GIT not found: %GIT% >> "%LOG%"
  exit /b 1
)
if not exist "%PS1%" (
  echo [FATAL] PS1 not found: %PS1% >> "%LOG%"
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [FAIL] update-scores.ps1 exited non-zero >> "%LOG%"
  exit /b 1
)

"%GIT%" diff --quiet -- index.html cpbl-planner.html data/briefings.json
if errorlevel 1 (
  "%GIT%" add index.html cpbl-planner.html data/briefings.json >> "%LOG%" 2>&1
  "%GIT%" commit -m "auto update scores !TS!" >> "%LOG%" 2>&1
  "%GIT%" push >> "%LOG%" 2>&1
  if errorlevel 1 (
    echo [FAIL] git push failed >> "%LOG%"
    exit /b 1
  )
  echo [OK] committed and pushed >> "%LOG%"
) else (
  echo [OK] no changes >> "%LOG%"
)

endlocal
