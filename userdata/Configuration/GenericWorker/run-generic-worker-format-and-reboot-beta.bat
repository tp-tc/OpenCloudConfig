@echo off

if "%USERNAME%" == "GenericWorker" ftype txtfile="C:\Windows\System32\Notepad.exe" "%%1"
if "%USERNAME%" == "GenericWorker" if exist "C:\Program Files (x86)" powershell -command "&{$p='HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3';$v=(Get-ItemProperty -Path $p).Settings;$v[8]=3;&Set-ItemProperty -Path $p -Name Settings -Value $v;&Stop-Process -ProcessName explorer}" > C:\log\taskbar-auto-hide-stdout.log 2> C:\log\taskbar-auto-hide-stderr.log
if exist C:\generic-worker\disable-desktop-interrupt.reg reg import C:\generic-worker\disable-desktop-interrupt.reg
if exist C:\generic-worker\SetDefaultPrinter.ps1 powershell -NoLogo -file C:\generic-worker\SetDefaultPrinter.ps1 -WindowStyle hidden -NoProfile -ExecutionPolicy bypass

if "%USERNAME%" != "GenericWorker" goto :CheckForStateFlag
:CheckForUserProfile
echo Checking user registry hive is loaded... >> C:\generic-worker\generic-worker.log
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects /ve
if %ERRORLEVEL% EQU 0 goto CheckForStateFlag
echo User registry hive is not loaded >> C:\generic-worker\generic-worker.log
timeout /t 1 >nul
goto CheckForUserProfile

:CheckForStateFlag
if exist Z:\loan logoff /f /n
if exist Z:\loan goto End
echo Checking for C:\dsc\task-claim-state.valid file... >> C:\generic-worker\generic-worker.log
if exist C:\dsc\task-claim-state.valid goto RunWorker
echo Not found >> C:\generic-worker\generic-worker.log
timeout /t 1 >nul
goto CheckForStateFlag

:RunWorker
echo File C:\dsc\task-claim-state.valid found >> C:\generic-worker\generic-worker.log
if exist Z:\loan logoff /f /n
if exist Z:\loan goto End
echo Deleting C:\dsc\task-claim-state.valid file >> C:\generic-worker\generic-worker.log
del /Q /F C:\dsc\task-claim-state.valid >> C:\generic-worker\generic-worker.log 2>&1
pushd %~dp0
set errorlevel=
.\generic-worker.exe run --configure-for-aws >> .\generic-worker.log 2>&1

rem exit code 67 means generic worker has created a task user and wants to reboot into it
if %errorlevel% equ 67 goto FormatAndReboot

rem exit code 0 handled for legacy reasons (needed when generic-worker version < 9.0.0)
if %errorlevel% equ 0 goto FormatAndReboot

rem commented shutdown as it interferes with loaner provisioning [occ kills gw in order to re-provision as loaner].
rem HaltOnIdle manages terminations with consideration to other instance states and requirements.
rem this script does not have the awareness of other considerations to manage this.
rem shutdown /s /t 0 /f /c "Killing worker, as generic worker crashed or had a problem"
goto End

:FormatAndReboot
if exist Z:\loan logoff /f /n
if exist Z:\loan goto End
format Z: /fs:ntfs /v:"task" /q /y
echo Creating file C:\dsc\task-claim-state.valid >> .\generic-worker.log
<nul (set/p z=) >C:\dsc\task-claim-state.valid
shutdown /r /t 0 /f /c "Rebooting as generic worker ran successfully"

:End
