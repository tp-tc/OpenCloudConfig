@echo off

reg import C:\generic-worker\disable-desktop-interrupt.reg

:CheckForStateFlag
if exist C:\dsc\task-claim-state.valid goto RunWorker
timeout /t 1 >nul
goto CheckForStateFlag

:RunWorker
del /Q /F C:\dsc\task-claim-state.valid
pushd %~dp0
set errorlevel=
.\generic-worker.exe run --configure-for-aws > .\generic-worker.log 2>&1

if %errorlevel% equ 0 goto successful

shutdown /s /t 0 /f /c "Killing worker, as generic worker crashed or had a problem"
goto end

:successful
format Z: /fs:ntfs /v:"task" /q /y
<nul (set/p z=) >C:\dsc\task-claim-state.valid
shutdown /r /t 0 /f /c "Rebooting as generic worker ran successfully"

:end
