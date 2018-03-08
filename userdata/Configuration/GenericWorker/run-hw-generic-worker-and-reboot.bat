@echo off

echo Checking for key pair >> C:\generic-worker\generic-worker.log
If exist C:\generic-worker\generic-worker-gpg-signing-key.key echo Key pair present >> C:\generic-worker\generic-worker.log
If not exist C:\generic-worker\generic-worker-gpg-signing-key.key echo Generating key pair >> C:\generic-worker\generic-worker.log
If not exist C:\generic-worker\generic-worker-gpg-signing-key.key C:\generic-worker\generic-worker.exe new-openpgp-keypair --file C:\generic-worker\generic-worker-gpg-signing-key.key"
If exist C:\generic-worker\generic-worker-gpg-signing-key.key echo Key pair created >> C:\generic-worker\generic-worker.log
If not exist C:\generic-worker\generic-worker-gpg-signing-key.key GoTo AwaitRepair


echo Running generic-worker startup script (run-generic-worker.bat) ... >> C:\generic-worker\generic-worker.log

echo Disk space stats of C:\ >> C:\generic-worker\generic-worker.log
fsutil volume diskfree c: >> C:\generic-worker\generic-worker.log

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
if %GW_EXIT_CODE% equ 67 goto AwaitRepair

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
