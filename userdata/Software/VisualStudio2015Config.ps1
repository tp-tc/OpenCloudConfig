<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration VisualStudio2015Config {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Chocolatey VisualStudio2015CommunityInstall {
    Ensure = 'Present'
    Package = 'visualstudio2015community'
    Version = '14.0.24720.01'
  }
  # tools folder required by mozilla build scripts
  File ToolsFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\tools' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script VisualStudio2015SymbolicLink {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\tools\vs2015' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\tools' -f $env:SystemDrive) -Name 'vs2015' -Target ('{0}\Microsoft Visual Studio 14.0' -f ${env:ProgramFiles(x86)})
      } else {
        & cmd @('/c', 'mklink', '/D', ('{0}\tools\vs2015' -f $env:SystemDrive), ('{0}\Microsoft Visual Studio 14.0' -f ${env:ProgramFiles(x86)}))
      }
    }
    TestScript = { (Test-Path -Path ('{0}\tools\vs2015' -f $env:SystemDrive)) }
  }
}
