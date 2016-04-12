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
  
  #Script DirectXSdkDownload {
  #  GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
  #  SetScript = {
  #    (New-Object Net.WebClient).DownloadFile('http://download.microsoft.com/download/A/E/7/AE743F1F-632B-4809-87A9-AA1BB3458E31/DXSDK_Jun10.exe', ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot))
  #    Unblock-File -Path ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot)
  #  }
  #  TestScript = { if (Test-Path -Path ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  #}
  #Script DirectXSdkInstall {
  #  DependsOn = @('[Script]DirectXSdkDownload', '[File]LogFolder')
  #  GetScript = { @{ Result = (Test-Path -Path ('{0}\Microsoft DirectX SDK (June 2010)\system\uninstall\DXSDK_Jun10.exe' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) } }
  #  SetScript = {
  #    # https://blogs.msdn.microsoft.com/chuckw/2011/12/09/known-issue-directx-sdk-june-2010-setup-and-the-s1023-error/
  #    Start-Process 'MsiExec.exe' -ArgumentList '/passive /X{F0C3E5D1-1ADE-321E-8167-68EF0DE699A5}' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.vcredist2010x86.uninstall.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.vcredist2010x86.uninstall.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  #    Start-Process 'MsiExec.exe' -ArgumentList '/passive /X{1D8E6291-B0D5-35EC-8441-6616F567A0F7}' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.vcredist2010x64.uninstall.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.vcredist2010x64.uninstall.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  #    Start-Process ('{0}\Temp\DXSDK_Jun10.exe' -f $env:SystemRoot) -ArgumentList '/U' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.DXSDK_Jun10.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.DXSDK_Jun10.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  #  }
  #  TestScript = { if (Test-Path -Path ('{0}\Microsoft DirectX SDK (June 2010)\system\uninstall\DXSDK_Jun10.exe' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) { $true } else { $false } }
  #}
  
  #Script VCRedist2010Download {
  #  GetScript = { @{ Result = ((Test-Path -Path ('{0}\Temp\vcredist_x86.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\Temp\vcredist_x64.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue)) } }
  #  SetScript = {
  #    (New-Object Net.WebClient).DownloadFile('http://download.microsoft.com/download/C/6/D/C6D0FD4E-9E53-4897-9B91-836EBA2AACD3/vcredist_x86.exe', ('{0}\Temp\vcredist_x86.exe' -f $env:SystemRoot))
  #    Unblock-File -Path ('{0}\Temp\vcredist_x86.exe' -f $env:SystemRoot)
  #    (New-Object Net.WebClient).DownloadFile('http://download.microsoft.com/download/A/8/0/A80747C3-41BD-45DF-B505-E9710D2744E0/vcredist_x64.exe', ('{0}\Temp\vcredist_x64.exe' -f $env:SystemRoot))
  #    Unblock-File -Path ('{0}\Temp\vcredist_x64.exe' -f $env:SystemRoot)
  #  }
  #  TestScript = { if ((Test-Path -Path ('{0}\Temp\vcredist_x86.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\Temp\vcredist_x64.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  #}
  #Script VCRedist2010Install {
  #  DependsOn = @('[Script]VCRedist2010Download', '[File]LogFolder')
  #  GetScript = { @{ Result = $false } }
  #  SetScript = {
  #    Start-Process ('{0}\Temp\vcredist_x86.exe' -f $env:SystemRoot) -ArgumentList @('/Q') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.vcredist_x86.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.vcredist_x86.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  #    Start-Process ('{0}\Temp\vcredist_x64.exe' -f $env:SystemRoot) -ArgumentList @('/Q') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.vcredist_x64.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.vcredist_x64.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  #  }
  #  TestScript = { $false }
  #}
  
  #Script WindowsSdkDownload {
  #  GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\sdksetup.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
  #  SetScript = {
  #    (New-Object Net.WebClient).DownloadFile('http://download.microsoft.com/download/B/0/C/B0C80BA3-8AD6-4958-810B-6882485230B5/standalonesdk/sdksetup.exe', ('{0}\Temp\sdksetup.exe' -f $env:SystemRoot))
  #    Unblock-File -Path ('{0}\Temp\sdksetup.exe' -f $env:SystemRoot)
  #  }
  #  TestScript = { if (Test-Path -Path ('{0}\Temp\sdksetup.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  #}
  #Script WindowsSdkInstall {
  #  DependsOn = @('[Script]WindowsSdkDownload', '[File]LogFolder')
  #  GetScript = { @{ Result = (Test-Path -Path ('{0}\Windows Kits\8.1' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) } }
  #  SetScript = {
  #    Start-Process ('{0}\Temp\sdksetup.exe' -f $env:SystemRoot) -ArgumentList @('/Quiet', '/NoRestart', '/Log', ('{0}\log\{1}.sdksetup.exe.install.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.sdksetup.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.sdksetup.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  #  }
  #  TestScript = { if (Test-Path -Path ('{0}\Windows Kits\8.1' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) { $true } else { $false } }
  #}
  
  Script MozillaBuildDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\MozillaBuildSetup-2.2.0.exe' -f $env:SystemRoot)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://ftp.mozilla.org/pub/mozilla/libraries/win32/MozillaBuildSetup-2.2.0.exe', ('{0}\Temp\MozillaBuildSetup-2.2.0.exe' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\MozillaBuildSetup-2.2.0.exe' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\MozillaBuildSetup-2.2.0.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script MozillaBuildInstall {
    DependsOn = @('[Script]MozillaBuildDownload', '[File]LogFolder')
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\mozilla-build\VERSION' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and ((Get-Content ('{0}\mozilla-build\VERSION' -f $env:SystemDrive)) -eq '2.2.0') -and (Test-Path -Path ('{0}\mozilla-build\msys\bin\sh.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) } }
    SetScript = {
      Start-Process ('{0}\Temp\MozillaBuildSetup-2.2.0.exe' -f $env:SystemRoot) -ArgumentList '/S' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.MozillaBuildSetup-2.2.0.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.MozillaBuildSetup-2.2.0.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if ((Test-Path -Path ('{0}\mozilla-build\VERSION' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and ((Get-Content ('{0}\mozilla-build\VERSION' -f $env:SystemDrive)) -eq '2.2.0') -and (Test-Path -Path ('{0}\mozilla-build\msys\bin\sh.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }

  Script MercurialConfigure {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\python\Scripts\mercurial.ini' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/Mercurial/mercurial.ini', ('{0}\mozilla-build\python\Scripts\mercurial.ini' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\python\Scripts\mercurial.ini' -f $env:SystemDrive)
    }
    TestScript = { if (Test-Path -Path ('{0}\mozilla-build\python\Scripts\mercurial.ini' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
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
          Start-Process ('{0}\mozilla-build\python\Scripts\hg.exe' -f $env:SystemDrive) -ArgumentList @('pull', '-R', $repo.Value) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.hg-pull-{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf)) -RedirectStandardError ('{0}\log\{1}.hg-pull-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf))
        } else {
          Start-Process ('{0}\mozilla-build\python\Scripts\hg.exe' -f $env:SystemDrive) -ArgumentList @('clone', '-U', $repo.Name, $repo.Value) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.hg-clone-{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf)) -RedirectStandardError ('{0}\log\{1}.hg-clone-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf))
        }
      }
    }
    TestScript = { $false }
  }

  #Script PythonModules {
  #  DependsOn = @('[Package]PythonTwoSevenInstall')
  #  GetScript = { @{ Result = $false } }
  #  SetScript = {
  #    $modules = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/python-modules.json' -UseBasicParsing | ConvertFrom-Json
  #    foreach ($module in $modules) {
  #      Start-Process ('{0}\Python27\python.exe' -f $env:SystemDrive) -ArgumentList @('-m', 'pip', 'install', '--upgrade', ('{0}=={1}' -f $module.module, $module.version)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.python-pip-upgrade-{2}-{3}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $module.module, $module.version) -RedirectStandardError ('{0}\log\{1}.python-pip-upgrade-{2}-{3}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $module.module, $module.version)
  #    }
  #  }
  #  TestScript = { $false }
  #}
  Script ToolToolInstall {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/mozilla/build-tooltool/master/tooltool.py', ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive)
    }
    TestScript = { if (Test-Path -Path ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }

  # ugly hacks to deal with mozharness configs hardcoded buildbot paths to virtualenv.py
  Script MozillaBuildBuildBotVirtualEnvScript {
    DependsOn = @('[Script]MozillaBuildInstall')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\mozilla-build\python\python.exe' -f $env:SystemDrive) -ArgumentList @('-m', 'virtualenv', ('{0}\mozilla-build\buildbotve' -f $env:SystemDrive)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.python-virtualenv-buildbotve.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.python-virtualenv-buildbotve.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      (New-Object Net.WebClient).DownloadFile('https://hg.mozilla.org/mozilla-central/raw-file/78babd21215d/python/virtualenv/virtualenv.py', ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive)
      New-Item -ItemType Directory -Force -Path ('{0}\mozilla-build\buildbotve\virtualenv_support' -f $env:SystemDrive)
      $modules = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/python-modules.json' -UseBasicParsing | ConvertFrom-Json
      foreach ($module in $modules) {
        foreach ($wheel in $module.wheels){
          (New-Object Net.WebClient).DownloadFile($wheel, ('{0}\mozilla-build\buildbotve\virtualenv_support\{1}' -f $env:SystemDrive, [IO.Path]::GetFileName($wheel).Split('#')[0]))
        }
      }
    }
    TestScript = { if (Test-Path -Path ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  # end ugly hacks to deal with mozharness configs hardcoded buildbot paths to virtualenv.py

  #Script VCForPythonDownload {
  #  GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\VCForPython27.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
  #  SetScript = {
  #    (New-Object Net.WebClient).DownloadFile('https://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi', ('{0}\Temp\VCForPython27.msi' -f $env:SystemRoot))
  #    Unblock-File -Path ('{0}\Temp\VCForPython27.msi' -f $env:SystemRoot)
  #  }
  #  TestScript = { if (Test-Path -Path ('{0}\Temp\VCForPython27.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  #}
  #Package VCForPythonInstall {
  #  DependsOn = @('[Script]VCForPythonDownload', '[File]LogFolder')
  #  Name = 'Microsoft Visual C++ Compiler Package for Python 2.7'
  #  Path = ('{0}\Temp\VCForPython27.msi' -f $env:SystemRoot)
  #  ProductId = '692514A8-5484-45FC-B0AE-BE2DF7A75891'
  #  Ensure = 'Present'
  #  LogPath = ('{0}\log\{1}.VCForPython27.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  #}
}