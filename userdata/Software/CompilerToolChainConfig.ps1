<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration CompilerToolChainConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  # log folder for installation logs
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  File ToolsFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\tools' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  
  Script DirectXSdkDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://download.microsoft.com/download/A/E/7/AE743F1F-632B-4809-87A9-AA1BB3458E31/DXSDK_Jun10.exe', ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script DirectXSdkInstall {
    DependsOn = @('[Script]DirectXSdkDownload', '[File]LogFolder')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Microsoft DirectX SDK (June 2010)\system\uninstall\DXSDK_Jun10.exe' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) } }
    SetScript = {
      # https://blogs.msdn.microsoft.com/chuckw/2011/12/09/known-issue-directx-sdk-june-2010-setup-and-the-s1023-error/
      Start-Process 'MsiExec.exe' -ArgumentList '/passive /X{F0C3E5D1-1ADE-321E-8167-68EF0DE699A5}' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.vcredist2010x86.uninstall.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.vcredist2010x86.uninstall.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Process 'MsiExec.exe' -ArgumentList '/passive /X{1D8E6291-B0D5-35EC-8441-6616F567A0F7}' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.vcredist2010x64.uninstall.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.vcredist2010x64.uninstall.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Process ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot) -ArgumentList '/U' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.DXSDK_Jun10.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.DXSDK_Jun10.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (Test-Path -Path ('{0}\Microsoft DirectX SDK (June 2010)\system\uninstall\DXSDK_Jun10.exe' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }

  Chocolatey VCRedist2010Install {
    Ensure = 'Present'
    Package = 'vcredist2010'
    Version = '10.0.40219.1'
  }
  Chocolatey WindowsSdkInstall {
    Ensure = 'Present'
    Package = 'windows-sdk-8.1'
    Version = '8.100.26654.0'
  }

  Script RustDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\rust-1.6.0-x86_64-pc-windows-msvc.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://static.rust-lang.org/dist/rust-1.6.0-x86_64-pc-windows-msvc.msi', ('{0}\Temp\rust-1.6.0-x86_64-pc-windows-msvc.msi' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\rust-1.6.0-x86_64-pc-windows-msvc.msi' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\rust-1.6.0-x86_64-pc-windows-msvc.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Package RustInstall {
    DependsOn = @('[Script]RustDownload', '[File]LogFolder')
    Name = 'Rust 1.6 (MSVC 64-bit)'
    Path = ('{0}\Temp\rust-1.6.0-x86_64-pc-windows-msvc.msi' -f $env:SystemRoot)
    ProductId = 'A21886AC-C591-4CC0-BA5B-C080B88F630B'
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.rust-1.6.0-x86_64-pc-windows-msvc.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }
  Script RustSymbolicLink {
    DependsOn = @('[Package]RustInstall', '[File]ToolsFolder')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\tools\rust' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\tools' -f $env:SystemDrive) -Name 'rust' -Target ('{0}\Rust stable MSVC 1.6' -f $env:ProgramFiles)
      } else {
        & cmd @('/c', 'mklink', '/D', ('{0}\tools\rust' -f $env:SystemDrive), ('{0}\Rust stable MSVC 1.6' -f $env:ProgramFiles))
      }
    }
    TestScript = { (Test-Path -Path ('{0}\tools\rust' -f $env:SystemDrive) -ErrorAction SilentlyContinue) }
  }
  
  Script MozillaBuildDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\MozillaBuildSetup-2.1.0.exe' -f $env:SystemRoot)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://ftp.mozilla.org/pub/mozilla/libraries/win32/MozillaBuildSetup-2.1.0.exe', ('{0}\Temp\MozillaBuildSetup-2.1.0.exe' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\MozillaBuildSetup-2.1.0.exe' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\MozillaBuildSetup-2.1.0.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script MozillaBuildInstall {
    DependsOn = @('[Script]MozillaBuildDownload', '[File]LogFolder')
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\mozilla-build\VERSION' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and ((Get-Content ('{0}\mozilla-build\VERSION' -f $env:SystemDrive)) -eq '2.1.0') -and (Test-Path -Path ('{0}\mozilla-build\msys\bin\sh.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) } }
    SetScript = {
      Start-Process ('{0}\Temp\MozillaBuildSetup-2.1.0.exe' -f $env:SystemRoot) -ArgumentList '/S' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.MozillaBuildSetup-2.1.0.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.MozillaBuildSetup-2.1.0.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if ((Test-Path -Path ('{0}\mozilla-build\VERSION' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and ((Get-Content ('{0}\mozilla-build\VERSION' -f $env:SystemDrive)) -eq '2.1.0') -and (Test-Path -Path ('{0}\mozilla-build\msys\bin\sh.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
  Script ShPath {
    DependsOn = @('[Script]MozillaBuildInstall')
    GetScript = { @{ Result = ($env:PATH.Contains(('{0}\mozilla-build\msys\bin' -f $env:SystemDrive))) } }
    SetScript = {
      [Environment]::SetEnvironmentVariable('PATH', ('{0};{1}\mozilla-build\msys\bin' -f $env:PATH, $env:SystemDrive), 'Machine')
    }
    TestScript = { if ($env:PATH.Contains(('{0}\mozilla-build\msys\bin' -f $env:SystemDrive))) { $true } else { $false } }
  }
  Script AutoconfPath {
    DependsOn = @('[Script]MozillaBuildInstall')
    GetScript = { @{ Result = ($env:PATH.Contains(('{0}\mozilla-build\msys\local\bin' -f $env:SystemDrive))) } }
    SetScript = {
      [Environment]::SetEnvironmentVariable('PATH', ('{0};{1}\mozilla-build\msys\local\bin' -f $env:PATH, $env:SystemDrive), 'Machine')
    }
    TestScript = { if ($env:PATH.Contains(('{0}\mozilla-build\msys\local\bin' -f $env:SystemDrive))) { $true } else { $false } }
  }

  # todo: add 32 bit installer
  Script MercurialDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\mercurial-3.7.2-x64.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://bitbucket.org/tortoisehg/files/downloads/mercurial-3.7.2-x64.msi', ('{0}\Temp\mercurial-3.7.2-x64.msi' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\mercurial-3.7.2-x64.msi' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\mercurial-3.7.2-x64.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Package MercurialInstall {
    DependsOn = @('[Script]MercurialDownload', '[File]LogFolder')
    Name = 'Mercurial 3.7.2 (x64)'
    Path = ('{0}\Temp\mercurial-3.7.2-x64.msi' -f $env:SystemRoot)
    ProductId = 'CAED022C-BC65-447A-A821-060B09439984'
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.mercurial-3.7.2-x64.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }
  Script MercurialSymbolicLink {
    DependsOn = @('[Package]MercurialInstall', '[Script]MozillaBuildInstall')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\hg' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\mozilla-build' -f $env:SystemDrive) -Name 'hg' -Target ('{0}\Mercurial' -f $env:ProgramFiles)
      } else {
        & cmd @('/c', 'mklink', '/D', ('{0}\mozilla-build\hg' -f $env:SystemDrive), ('{0}\Mercurial' -f $env:ProgramFiles))
      }
    }
    TestScript = { (Test-Path -Path ('{0}\mozilla-build\hg' -f $env:SystemDrive) -ErrorAction SilentlyContinue) }
  }
  File MercurialCertFolder {
    DependsOn = '[Script]MercurialSymbolicLink'
    Type = 'Directory'
    DestinationPath = ('{0}\mozilla-build\hg\hgrc.d' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script MercurialConfigure {
    DependsOn = '[File]MercurialCertFolder'
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\mozilla-build\hg\hgrc.d\cacert.pem' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/Mercurial/mercurial.ini', ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive)
    }
    TestScript = { if ((Test-Path -Path ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\mozilla-build\hg\hgrc.d\cacert.pem' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
  File MozillaRepositoriesFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\builds\hg-shared' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script MozillaRepositoriesCache {
    DependsOn = @('[Script]MercurialConfigure', '[File]MozillaRepositoriesFolder')
    GetScript = { @{ Result = $false } }
    SetScript = {
      $repos = @{
        'https://hg.mozilla.org/build/mozharness' = ('{0}\builds\hg-shared\build\mozharness' -f $env:SystemDrive);
        'https://hg.mozilla.org/build/tools' = ('{0}\builds\hg-shared\build\tools' -f $env:SystemDrive);
        'https://hg.mozilla.org/integration/mozilla-inbound' = ('{0}\builds\hg-shared\integration\mozilla-inbound' -f $env:SystemDrive);
        'https://hg.mozilla.org/integration/fx-team' = ('{0}\builds\hg-shared\integration\fx-team' -f $env:SystemDrive);
        'https://hg.mozilla.org/mozilla-central' = ('{0}\builds\hg-shared\mozilla-central' -f $env:SystemDrive);
        ('{0}\builds\hg-shared\mozilla-central' -f $env:SystemDrive) = ('{0}\builds\hg-shared\try' -f $env:SystemDrive)
      }
      foreach ($repo in $repos.GetEnumerator()) {
        if (Test-Path -Path ('{0}\.hg' -f $repo.Value) -PathType Container -ErrorAction SilentlyContinue) {
          Start-Process ('{0}\mozilla-build\hg\hg.exe' -f $env:SystemDrive) -ArgumentList @('pull', '-R', $repo.Value) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.hg-pull-{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf)) -RedirectStandardError ('{0}\log\{1}.hg-pull-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf))
        } else {
          Start-Process ('{0}\mozilla-build\hg\hg.exe' -f $env:SystemDrive) -ArgumentList @('clone', '-U', $repo.Name, $repo.Value) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.hg-clone-{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf)) -RedirectStandardError ('{0}\log\{1}.hg-clone-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf))
        }
      }
    }
    TestScript = { $false }
  }

  Script PythonTwoSevenDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://www.python.org/ftp/python/2.7.11/python-2.7.11.amd64.msi', ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Package PythonTwoSevenInstall {
    DependsOn = @('[Script]PythonTwoSevenDownload', '[File]LogFolder')
    Name = 'Python 2.7.11 (64-bit)'
    Path = ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot)
    ProductId = '16E52445-1392-469F-9ADB-FC03AF00CD62'
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.python-2.7.11.amd64.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }
  Script PythonTwoSevenSymbolicLink {
    DependsOn = @('[Package]PythonTwoSevenInstall')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Python27\python2.7.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\Python27' -f $env:SystemDrive) -Name 'python2.7.exe' -Target ('{0}\Python27\python.exe' -f $env:SystemDrive)
      } else {
        & cmd @('/c', 'mklink', ('{0}\Python27\python2.7.exe' -f $env:SystemDrive), ('{0}\Python27\python.exe' -f $env:SystemDrive))
      }
    }
    TestScript = { if (Test-Path -Path ('{0}\Python27\python2.7.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script PythonTwoSevenPath {
    DependsOn = @('[Package]PythonTwoSevenInstall')
    GetScript = { @{ Result = ($env:PATH.Contains(('{0}\Python27;{0}\Python27\Scripts' -f $env:SystemDrive))) } }
    SetScript = {
      [Environment]::SetEnvironmentVariable('PATH', ('{0};{1}\Python27;{1}\Python27\Scripts' -f $env:PATH, $env:SystemDrive), 'Machine')
    }
    TestScript = { if ($env:PATH.Contains(('{0}\Python27;{0}\Python27\Scripts' -f $env:SystemDrive))) { $true } else { $false } }
  }
  File MozillaBuildPythonRemove {
    DependsOn = @('[Package]PythonTwoSevenInstall', '[Script]MozillaBuildInstall')
    Force = $true
    Type = 'Directory'
    DestinationPath = ('{0}\mozilla-build\python' -f $env:SystemDrive)
    Ensure = 'Absent'
  }
  Script MozillaBuildPythonSymbolicLink {
    DependsOn = @('[File]MozillaBuildPythonRemove')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\Python27' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\mozilla-build' -f $env:SystemDrive) -Name 'Python27' -Target ('{0}\Python27' -f $env:SystemDrive)
      } else {
        & cmd @('/c', 'mklink', '/D', ('{0}\mozilla-build\Python27' -f $env:SystemDrive), ('{0}\Python27' -f $env:SystemDrive))
      }
    }
    TestScript = { (Test-Path -Path ('{0}\mozilla-build\Python27' -f $env:SystemDrive) -ErrorAction SilentlyContinue) }
  }

  # ugly hacks to deal with mozharness configs hardcoded buildbot paths to virtualenv.py
  File MozillaBuildBuildBotVirtualEnv {
    DependsOn = @('[Script]MozillaBuildInstall')
    Type = 'Directory'
    DestinationPath = ('{0}\mozilla-build\buildbotve' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script MozillaBuildBuildBotVirtualEnvScript {
    DependsOn = @('[File]MozillaBuildBuildBotVirtualEnv')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://hg.mozilla.org/mozilla-central/raw-file/78babd21215d/python/virtualenv/virtualenv.py', ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive)
    }
    TestScript = { (Test-Path -Path ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) }
  }
  # end ugly hacks to deal with mozharness configs hardcoded buildbot paths to virtualenv.py

  Script PipUpgrade {
    DependsOn = @('[Package]PythonTwoSevenInstall', '[Script]PythonTwoSevenPath')
    GetScript = { @{ Result = $false } }
    SetScript = {
      Start-Process ('{0}\Python27\python.exe' -f $env:SystemDrive) -ArgumentList @('-m', 'pip', 'install', '--upgrade', 'pip') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.python-pip-upgrade.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.python-pip-upgrade.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { $false }
  }
  Script PythonVirtualEnvInstall {
    DependsOn = @('[Package]PythonTwoSevenInstall', '[Script]PipUpgrade')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Python27\Scripts\virtualenv.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\Python27\python.exe' -f $env:SystemDrive) -ArgumentList @('-m', 'pip', 'install', 'virtualenv') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.python-virtualenv-install.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.python-virtualenv-install.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (Test-Path -Path ('{0}\Python27\Scripts\virtualenv.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script PythonWheelInstall {
    DependsOn = @('[Package]PythonTwoSevenInstall', '[Script]PipUpgrade')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Python27\Scripts\wheel.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\Python27\python.exe' -f $env:SystemDrive) -ArgumentList @('-m', 'pip', 'install', 'wheel') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.python-wheel-install.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.python-wheel-install.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (Test-Path -Path ('{0}\Python27\Scripts\wheel.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script PythonPyWinDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\pypiwin32-219-cp27-none-win_amd64.whl' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://pypi.python.org/packages/cp27/p/pypiwin32/pypiwin32-219-cp27-none-win_amd64.whl#md5=d7bafcf3cce72c3ce9fdd633a262c335', ('{0}\Temp\pypiwin32-219-cp27-none-win_amd64.whl' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\pypiwin32-219-cp27-none-win_amd64.whl' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\pypiwin32-219-cp27-none-win_amd64.whl' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script PythonPyWinInstall {
    DependsOn = @('[Package]PythonTwoSevenInstall', '[Script]PipUpgrade', '[Script]PythonPyWinDownload')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Python27\Scripts\pywin32_postinstall.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\Python27\python.exe' -f $env:SystemDrive) -ArgumentList @('-m', 'pip', 'install', ('{0}\Temp\pypiwin32-219-cp27-none-win_amd64.whl' -f $env:SystemRoot)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.pypiwin32-219-cp27-none-win_amd64.whl.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.pypiwin32-219-cp27-none-win_amd64.whl.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Process ('{0}\Python27\python.exe' -f $env:SystemDrive) -ArgumentList @(('{0}\Python27\Scripts\pywin32_postinstall.py' -f $env:SystemDrive), '-install') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.pywin32_postinstall.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.pywin32_postinstall.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (Test-Path -Path ('{0}\Python27\Scripts\pywin32_postinstall.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script ToolToolInstall {
    DependsOn = @('[Package]PythonTwoSevenInstall', '[Script]PipUpgrade', '[Script]PythonPyWinDownload')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Python27\Scripts\pywin32_postinstall.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/mozilla/build-tooltool/master/tooltool.py', ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive)
    }
    TestScript = { if (Test-Path -Path ('{0}\Python27\Scripts\pywin32_postinstall.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
}