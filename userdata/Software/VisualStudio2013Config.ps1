<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration VisualStudio2013Config {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Chocolatey VisualStudioCommunity2013Install {
    Ensure = 'Present'
    Package = 'visualstudiocommunity2013'
    Version = '12.0.21005.1'
  }
  # tools folder required by mozilla build scripts
  File ToolsFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\tools' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script VisualStudio2013SymbolicLink {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\tools\vs2013' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = { New-Item -ItemType SymbolicLink -Path ('{0}\tools' -f $env:SystemDrive) -Name 'vs2013' -Target ('{0}\Microsoft Visual Studio 12.0' -f ${env:ProgramFiles(x86)}) }
    TestScript = { (Test-Path -Path ('{0}\tools\vs2013' -f $env:SystemDrive)) }
  }
}
