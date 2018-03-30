@echo off

if exist C:\generic-worker\wait.semaphore GoTo wait

copy /y C:\generic-worker\generic-worker.log c:\log\generic-worker%time:~-5%.log 
type NUL > C:\generic-worker\generic-worker.log
echo Running generic-worker startup script (run-generic-worker.bat) ... >> C:\generic-worker\generic-worker.log

for /F "tokens=* skip=1" %%n in ('WMIC path Win32_VideoController get Name ^| findstr "."') do set GPU_NAME=%%n
echo Graphic Card being used "%GPU_NAME%" >> C:\generic-worker\generic-worker.log
if not "%GPU_NAME%"=="Intel(R) Iris(R) Pro Graphics P580  "  Goto Graphic_Card_Reboot

echo Disk space stats of C:\ >> C:\generic-worker\generic-worker.log
SETLOCAL EnableDelayedExpansion
FOR /f "usebackq delims== tokens=2" %%x IN (`wmic logicaldisk where "DeviceID='C:'" get FreeSpace /format:value`) DO SET "FreeSpaceBig=%%x"
SET FreeSpace=!FreeSpaceBig:~0,-7!
IF %FreeSpace% GTR 25240 echo %FreeSpace% MB available disk space >> C:\generic-worker\generic-worker.log
IF %FreeSpace% LSS 25240 echo Disk space ABNORMALLY low  %FreeSpace% MB available >> C:\generic-worker\generic-worker.log
IF %FreeSpace% LSS 15240 echo ALERT disk space is low %FreeSpace% MB available >> C:\generic-worker\generic-worker.log
ENDLOCAL

If exist C:\generic-worker\gen_worker.config GoTo PreWorker
for /F "tokens=14" %%i in ('"ipconfig | findstr IPv4"') do SET LOCAL_IP=%%i
cat C:\generic-worker\master-generic-worker.json | jq ".  | .workerId=\"%COMPUTERNAME%\"" > C:\generic-worker\gen_worker.json
cat C:\generic-worker\gen_worker.json | jq ".  | .publicIP=\"%LOCAL_IP%\"" > C:\generic-worker\gen_worker.config

:PreWorker
if exist C:\generic-worker\disable-desktop-interrupt.reg reg import C:\generic-worker\disable-desktop-interrupt.reg

:CheckForStateFlag
echo Checking for C:\dsc\task-claim-state.valid file... >> C:\generic-worker\generic-worker.log
if exist C:\dsc\task-claim-state.valid goto RunWorker
timeout /t 5 >nul
goto CheckForStateFlag

:RunWorker
rem Change resolution to 1280 x 1024 Re: Bug 1437615
echo Changing resolution to 1280 x 1024 >> C:\generic-worker\generic-worker.log 2>&1
c:\dsc\configmymonitor.exe r8 v0 
echo File C:\dsc\task-claim-state.valid found >> C:\generic-worker\generic-worker.log
echo Deleting C:\dsc\task-claim-state.valid file >> C:\generic-worker\generic-worker.log
del /Q /F C:\dsc\task-claim-state.valid >> C:\generic-worker\generic-worker.log 2>&1
pushd %~dp0
set errorlevel=
C:\generic-worker\generic-worker.exe run --config C:\generic-worker\gen_worker.config >> C:\generic-worker\generic-worker.log 2>&1
set GW_EXIT_CODE=%errorlevel%
if %GW_EXIT_CODE% equ 1 goto ErrorReboot
if %GW_EXIT_CODE% equ 67 goto ErrorReboot
if %GW_EXIT_CODE% EQU 69 goto ErrorReboot

<nul (set/p z=) >C:\dsc\task-claim-state.valid
for /F "tokens=* skip=1" %%n in ('WMIC path Win32_VideoController get Name ^| findstr "."') do set GPU_NAME=%%n
echo Graphic Card being used "%GPU_NAME%" >> C:\generic-worker\generic-worker.log
if not "%GPU_NAME%"=="Intel(R) Iris(R) Pro Graphics P580  " echo Graphic card is in an unexpected state post test >> C:\generic-worker\generic-worker.log
if not "%GPU_NAME%"=="Intel(R) Iris(R) Pro Graphics P580  "  Goto Graphic_Card_Reboot >> C:\generic-worker\generic-worker.log

echo Removing temp dir contents >> C:\generic-worker\generic-worker.log 2>&1
del /s /q C:\Users\GenericWorker\AppData\Local\Temp\*  >> C:\generic-worker\generic-worker.log
rem Bug 1445779 Cleanup some left overs from the OCC run
del /s /q /f  C:\Windows\SoftwareDistribution\Download\*
del /s /q /f "C:\Program Files\rempl\Logs\*" 
del /s /q /f "C:\ProgramData\Package Cache\*" 
if exist C:\$WINDOWS.~BT del /s /f /q C:\$WINDOWS.~BT  
Dism.exe /online /Cleanup-Image /StartComponentCleanup 
forfiles -p "C:\log" -s -m *.* -d -1 -c "cmd /c del @path"
rmdir /s /q  %systemdrive%\$Recycle.bin 
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

:Graphic_Card_Reboot
type NUL > C:\generic-worker\wait.semaphore
echo Graphics card is in an unexpected state! >> C:\generic-worker\generic-worker.log
echo enable basic display and rebooting  >> C:\generic-worker\generic-worker.log
sc config "basicdisplay" start=auto >> C:\generic-worker\generic-worker.log
shutdown /r /t 0 /f /c "Graphics card is in an unexpected state!"
exit

:wait 
echo Waiting on human interaction to fix!  >> C:\generic-worker\generic-worker.log
sleep 120
GoTo wait
