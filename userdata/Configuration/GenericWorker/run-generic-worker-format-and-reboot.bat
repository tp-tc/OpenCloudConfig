@echo off

echo Running generic-worker startup script (run-generic-worker.bat) ... >> C:\generic-worker\generic-worker.log
if "%USERNAME%" == "GenericWorker" ftype txtfile="C:\Windows\System32\Notepad.exe" "%%1"
if "%USERNAME%" == "GenericWorker" if exist "C:\Program Files (x86)" powershell -command "&{$p='HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3';$v=(Get-ItemProperty -Path $p).Settings;$v[8]=3;&Set-ItemProperty -Path $p -Name Settings -Value $v;&Stop-Process -ProcessName explorer}" > C:\log\taskbar-auto-hide-stdout.log 2> C:\log\taskbar-auto-hide-stderr.log
if exist C:\generic-worker\disable-desktop-interrupt.reg reg import C:\generic-worker\disable-desktop-interrupt.reg
if exist C:\generic-worker\SetDefaultPrinter.ps1 powershell -NoLogo -file C:\generic-worker\SetDefaultPrinter.ps1 -WindowStyle hidden -NoProfile -ExecutionPolicy bypass

if not "%USERNAME%" == "GenericWorker" goto CheckForStateFlag
:CheckForUserProfile
echo Checking user registry hive is loaded... >> C:\generic-worker\generic-worker.log
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects /ve
if %ERRORLEVEL% EQU 0 goto CheckForStateFlag
echo User registry hive is not loaded >> C:\generic-worker\generic-worker.log
ping -n 2 127.0.0.1 1>/nul
goto CheckForUserProfile

:CheckForStateFlag
if exist Z:\loan logoff /f /n
if exist Z:\loan goto End
echo Checking for C:\dsc\task-claim-state.valid file... >> C:\generic-worker\generic-worker.log
if exist C:\dsc\task-claim-state.valid goto RunWorker
echo Not found >> C:\generic-worker\generic-worker.log
ping -n 2 127.0.0.1 1>/nul
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
set gw_exit_code=%errorlevel%

rem exit code 67 means generic worker has created a task user and wants to reboot into it
if %gw_exit_code% equ 67 goto FormatAndReboot

rem exit code 68 means generic worker has reached it's idle timeout and the instance should be retired
if %gw_exit_code% equ 68 goto RetireIdleInstance

rem exit code 0 handled for legacy reasons (needed when generic-worker version < 9.0.0)
if %gw_exit_code% equ 0 goto FormatAndReboot

rem for all other exit codes, simply end script execution and allow halt-on-idle or prep-loaner to do its thing 
goto End

:RetireIdleInstance
shutdown /s /t 10 /c "shutting down; max idle time reached" /d p:4:1
goto End

:FormatAndReboot
if exist Z:\loan logoff /f /n
if exist Z:\loan goto End
format Z: /fs:ntfs /v:"task" /q /y
shutdown /r /t 0 /f /c "rebooting; generic worker task run completed" /d p:4:1

:End
