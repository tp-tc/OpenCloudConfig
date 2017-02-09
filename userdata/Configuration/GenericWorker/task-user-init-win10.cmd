if "%cd%" NEQ "%USERPROFILE%" if exist %USERPROFILE%\AppData if not exist %cd%\AppData mklink /d %cd%\AppData %USERPROFILE%\AppData
powershell -command "& {& Add-AppxPackage -DisableDevelopmentMode -Register C:\Windows\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AppXManifest.xml -Verbose }"
