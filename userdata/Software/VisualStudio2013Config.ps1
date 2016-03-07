<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration VisualStudio2013Config {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  Script VsCommunity2013Download {
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\Temp\vs_community_2013.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\Temp\VisualStudio2013-AdminDeployment.xml' -f $env:SystemRoot) -ErrorAction SilentlyContinue)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://download.microsoft.com/download/7/1/B/71BA74D8-B9A0-4E6C-9159-A8335D54437E/vs_community.exe', ('{0}\Temp\vs_community_2013.exe' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\vs_community_2013.exe' -f $env:SystemRoot)
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/VisualStudio2013/AdminDeployment.xml', ('{0}\Temp\VisualStudio2013-AdminDeployment.xml' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\VisualStudio2013-AdminDeployment.xml' -f $env:SystemRoot)
    }
    TestScript = { if ((Test-Path -Path ('{0}\Temp\vs_community_2013.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\Temp\VisualStudio2013-AdminDeployment.xml' -f $env:SystemRoot) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
  Script VsCommunity2013Install {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Microsoft Visual Studio 12.0\Common7\IDE\devenv.exe' -f @{$true=${env:ProgramFiles(x86)};$false=$env:ProgramFiles}[(Test-Path ${ProgramFiles(x86)})]) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\Temp\vs_community_2013.exe' -f $env:SystemRoot) -ArgumentList ('/Passive /NoRestart /AdminFile {0} /Log {1}' -f ('{0}\Temp\VisualStudio2013-AdminDeployment.xml' -f $env:SystemRoot), ('{0}\log\{1}.vs_community_2013.exe.install.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.vs_community_2013.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.vs_community_2013.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { (Test-Path -Path ('{0}\Microsoft Visual Studio 12.0\Common7\IDE\devenv.exe' -f @{$true=${env:ProgramFiles(x86)};$false=$env:ProgramFiles}[(Test-Path ${ProgramFiles(x86)})]) -ErrorAction SilentlyContinue) }
  }

  # tools folder required by mozilla build scripts
  File ToolsFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\tools' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script VisualStudio2013SymbolicLink {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\tools\vs2013' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\tools' -f $env:SystemDrive) -Name 'vs2013' -Target ('{0}\Microsoft Visual Studio 12.0' -f ${env:ProgramFiles(x86)})
      } else {
        & cmd @('/c', 'mklink', '/D', ('{0}\tools\vs2013' -f $env:SystemDrive), ('{0}\Microsoft Visual Studio 12.0' -f ${env:ProgramFiles(x86)}))
      }
    }
    TestScript = { (Test-Path -Path ('{0}\tools\vs2013' -f $env:SystemDrive) -ErrorAction SilentlyContinue) }
  }
}
