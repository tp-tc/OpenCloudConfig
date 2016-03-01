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

  #Chocolatey VisualStudioCommunity2013Install {
  #  Ensure = 'Present'
  #  Package = 'visualstudiocommunity2013'
  #  Version = '12.0.21005.1'
  #}
  #Script VisualStudio2013SymbolicLink {
  #  GetScript = { @{ Result = (Test-Path ('{0}\tools\vs2013' -f $env:SystemDrive)) } }
  #  SetScript = { New-Item -ItemType SymbolicLink -Name ('{0}\tools\vs2013' -f $env:SystemDrive) -Target ('{0}\Microsoft Visual Studio 12.0' -f ${env:ProgramFiles(x86)}) }
  #  TestScript = { (Test-Path ('{0}\tools\vs2013' -f $env:SystemDrive)) }
  #}

  Chocolatey VisualStudio2015CommunityInstall {
    Ensure = 'Present'
    Package = 'visualstudio2015community'
    Version = '14.0.24720.01'
  }
  Script VisualStudio2015SymbolicLink {
    GetScript = { @{ Result = (Test-Path ('{0}\tools\vs2015' -f $env:SystemDrive)) } }
    SetScript = { New-Item -ItemType SymbolicLink -Name ('{0}\tools\vs2015' -f $env:SystemDrive) -Target ('{0}\Microsoft Visual Studio 14.0' -f ${env:ProgramFiles(x86)}) }
    TestScript = { (Test-Path ('{0}\tools\vs2015' -f $env:SystemDrive)) }
  }

  Chocolatey WindowsSdkInstall {
    Ensure = 'Present'
    Package = 'windows-sdk-8.1'
    Version = '8.100.26654.0'
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
    SetScript = { New-Item -ItemType SymbolicLink -Name ('{0}\tools\rust' -f $env:SystemDrive) -Target ('{0}\Rust beta MSVC 1.7' -f $env:ProgramFiles) }
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
