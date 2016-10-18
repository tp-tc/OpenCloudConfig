@echo off

:CheckForStateFlag
if exist C:\dsc\task-claim-state.valid goto RunWorker
timeout /t 1 >nul
goto CheckForStateFlag

:RunWorker
pushd %~dp0
.\generic-worker.exe run --configure-for-aws > .\generic-worker.log 2>&1
