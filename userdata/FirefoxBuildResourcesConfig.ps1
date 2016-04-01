<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration FirefoxBuildResourcesConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  # log folder for installation logs
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }

  File BuildWorkspaceFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\home\worker\workspace' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script WindowsDesktopBuildScripts {
    DependsOn = @('[File]BuildWorkspaceFolder')
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\home\worker\workspace\checkout-sources.cmd' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\home\worker\workspace\buildprops.json' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/TaskCluster/checkout-sources.cmd', ('{0}\home\worker\workspace\checkout-sources.cmd' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\home\worker\workspace\checkout-sources.cmd' -f $env:SystemDrive)
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/TaskCluster/buildprops.json', ('{0}\home\worker\workspace\buildprops.json' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\home\worker\workspace\buildprops.json' -f $env:SystemDrive)
    }
    TestScript = { if ((Test-Path -Path ('{0}\home\worker\workspace\checkout-sources.cmd' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\home\worker\workspace\buildprops.json' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
  Script WindowsDesktopBuildSecrets {
    DependsOn = @('[File]LogFolder', '[File]BuildWorkspaceFolder')
    GetScript = { @{ Result = $false } }
    SetScript = {
      $files = @('crash-stats-api.token', 'gapi.data', 'google-oauth-api.key', 'mozilla-api.key', 'mozilla-desktop-geoloc-api.key', 'mozilla-fennec-geoloc-api.key', 'relengapi.tok')
      for ($file in $files) {
        (New-Object Net.WebClient).DownloadFile(('https://github.com/MozRelOps/OpenCloudConfig/blob/master/userdata/Configuration/FirefoxBuildResources/{0}.gpg?raw=true' -f $file), ('{0}\home\worker\workspace\{1}.gpg' -f $env:SystemDrive, $file))
        Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('-d', ('{0}\home\worker\workspace\{1}.gpg' -f $env:SystemDrive, $file)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\home\worker\workspace\{1}' -f $env:SystemDrive, $file) -RedirectStandardError ('{0}\log\{1}.gpg-decrypt-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), , $file)
        Remove-Item -Path ('{0}\home\worker\workspace\{1}.gpg' -f $env:SystemDrive, $file) -Force
      }
    }
    TestScript = { $false }
  }
}
