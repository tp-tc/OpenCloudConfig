rd /s /q %cd%\AppData
mklink /d %cd%\AppData %USERPROFILE%\AppData
set AppData=%USERPROFILE%\AppData\Roaming
setx AppData %USERPROFILE%\AppData\Roaming
set LocalAppData=%USERPROFILE%\AppData\Local
setx LocalAppData %USERPROFILE%\AppData\Local
powershell -command "& {& Set-KnownFolderPath -KnownFolder RoamingAppData -Path $env:AppData }"
powershell -command "& {& Set-KnownFolderPath -KnownFolder LocalAppData -Path $env:LocalAppData }"
powershell -command "& {& Add-AppxPackage -DisableDevelopmentMode -Register C:\Windows\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AppXManifest.xml -Verbose }"
