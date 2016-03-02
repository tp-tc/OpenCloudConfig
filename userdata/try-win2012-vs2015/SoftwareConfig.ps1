# SoftwareConfig downloads and installs required software
Configuration SoftwareConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  Chocolatey SublimeText3Install {
    Ensure = 'Present'
    Package = 'sublimetext3'
    Version = '3.0.0.3103'
  }
  Chocolatey SublimeText3PackageControlInstall {
    Ensure = 'Present'
    Package = 'sublimetext3.packagecontrol'
    Version = '2.0.0.20140915'
  }

  # log folder for installation logs
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }

  # tools folder required by mozilla build scripts
  File ToolsFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\tools' -f $env:SystemDrive)
    Ensure = 'Present'
  }

  Chocolatey VisualStudio2015CommunityInstall {
    Ensure = 'Present'
    Package = 'visualstudio2015community'
    Version = '14.0.24720.01'
  }
  Script VisualStudio2015SymbolicLink {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\tools\vs2015' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = { New-Item -ItemType SymbolicLink -Path ('{0}\tools' -f $env:SystemDrive) -Name 'vs2015' -Target ('{0}\Microsoft Visual Studio 14.0' -f ${env:ProgramFiles(x86)}) }
    TestScript = { (Test-Path -Path ('{0}\tools\vs2015' -f $env:SystemDrive)) }
  }
  
  Script DirectXSdkDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\DXSDK_Jun10.exe' -f $env:Temp) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://download.microsoft.com/download/A/E/7/AE743F1F-632B-4809-87A9-AA1BB3458E31/DXSDK_Jun10.exe', ('{0}\DXSDK_Jun10.exe' -f $env:Temp))
      Unblock-File -Path ('{0}\DXSDK_Jun10.exe' -f $env:Temp)
    }
    TestScript = { if (Test-Path -Path ('{0}\DXSDK_Jun10.exe' -f $env:Temp) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script DirectXSdkInstall {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Microsoft DirectX SDK (June 2010)\system\uninstall\DXSDK_Jun10.exe' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) } }
    SetScript = {
      # https://blogs.msdn.microsoft.com/chuckw/2011/12/09/known-issue-directx-sdk-june-2010-setup-and-the-s1023-error/
      Start-Process 'MsiExec.exe' -ArgumentList '/passive /X{F0C3E5D1-1ADE-321E-8167-68EF0DE699A5}' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.vcredist2010x86.uninstall.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.vcredist2010x86.uninstall.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Process 'MsiExec.exe' -ArgumentList '/passive /X{1D8E6291-B0D5-35EC-8441-6616F567A0F7}' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.vcredist2010x64.uninstall.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.vcredist2010x64.uninstall.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Process ('{0}\DXSDK_Jun10.exe' -f $env:Temp) -ArgumentList '/U' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.DXSDK_Jun10.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.DXSDK_Jun10.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
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

  Script PSToolsDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\PSTools.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://download.sysinternals.com/files/PSTools.zip', ('{0}\Temp\PSTools.zip' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\PSTools.zip' -f $env:SystemRoot)
    }
    TestScript = { if ((Test-Path -Path ('{0}\Temp\PSTools.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
  Archive PSToolsExtract {
    Path = ('{0}\Temp\PSTools.zip' -f $env:SystemRoot)
    Destination = ('{0}\PSTools' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  
  Script NssmDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://www.nssm.cc/release/nssm-2.24.zip', ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot)
    }
    TestScript = { if ((Test-Path -Path ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
  Archive NssmExtract {
    Path = ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot)
    Destination = ('{0}\' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  
  File GenericWorkerFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\generic-worker' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script GenericWorkerDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } } # todo: version check
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://github.com/taskcluster/generic-worker/releases/download/v1.0.11/generic-worker-windows-amd64.exe', ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive)
    }
    TestScript = { if (Test-Path -Path ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } } # todo: version check
  }
  Script GenericWorkerInstall {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } } # todo: version check
    SetScript = {
      Start-Process ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive) -ArgumentList ('install --config {0}\generic-worker\generic-worker.config' -f $env:SystemDrive) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.generic-worker-windows-amd64.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.generic-worker-windows-amd64.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (Test-Path -Path ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } } # todo: version check
  }

  Package RustInstall {
    Name = 'Rust beta 1.7 (MSVC 64-bit)'
    Path = 'https://static.rust-lang.org/dist/rust-beta-x86_64-pc-windows-msvc.msi'
    ProductId = '2B9726D5-BA12-44AF-B083-178CE2E08DD1'
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.rust-beta-x86_64-pc-windows-msvc.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }
  Script RustSymbolicLink {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\tools\rust' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = { New-Item -ItemType SymbolicLink -Path ('{0}\tools' -f $env:SystemDrive) -Name 'rust' -Target ('{0}\Rust beta MSVC 1.7' -f $env:ProgramFiles) }
    TestScript = { (Test-Path -Path ('{0}\tools\rust' -f $env:SystemDrive) -ErrorAction SilentlyContinue) }
  }
  
  Script MozillaBuildDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\MozillaBuildSetup-2.1.0.exe' -f $env:Temp)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://ftp.mozilla.org/pub/mozilla/libraries/win32/MozillaBuildSetup-2.1.0.exe', ('{0}\MozillaBuildSetup-2.1.0.exe' -f $env:Temp))
      Unblock-File -Path ('{0}\MozillaBuildSetup-2.1.0.exe' -f $env:Temp)
    }
    TestScript = { if (Test-Path -Path ('{0}\MozillaBuildSetup-2.1.0.exe' -f $env:Temp) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script MozillaBuildInstall {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\VERSION' -f $env:SystemDrive)) } }
    SetScript = {
      Start-Process ('{0}\MozillaBuildSetup-2.1.0.exe' -f $env:Temp) -ArgumentList '/S' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.MozillaBuildSetup-2.1.0.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.MozillaBuildSetup-2.1.0.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { ((Test-Path -Path ('{0}\mozilla-build\VERSION' -f $env:SystemDrive)) -and ((Get-Content ('{0}\mozilla-build\VERSION' -f $env:SystemDrive)) -eq '2.1.0')) }
  }

  Script CygWinDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://www.cygwin.com/setup-x86_64.exe', ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp))
      Unblock-File -Path ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp)
    }
    TestScript = { if (Test-Path -Path ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script CygWinInstall {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\cygwin\bin\cygrunsrv.exe' -f $env:SystemDrive)) } }
    SetScript = {
      Start-Process ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp) -ArgumentList ('--quiet-mode --wait --root {0}\cygwin --site http://cygwin.mirror.constant.com --packages openssh,vim,curl,tar,wget,zip,unzip,diffutils,bzr' -f $env:SystemDrive) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.MozillaBuildSetup-2.1.0.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.MozillaBuildSetup-2.1.0.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { (Test-Path -Path ('{0}\cygwin\bin\cygrunsrv.exe' -f $env:SystemDrive)) }
  }
  Script SshInboundFirewallEnable {
    GetScript = { @{ Result = (Get-NetFirewallRule -DisplayName 'Allow SSH inbound' -ErrorAction SilentlyContinue) } }
    SetScript = { New-NetFirewallRule -DisplayName 'Allow SSH inbound' -Direction Inbound -LocalPort 22 -Protocol TCP -Action Allow }
    TestScript = { if (Get-NetFirewallRule -DisplayName 'Allow SSH inbound' -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script SshdServiceInstall {
    GetScript = { @{ Result = (Get-Service 'sshd' -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\cygwin\bin\bash.exe' -f $env:SystemDrive) -ArgumentList ("--login -c `"ssh-host-config -y -c 'ntsec mintty' -u 'sshd' -w '{0}'`"" -f [Guid]::NewGuid().ToString().Substring(0, 10)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.ssh-host-config.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.ssh-host-config.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (Get-Service 'sshd' -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
}
