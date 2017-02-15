robocopy %USERPROFILE%\AppData\Local %cd%\AppData\Local /mir /sec /xjd /w:1 /r:1
robocopy %USERPROFILE%\AppData\Roaming %cd%\AppData\Roaming /mir /sec /xjd /w:1 /r:1
powershell -command "& {& Add-AppxPackage -DisableDevelopmentMode -Register C:\Windows\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AppXManifest.xml -Verbose }"
