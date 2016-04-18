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
      # MOZBUILDDIR, MOZILLABUILD
      if (Test-Path -Path ('{0}\mozilla-build' -f $env:SystemDrive) -ErrorAction SilentlyContinue) {
        $env:MOZBUILDDIR = ('{0}\mozilla-build' -f $env:SystemDrive)
        [Environment]::SetEnvironmentVariable('MOZBUILDDIR', $env:MOZBUILDDIR, 'Machine')
        $env:MOZILLABUILD = ('{0}\mozilla-build' -f $env:SystemDrive)
        [Environment]::SetEnvironmentVariable('MOZILLABUILD', $env:MOZILLABUILD, 'Machine')
      }
      # MOZ_TOOLS
      if (Test-Path -Path ('{0}\moztools-x64' -f $env:MOZILLABUILD) -ErrorAction SilentlyContinue) {
        $env:MOZ_TOOLS = ('{0}\moztools-x64' -f $env:MOZILLABUILD)
        [Environment]::SetEnvironmentVariable('MOZ_TOOLS', $env:INPUTRC, 'Machine')
      }
      # VCINSTALLDIR
      if (Test-Path -Path ('{0}\SysWOW64\config\systemprofile\AppData\Local\Programs\Common\Microsoft\Visual C++ for Python\9.0\VC' -f $env:SystemRoot) -ErrorAction SilentlyContinue) {
        $env:VCINSTALLDIR = ('{0}\SysWOW64\config\systemprofile\AppData\Local\Programs\Common\Microsoft\Visual C++ for Python\9.0\VC' -f $env:SystemRoot)
        [Environment]::SetEnvironmentVariable('VCINSTALLDIR', $env:VCINSTALLDIR, 'Machine')
      }
      # PATH
      if (Test-Path -Path ('{0}\python' -f $env:MOZILLABUILD) -ErrorAction SilentlyContinue) {
        $pythonPath = ('{0}\python' -f $env:MOZILLABUILD)
      } elseif (Test-Path -Path ('{0}\python27' -f $env:MOZILLABUILD) -ErrorAction SilentlyContinue) {
        $pythonPath = ('{0}\python27' -f $env:MOZILLABUILD)
      } elseif (Test-Path -Path ('{0}\Python27' -f $env:SystemDrive) -ErrorAction SilentlyContinue) {
        $pythonPath = ('{0}\Python27' -f $env:SystemDrive)
      }
      $env:PATH = (((($env:PATH -split ';') + @(
        ('{0}\mozilla-build\info-zip' -f $env:SystemDrive),
        ('{0}\mozilla-build\msys\bin' -f $env:SystemDrive),
        ('{0}\mozilla-build\msys\local\bin' -f $env:SystemDrive),
        ('{0}' -f $pythonPath),
        ('{0}\Scripts' -f $pythonPath),
        ('{0}\mozilla-build\wget' -f $env:SystemDrive),
        ('{0}\mozilla-build\yasm' -f $env:SystemDrive))) | select -Unique) -join ';')
      [Environment]::SetEnvironmentVariable('PATH', $env:PATH, 'Machine')     
    }
    TestScript = { $false }
  }
}
