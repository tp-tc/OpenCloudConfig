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
  Script BuildWorkspacePermissions {
    DependsOn = @('[File]BuildWorkspaceFolder')
    GetScript = { @{ Result = $false } }
    SetScript = {
      #todo: change 'Everyone' to whatever group the taskcluster worker users are being added to.
      Start-Process ('icacls' -f ${env:ProgramFiles(x86)}) -ArgumentList @(('{0}\Users\worker' -f $env:SystemDrive), '/grant', 'Everyone:(OI)(CI)F', '/inheritance:r') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.grant-worker-access.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.grant-worker-access.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { $false }
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
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\builds\*.tok' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (-not (Compare-Object -ReferenceObject (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/releng-secrets.json' -UseBasicParsing | ConvertFrom-Json) -DifferenceObject (Get-ChildItem -Path ('{0}\builds' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer } | % { $_.Name })))) } }
    SetScript = {
      $files = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/releng-secrets.json' -UseBasicParsing | ConvertFrom-Json
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
    TestScript = { if ((Test-Path -Path ('{0}\builds\*.tok' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (-not (Compare-Object -ReferenceObject (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/releng-secrets.json' -UseBasicParsing | ConvertFrom-Json) -DifferenceObject (Get-ChildItem -Path ('{0}\builds' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer } | % { $_.Name })))) { $true } else { $false } }
  }

  File ToolToolCacheFolder {
    DependsOn = @('[Script]HomeFolder')
    Type = 'Directory'
    DestinationPath = ('{0}\home\worker\tooltool-cache' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script ToolToolArtifactsCache {
    DependsOn = @('[File]ToolToolCacheFolder', '[Script]WindowsDesktopBuildSecrets')
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\home\worker\tooltool-cache\*' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (-not (Compare-Object -ReferenceObject (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/tooltool-artifacts.json' -UseBasicParsing | ConvertFrom-Json) -DifferenceObject (Get-ChildItem -Path ('{0}\home\worker\tooltool-cache' -f $env:SystemDrive) | % { $_.Name })))) } }
    SetScript = {
      $files = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/tooltool-artifacts.json' -UseBasicParsing | ConvertFrom-Json
      $webClient = New-Object Net.WebClient
      $webClient.Headers.Add('Authorization', ('Bearer {0}' -f [IO.File]::ReadAllText(('{0}\builds\relengapi.tok' -f $env:SystemDrive))))
      foreach ($file in $files) {
        $webClient.DownloadFile(('https://api.pub.build.mozilla.org/tooltool/sha512/{0}' -f $file), ('{0}\home\worker\tooltool-cache\{1}' -f $env:SystemDrive, $file))
      }
    }
    TestScript = { if ((Test-Path -Path ('{0}\home\worker\tooltool-cache\*' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (-not (Compare-Object -ReferenceObject (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/tooltool-artifacts.json' -UseBasicParsing | ConvertFrom-Json) -DifferenceObject (Get-ChildItem -Path ('{0}\home\worker\tooltool-cache' -f $env:SystemDrive) | % { $_.Name })))) { $true } else { $false } }
  }

  File MozillaRepositoriesFolder {
    DependsOn = @('[File]BuildsFolder')
    Type = 'Directory'
    DestinationPath = ('{0}\builds\hg-shared' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script MozillaRepositoriesCache {
    DependsOn = @('[Script]MercurialConfigure', '[File]MozillaRepositoriesFolder')
    GetScript = { @{ Result = $false } }
    SetScript = {
      $repos = @{
        'https://hg.mozilla.org/build/mozharness' = ('{0}\builds\hg-shared\build\mozharness' -f $env:SystemDrive);
        'https://hg.mozilla.org/build/tools' = ('{0}\builds\hg-shared\build\tools' -f $env:SystemDrive);
        'https://hg.mozilla.org/integration/mozilla-inbound' = ('{0}\builds\hg-shared\integration\mozilla-inbound' -f $env:SystemDrive);
        'https://hg.mozilla.org/integration/fx-team' = ('{0}\builds\hg-shared\integration\fx-team' -f $env:SystemDrive);
        'https://hg.mozilla.org/mozilla-central' = ('{0}\builds\hg-shared\mozilla-central' -f $env:SystemDrive);
        ('{0}\builds\hg-shared\mozilla-central' -f $env:SystemDrive) = ('{0}\builds\hg-shared\try' -f $env:SystemDrive)
      }
      foreach ($repo in $repos.GetEnumerator()) {
        if (Test-Path -Path ('{0}\.hg' -f $repo.Value) -PathType Container -ErrorAction SilentlyContinue) {
          Start-Process ('{0}\mozilla-build\python\Scripts\hg.exe' -f $env:SystemDrive) -ArgumentList @('pull', '-R', $repo.Value) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.hg-pull-{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf)) -RedirectStandardError ('{0}\log\{1}.hg-pull-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf))
        } else {
          Start-Process ('{0}\mozilla-build\python\Scripts\hg.exe' -f $env:SystemDrive) -ArgumentList @('clone', '-U', $repo.Name, $repo.Value) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.hg-clone-{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf)) -RedirectStandardError ('{0}\log\{1}.hg-clone-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf))
        }
      }
    }
    TestScript = { $false }
  }
}
