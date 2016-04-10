<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration EnvironmentConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Script Path {
    GetScript = { @{ Result = $false } }
    SetScript = {
      $env:PATH = (((($env:PATH -split ';') + @(
        ('{0}\mozilla-build\msys\bin' -f $env:SystemDrive),
        ('{0}\mozilla-build\msys\local\bin' -f $env:SystemDrive),
        ('{0}\mozilla-build\hg' -f $env:SystemDrive),
        ('{0}\mozilla-build\unzip\bin' -f $env:SystemDrive),
        ('{0}\mozilla-build\yasm' -f $env:SystemDrive),
        ('{0}\Python27' -f $env:SystemDrive),
        ('{0}\Python27\Scripts' -f $env:SystemDrive))) | select -Unique) -join ';')
      [Environment]::SetEnvironmentVariable('PATH', $env:PATH, 'Machine')
    }
    TestScript = { $false }
  }
}
