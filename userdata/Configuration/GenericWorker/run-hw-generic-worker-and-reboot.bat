@echo off

rem needed for the generic worker 8.* to keep disk space free https://bugzilla.mozilla.org/show_bug.cgi?id=1441208#c12
IF EXIST C:\Users\GenericWorker\AppData\Local\Temp del /s /q C:\Users\GenericWorker\AppData\Local\Temp
IF EXIST C:\Users\GenericWorker\AppData\Local\Temp rmdir /s /q C:\Users\GenericWorker\AppData\Local\Temp

cat C:\generic-worker\master-generic-worker.json | jq ".  | .workerId=\"%COMPUTERNAME%\"" > C:\generic-worker\gen_worker.config

if exist C:\generic-worker\disable-desktop-interrupt.reg reg import C:\generic-worker\disable-desktop-interrupt.reg

:CheckForStateFlag
if exist C:\dsc\task-claim-state.valid goto RunWorker
timeout /t 1 >nul
goto CheckForStateFlag

:RunWorker
del /Q /F C:\dsc\task-claim-state.valid
pushd %~dp0
set errorlevel=
C:\generic-worker\generic-worker.exe run --config C:\generic-worker\gen_worker.config >> C:\generic-worker\generic-worker.log 2>&1
set GW_EXIT_CODE=%errorlevel%
if %GW_EXIT_CODE% equ 1 shutdown /s /t 0 /f /c "Halting as worker is impaired"
if %GW_EXIT_CODE% equ 67 goto RmLock

<nul (set/p z=) >C:\dsc\task-claim-state.valid
shutdown /r /t 0 /f /c "Rebooting as generic worker ran successfully"

:RmLock
net stop winrm
del C:DSC\in-progress.lock
shutdown /r /t 0 /f /c "Rebooting as generic worker exit with code 67"
