@echo off

if exist C:\generic-worker\disable-desktop-interrupt.reg reg import C:\generic-worker\disable-desktop-interrupt.reg
if exist C:\generic-worker\SetDefaultPrinter.ps1 powershell -NoLogo -file C:\generic-worker\SetDefaultPrinter.ps1 -WindowStyle hidden -NoProfile -ExecutionPolicy bypass
if exist C:\Windows\System32\fakemon.vbs cscript C:\Windows\System32\fakemon.vbs > C:\log\fakemon-stdout.log 2> C:\log\fakemon-stderr.log

:CheckForStateFlag
if exist Z:\loan goto End
if exist C:\dsc\task-claim-state.valid goto RunWorker
timeout /t 1 >nul
goto CheckForStateFlag

:RunWorker
if exist Z:\loan goto End
del /Q /F C:\dsc\task-claim-state.valid
pushd %~dp0
set errorlevel=
.\generic-worker.exe run --configure-for-aws > .\generic-worker.log 2>&1

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
if exist Z:\loan goto End
format Z: /fs:ntfs /v:"task" /q /y
<nul (set/p z=) >C:\dsc\task-claim-state.valid
shutdown /r /t 0 /f /c "Rebooting as generic worker ran successfully"

:End
