md %cd%\empty
robocopy /mir %cd%\empty %cd%\AppData
rd /s /q %cd%\AppData %cd%\empty
mklink /d %cd%\AppData %USERPROFILE%\AppData
powershell -command "& {& Add-AppxPackage -DisableDevelopmentMode -Register C:\Windows\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AppXManifest.xml -Verbose }"
