rem task user initialisation script

rem task user firewall exceptions
netsh advfirewall firewall add rule name="ssltunnel-%USERNAME%" dir=in action=allow program="%USERPROFILE%\build\tests\bin\ssltunnel.exe" enable=yes
netsh advfirewall firewall add rule name="ssltunnel-%USERNAME%" dir=out action=allow program="%USERPROFILE%\build\tests\bin\ssltunnel.exe" enable=yes
netsh advfirewall firewall add rule name="python-%USERNAME%" dir=in action=allow program="%USERPROFILE%\build\venv\scripts\python.exe" enable=yes
netsh advfirewall firewall add rule name="python-%USERNAME%" dir=out action=allow program="%USERPROFILE%\build\venv\scripts\python.exe" enable=yes
