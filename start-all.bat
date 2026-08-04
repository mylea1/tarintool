@echo off
setlocal EnableExtensions

set "ROOT_DIR=%~dp0"
set "FRONTEND_DIR=%ROOT_DIR%web-prototype"
set "BACKEND_DIR=%ROOT_DIR%backend-mock"
set "FRONTEND_URL=http://127.0.0.1:4174/"
set "BACKEND_HEALTH=http://127.0.0.1:8790/health"

title KILO Development Launcher

where node.exe >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Node.js was not found. Install Node.js 20 or newer first.
  pause
  exit /b 1
)

where npm.cmd >nul 2>&1
if errorlevel 1 (
  echo [ERROR] npm was not found. Check the Node.js installation.
  pause
  exit /b 1
)

if not exist "%FRONTEND_DIR%\package.json" (
  echo [ERROR] Frontend directory was not found: %FRONTEND_DIR%
  pause
  exit /b 1
)

if not exist "%BACKEND_DIR%\server.mjs" (
  echo [ERROR] Backend entry was not found: %BACKEND_DIR%\server.mjs
  pause
  exit /b 1
)

if not exist "%FRONTEND_DIR%\node_modules\.bin\vite.cmd" (
  echo [SETUP] Installing frontend dependencies with npmmirror...
  pushd "%FRONTEND_DIR%"
  call npm.cmd install --registry=https://registry.npmmirror.com
  if errorlevel 1 (
    popd
    echo [ERROR] Frontend dependency installation failed.
    pause
    exit /b 1
  )
  popd
)

powershell.exe -NoProfile -Command "try { $r = Invoke-RestMethod -TimeoutSec 2 '%BACKEND_HEALTH%'; if ($r.service -eq 'kilo-backend-mock') { exit 0 } } catch {}; exit 1" >nul 2>&1
if errorlevel 1 (
  echo [START] Mock backend: http://127.0.0.1:8790
  start "KILO Backend" /D "%BACKEND_DIR%" cmd.exe /k "node server.mjs"
) else (
  echo [SKIP] Mock backend is already running.
)

powershell.exe -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 '%FRONTEND_URL%'; if ($r.StatusCode -eq 200) { exit 0 } } catch {}; exit 1" >nul 2>&1
if errorlevel 1 (
  echo [START] Web frontend: %FRONTEND_URL%
  start "KILO Frontend" /D "%FRONTEND_DIR%" cmd.exe /k "npm.cmd run dev"
) else (
  echo [SKIP] Web frontend is already running.
)

echo [WAIT] Checking both services...
set /a WAIT_COUNT=0

:WAIT_SERVICES
set "FRONTEND_READY=0"
set "BACKEND_READY=0"

powershell.exe -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 '%FRONTEND_URL%'; if ($r.StatusCode -eq 200) { exit 0 } } catch {}; exit 1" >nul 2>&1
if not errorlevel 1 set "FRONTEND_READY=1"

powershell.exe -NoProfile -Command "try { $r = Invoke-RestMethod -TimeoutSec 2 '%BACKEND_HEALTH%'; if ($r.service -eq 'kilo-backend-mock') { exit 0 } } catch {}; exit 1" >nul 2>&1
if not errorlevel 1 set "BACKEND_READY=1"

if "%FRONTEND_READY%"=="1" if "%BACKEND_READY%"=="1" goto SERVICES_READY

set /a WAIT_COUNT+=1
if %WAIT_COUNT% GEQ 30 goto SERVICES_FAILED
timeout /t 1 /nobreak >nul
goto WAIT_SERVICES

:SERVICES_READY
echo.
echo [READY] KILO development environment is running:
echo         Frontend: %FRONTEND_URL%
echo         Backend:  http://127.0.0.1:8790/
echo         Health:   %BACKEND_HEALTH%
echo.
if /I not "%~1"=="--no-browser" start "" "%FRONTEND_URL%"
exit /b 0

:SERVICES_FAILED
echo.
echo [ERROR] Services were not ready within 30 seconds.
echo         Check the KILO Frontend and KILO Backend windows for errors.
pause
exit /b 1
