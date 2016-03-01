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

  Chocolatey VisualStudioCommunity2013Install {
    Ensure = 'Present'
    Package = 'visualstudiocommunity2013'
    Version = '12.0.21005.1'
  }
  Script VisualStudio2013SymbolicLink {
    GetScript = { @{ Result = (Test-Path ('{0}\tools\vs2013' -f $env:SystemDrive)) } }
    SetScript = { New-Item -ItemType SymbolicLink -Name ('{0}\tools\vs2013' -f $env:SystemDrive) -Target ('{0}\Microsoft Visual Studio 12.0' -f ${env:ProgramFiles(x86)}) }
    TestScript = { (Test-Path ('{0}\tools\vs2013' -f $env:SystemDrive)) }
  }

  Chocolatey WindowsSdkInstall {
    Ensure = 'Present'
    Package = 'windows-sdk-8.1'
    Version = '8.100.26654.0'
  }

  Package DirectXSdkInstall {
    Name = 'DXSDK_Jun10'
    Path = 'http://download.microsoft.com/download/A/E/7/AE743F1F-632B-4809-87A9-AA1BB3458E31/DXSDK_Jun10.exe'
    ProductId = ''
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.DXSDK_Jun10.exe.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }
  
  Archive PSToolsInstall {
    Path = 'https://download.sysinternals.com/files/PSTools.zip'
    Destination = ('{0}\PSTools' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  
  Archive NssmInstall {
    Path = 'http://www.nssm.cc/release/nssm-2.24.zip'
    Destination = ('{0}\' -f $env:SystemDrive)
    Ensure = 'Present'
  }

  Package GenericWorkerInstall {
    Name = 'TaskCluster Generic Worker'
    Path = 'https://github.com/taskcluster/generic-worker/releases/download/v1.0.11/generic-worker-windows-amd64.exe'
    ProductId = ''
    Arguments = ('install --config {0}\\generic-worker\\generic-worker.config' -f $env:SystemDrive)
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.generic-worker-windows-amd64.exe.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }

  Package RustInstall {
    Name = 'Rust beta 1.7 (MSVC 64-bit)'
    Path = 'https://static.rust-lang.org/dist/rust-beta-x86_64-pc-windows-msvc.msi'
    ProductId = '2B9726D5-BA12-44AF-B083-178CE2E08DD1'
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.rust-beta-x86_64-pc-windows-msvc.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }
  Script RustSymbolicLink {
    GetScript = { @{ Result = (Test-Path ('{0}\tools\rust' -f $env:SystemDrive)) } }
    SetScript = { New-Item -ItemType SymbolicLink -Path ('{0}\tools' -f $env:SystemDrive) -Name 'rust' -Target ('{0}\Rust beta MSVC 1.7' -f $env:ProgramFiles) }
    TestScript = { (Test-Path ('{0}\tools\rust' -f $env:SystemDrive)) }
  }

  Package MozillaBuildInstall {
    Name = 'Mozilla Build'
    Path = 'http://ftp.mozilla.org/pub/mozilla/libraries/win32/MozillaBuildSetup-2.1.0.exe'
    ProductId = ''
    Arguments = '/S'
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.MozillaBuildSetup-2.1.0.exe.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }
}
