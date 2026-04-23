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

REM === Branch guard: auto-update must commit to main ===
set "ORIG_BRANCH="
for /f "usebackq delims=" %%b in (`"%GIT%" rev-parse --abbrev-ref HEAD`) do set "ORIG_BRANCH=%%b"
if "!ORIG_BRANCH!"=="" (
  echo [FATAL] cannot detect current branch >> "%LOG%"
  exit /b 1
)

REM Refuse to proceed if tracked files are dirty (checkout would clobber in-progress work)
"%GIT%" diff --quiet
if errorlevel 1 goto :dirty_abort
"%GIT%" diff --cached --quiet
if errorlevel 1 goto :dirty_abort
goto :tree_clean
:dirty_abort
echo [ABORT] working tree dirty on branch !ORIG_BRANCH! -- skip auto-update, resolve manually >> "%LOG%"
exit /b 1
:tree_clean

set "SWITCHED=0"
if /i not "!ORIG_BRANCH!"=="main" (
  echo [info] switching from !ORIG_BRANCH! to main for auto-update >> "%LOG%"
  "%GIT%" checkout main >> "%LOG%" 2>&1
  if errorlevel 1 (
    echo [FAIL] checkout main failed >> "%LOG%"
    exit /b 1
  )
  set "SWITCHED=1"
  "%GIT%" pull >> "%LOG%" 2>&1
)

set "FINAL_EXIT=0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [FAIL] update-scores.ps1 exited non-zero >> "%LOG%"
  set "FINAL_EXIT=1"
  goto :restore_branch
)

"%GIT%" diff --quiet -- index.html cpbl-planner.html data/briefings.json
if errorlevel 1 (
  "%GIT%" add index.html cpbl-planner.html data/briefings.json >> "%LOG%" 2>&1
  "%GIT%" commit -m "auto update scores !TS!" >> "%LOG%" 2>&1
  "%GIT%" push >> "%LOG%" 2>&1
  if errorlevel 1 (
    echo [FAIL] git push failed >> "%LOG%"
    set "FINAL_EXIT=1"
    goto :restore_branch
  )
  echo [OK] committed and pushed >> "%LOG%"
) else (
  echo [OK] no changes >> "%LOG%"
)

:restore_branch
if "!SWITCHED!"=="1" (
  echo [info] switching back to !ORIG_BRANCH! >> "%LOG%"
  "%GIT%" checkout !ORIG_BRANCH! >> "%LOG%" 2>&1
  if errorlevel 1 (
    echo [FAIL] checkout back to !ORIG_BRANCH! failed >> "%LOG%"
    set "FINAL_EXIT=1"
  )
)

if "!FINAL_EXIT!"=="1" exit /b 1
endlocal
