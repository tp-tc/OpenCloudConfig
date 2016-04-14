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
      if (Test-Path -Path ('{0}\mozilla-build\python' -f $env:SystemDrive) -ErrorAction SilentlyContinue) {
        $pythonPath = ('{0}\mozilla-build\python' -f $env:SystemDrive)
      } elseif (Test-Path -Path ('{0}\mozilla-build\python27' -f $env:SystemDrive) -ErrorAction SilentlyContinue) {
        $pythonPath = ('{0}\mozilla-build\python27' -f $env:SystemDrive)
      } else {
        $pythonPath = ('{0}\Python27' -f $env:SystemDrive)
      }
      $env:PATH = (((($env:PATH -split ';') + @(
        ('{0}\mozilla-build\info-zip' -f $env:SystemDrive),
        ('{0}\mozilla-build\msys\bin' -f $env:SystemDrive),
        ('{0}\mozilla-build\msys\local\bin' -f $env:SystemDrive),
        ('{0}' -f $pythonPath),
        ('{0}\Scripts' -f $pythonPath),
        ('{0}\mozilla-build\yasm' -f $env:SystemDrive))) | select -Unique) -join ';')
      [Environment]::SetEnvironmentVariable('PATH', $env:PATH, 'Machine')
    }
    TestScript = { $false }
  }
}
