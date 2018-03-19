@echo off

echo Checking for key pair >> C:\generic-worker\generic-worker.log
If exist C:\generic-worker\generic-worker-gpg-signing-key.key echo Key pair present >> C:\generic-worker\generic-worker.log
If not exist C:\generic-worker\generic-worker-gpg-signing-key.key echo Generating key pair >> C:\generic-worker\generic-worker.log
If not exist C:\generic-worker\generic-worker-gpg-signing-key.key C:\generic-worker\generic-worker.exe new-openpgp-keypair --file C:\generic-worker\generic-worker-gpg-signing-key.key"
If exist C:\generic-worker\generic-worker-gpg-signing-key.key echo Key pair created >> C:\generic-worker\generic-worker.log
If not exist C:\generic-worker\generic-worker-gpg-signing-key.key shutdown /r /t 0 /f /c "Rebooting as key generation failed"


echo Running generic-worker startup script (run-generic-worker.bat) ... >> C:\generic-worker\generic-worker.log

echo Disk space stats of C:\ >> C:\generic-worker\generic-worker.log
fsutil volume diskfree c: >> C:\generic-worker\generic-worker.log

If exist C:\generic-worker\gen_worker.config GoTo PreWorker
for /F "tokens=14" %%i in ('"ipconfig | findstr IPv4"') do SET LOCAL_IP=%%i
cat C:\generic-worker\master-generic-worker.json | jq ".  | .workerId=\"%COMPUTERNAME%\"" > C:\generic-worker\gen_worker.json
cat C:\generic-worker\gen_worker.json | jq ".  | .publicIP=\"%LOCAL_IP%\"" > C:\generic-worker\gen_worker.config


:PreWorker
if exist C:\generic-worker\disable-desktop-interrupt.reg reg import C:\generic-worker\disable-desktop-interrupt.reg

:CheckForStateFlag
echo Checking for C:\dsc\task-claim-state.valid file... >> C:\generic-worker\generic-worker.log
if exist C:\dsc\task-claim-state.valid goto RunWorker
timeout /t 1 >nul
goto CheckForStateFlag

:RunWorker
rem Bug 1445779 
del /s /q /f  C:\Windows\SoftwareDistribution\Download\*

echo File C:\dsc\task-claim-state.valid found >> C:\generic-worker\generic-worker.log
echo Deleting C:\dsc\task-claim-state.valid file >> C:\generic-worker\generic-worker.log
del /Q /F C:\dsc\task-claim-state.valid >> C:\generic-worker\generic-worker.log 2>&1
pushd %~dp0
set errorlevel=
C:\generic-worker\generic-worker.exe run --config C:\generic-worker\gen_worker.config >> C:\generic-worker\generic-worker.log 2>&1
set GW_EXIT_CODE=%errorlevel%

if %GW_EXIT_CODE% EQU 69 goto ErrorReboot

<nul (set/p z=) >C:\dsc\task-claim-state.valid
echo Generic worker ran successfully (exit code %GW_EXIT_CODE%) rebooting
if exist C:\generic-worker\rebootcount.txt del /Q /F  C:\generic-worker\rebootcount.txt
shutdown /r /t 0 /f /c "Rebooting as generic worker ran successfully"
exit

:ErrorReboot
if exist C:DSC\in-progress.lock del /Q /F C:DSC\in-progress.lock
if exist C:\generic-worker\rebootcount.txt GoTo AdditonalReboots
echo 1 >> C:\generic-worker\rebootcount.txt
echo Generic worker exit with code %GW_EXIT_CODE%; Rebooting to recover  >> C:\generic-worker\generic-worker.log
shutdown /r /t 0 /f /c "Generic worker exit with code %GW_EXIT_CODE%; Attempting reboot to recover"
exit
:AdditonalReboots
for /f "delims=" %%a in ('type "C:\generic-worker\rebootcount" ' ) do set num=%%a
set /a num=num + 1 > C:\generic-worker\rebootcount.txt
if %num% GTR 5 GoTo WaitReboot
echo Generic worker exit with code %GW_EXIT_CODE% more than once; Rebooting to recover  >> C:\generic-worker\generic-worker.log
shutdown /r /t 0 /f /c "Generic worker has not recovered;  Rebooting"
exit
:WaitReboot
echo Generic worker exit with code %GW_EXIT_CODE% %num% times; 1800 second delay and then rebooting  >> C:\generic-worker\generic-worker.log
sleep 1800
shutdown /r /t 0 /f /c "Generic worker has not recovered;  Rebooting"
exit
