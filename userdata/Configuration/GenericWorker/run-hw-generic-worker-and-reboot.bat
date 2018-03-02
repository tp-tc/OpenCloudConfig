@echo off

echo Running generic-worker startup script (run-generic-worker.bat) ... >> C:\generic-worker\generic-worker.log

rem needed for the generic worker 8.* to keep disk space free https://bugzilla.mozilla.org/show_bug.cgi?id=1441208#c12
echo Clearing temp directory  >> C:\generic-worker\generic-worker.log 
move C:\Users\GenericWorker\AppData\Local\Temp\live* C:\dsc\  >> C:\generic-worker\generic-worker.log
IF EXIST C:\Users\GenericWorker\AppData\Local\Temp del /s /q C:\Users\GenericWorker\AppData\Local\Temp  >> C:\generic-worker\generic-worker.log
IF EXIST C:\Users\GenericWorker\AppData\Local\Temp rmdir /s /q C:\Users\GenericWorker\AppData\Local\Temp  >> C:\generic-worker\generic-worker.log
move C:\dsc\live* C:\Users\GenericWorker\AppData\Local\Temp\  >> C:\generic-worker\generic-worker.log

cat C:\generic-worker\master-generic-worker.json | jq ".  | .workerId=\"%COMPUTERNAME%\"" > C:\generic-worker\gen_worker.config

if exist C:\generic-worker\disable-desktop-interrupt.reg reg import C:\generic-worker\disable-desktop-interrupt.reg

:CheckForStateFlag
echo Checking for C:\dsc\task-claim-state.valid file... >> C:\generic-worker\generic-worker.log
echo Deleting C:\dsc\task-claim-state.valid file >> C:\generic-worker\generic-worker.log
if exist C:\dsc\task-claim-state.valid goto RunWorker
timeout /t 1 >nul
goto CheckForStateFlag

:RunWorker
echo File C:\dsc\task-claim-state.valid found >> C:\generic-worker\generic-worker.log
del /Q /F C:\dsc\task-claim-state.valid >> C:\generic-worker\generic-worker.log 2>&1
pushd %~dp0
set errorlevel=
C:\generic-worker\generic-worker.exe run --config C:\generic-worker\gen_worker.config >> C:\generic-worker\generic-worker.log 2>&1
set GW_EXIT_CODE=%errorlevel%
if %GW_EXIT_CODE% equ 1 goto AwaitRepair
if %GW_EXIT_CODE% equ 67 goto RmLock

<nul (set/p z=) >C:\dsc\task-claim-state.valid
shutdown /r /t 0 /f /c "Rebooting as generic worker ran successfully"
exit

:RmLock
net stop winrm
del C:DSC\in-progress.lock
shutdown /r /t 0 /f /c "Rebooting as generic worker exit with code 67"
exit

:AwaitRepair
echo last exit code from gw indicates unhealthy instance >> C:\generic-worker\generic-worker.log
echo this instance is idling while awaiting repair >> C:\generic-worker\generic-worker.log
timeout /t 600 >nul
goto AwaitRepair
