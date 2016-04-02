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

  Script HomeFolder {
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\home' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and ([bool]((Get-Item ('{0}\home' -f $env:SystemDrive) -Force -ea 0).Attributes -band [IO.FileAttributes]::ReparsePoint))) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\' -f $env:SystemDrive) -Name 'home' -Target ('{0}\Users' -f $env:SystemDrive)
      } else {
        & 'cmd' @('/c', 'mklink', '/D', ('{0}\home' -f $env:SystemDrive), ('{0}\Users' -f $env:SystemDrive))
      }
    }
    TestScript = { if ((Test-Path -Path ('{0}\home' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and ([bool]((Get-Item ('{0}\home' -f $env:SystemDrive) -Force -ea 0).Attributes -band [IO.FileAttributes]::ReparsePoint))) { $true } else { $false } }
  }
  File BuildsFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\builds' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  File BuildWorkspaceFolder {
    DependsOn = @('[Script]HomeFolder')
    Type = 'Directory'
    DestinationPath = ('{0}\home\worker\workspace' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script WindowsDesktopBuildScripts {
    DependsOn = @('[File]BuildWorkspaceFolder')
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\home\worker\workspace\checkout-sources.cmd' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\home\worker\workspace\buildprops.json' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/FirefoxBuildResources/checkout-sources.cmd', ('{0}\home\worker\workspace\checkout-sources.cmd' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\home\worker\workspace\checkout-sources.cmd' -f $env:SystemDrive)
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/FirefoxBuildResources/buildprops.json', ('{0}\home\worker\workspace\buildprops.json' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\home\worker\workspace\buildprops.json' -f $env:SystemDrive)
    }
    TestScript = { if ((Test-Path -Path ('{0}\home\worker\workspace\checkout-sources.cmd' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\home\worker\workspace\buildprops.json' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }

  Script GpgKeyImport {
    DependsOn = '[File]LogFolder'
    GetScript = { @{ Result = (((Test-Path -Path ('{0}\SysWOW64\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\SysWOW64\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot)).length -gt 0kb)) -or ((Test-Path -Path ('{0}\System32\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\System32\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot)).length -gt 0kb))) } }
    SetScript = {
      # todo: pipe key to gpg import, avoiding disk write
      Start-Process ('{0}\System32\diskperf.exe' -f $env:SystemRoot) -ArgumentList '-y' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.diskperf.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.diskperf.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      [IO.File]::WriteAllLines(('{0}\Temp\private.key' -f $env:SystemRoot), [regex]::matches((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data'), '(?s)-----BEGIN PGP PRIVATE KEY BLOCK-----.*-----END PGP PRIVATE KEY BLOCK-----').Value)
      Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('--allow-secret-key-import', '--import', ('{0}\Temp\private.key' -f $env:SystemRoot)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.gpg-import-key.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.gpg-import-key.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Remove-Item -Path ('{0}\Temp\private.key' -f $env:SystemRoot) -Force
    }
    TestScript = { if (((Test-Path -Path ('{0}\SysWOW64\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\SysWOW64\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot)).length -gt 0kb)) -or ((Test-Path -Path ('{0}\System32\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\System32\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot)).length -gt 0kb)))  { $true } else { $false } }
  }
  Script WindowsDesktopBuildSecrets {
    DependsOn = @('[File]LogFolder', '[File]BuildWorkspaceFolder', '[Script]GpgKeyImport')
    GetScript = { @{ Result = $false } }
    SetScript = {
      $files = @('crash-stats-api.token', 'gapi.data', 'google-oauth-api.key', 'mozilla-api.key', 'mozilla-desktop-geoloc-api.key', 'mozilla-fennec-geoloc-api.key', 'relengapi.tok')
      foreach ($file in $files) {
        (New-Object Net.WebClient).DownloadFile(('https://github.com/MozRelOps/OpenCloudConfig/blob/master/userdata/Configuration/FirefoxBuildResources/{0}.gpg?raw=true' -f $file), ('{0}\builds\{1}.gpg' -f $env:SystemDrive, $file))
        Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('-d', ('{0}\builds\{1}.gpg' -f $env:SystemDrive, $file)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\builds\{1}' -f $env:SystemDrive, $file) -RedirectStandardError ('{0}\log\{1}.gpg-decrypt-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $file)
        Remove-Item -Path ('{0}\builds\{1}.gpg' -f $env:SystemDrive, $file) -Force
        if ($PSVersionTable.PSVersion.Major -gt 4) {
          New-Item -ItemType SymbolicLink -Path ('{0}\home\worker\workspace' -f $env:SystemDrive) -Name $file -Target ('{0}\builds\{1}' -f $env:SystemDrive, $file)
        } else {
          & 'cmd' @('/c', 'mklink', ('{0}\home\worker\workspace\{1}' -f $env:SystemDrive, $file), ('{0}\builds\{1}' -f $env:SystemDrive, $file))
        }
      }
    }
    TestScript = { $false }
  }

  File ToolToolCacheFolder {
    DependsOn = @('[Script]HomeFolder')
    Type = 'Directory'
    DestinationPath = ('{0}\home\worker\tooltool-cache' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script ToolToolArtifactsCache {
    DependsOn = @('[File]ToolToolCacheFolder', '[Script]WindowsDesktopBuildSecrets')
    GetScript = { @{ Result = $false } }
    SetScript = {
      $files = @(
        'bb345b0e700ffab4d09436981f14b5de84da55a3f18a7f09ebc4364a4488acdeab8d46f447b12ac70f2da1444a68b8ce8b8675f0dae2ccf845e966d1df0f0869',
        'c4704dcc6774b9f3baaa9313192d26e36bfba2d4380d0518ee7cb89153d9adfe63f228f0ac29848f02948eb1ab7e6624ba71210f0121196d2b54ecebd640d1e6',
        '9c2c40637de27a0852aa1166f2a08159908b23f7a55855c933087c541461bbb2a1ec9e0522df0d2b9da2b2c343b673dbb5a2fa8d30216fe8acee1eb1383336ea',
        '0b71a936edf5bd70cf274aaa5d7abc8f77fe8e7b5593a208f805cc9436fac646b9c4f0b43c2b10de63ff3da671497d35536077ecbc72dba7f8159a38b580f831',
        '0379fd087705f54aeb335449e6c623cd550b656d7110acafd1e5b315e1fc9272b7cdd1e37f99d575b16ecba4e8e4fe3af965967a3944c023b83caf68fa684888'
      )
      $webClient = New-Object Net.WebClient
      $webClient.Headers.Add('Authorization', ('Bearer {0}' -f [IO.File]::ReadAllText(('{0}\builds\relengapi.tok' -f $env:SystemDrive))))
      foreach ($file in $files) {
        $webClient.DownloadFile(('https://api.pub.build.mozilla.org/tooltool/sha512/{0}' -f $file), ('{0}\home\worker\tooltool-cache\{1}' -f $env:SystemDrive, $file))
      }
    }
    TestScript = { $false }
  }
}
