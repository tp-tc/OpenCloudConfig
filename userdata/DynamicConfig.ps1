<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

Configuration DynamicConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  $hostname = ((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id'))
  Script SetHostname {
    GetScript = "@{ Script = SetHostname }"
    SetScript = {
      if ((-not ([string]::IsNullOrWhiteSpace($using:hostname))) -and (-not ([System.Net.Dns]::GetHostName() -ieq $using:hostname))) {
        [Environment]::SetEnvironmentVariable('COMPUTERNAME', $using:hostname, 'Machine')
        $env:COMPUTERNAME = $using:hostname
        (Get-WmiObject Win32_ComputerSystem).Rename($using:hostname)
        [Environment]::SetEnvironmentVariable('DscRebootRequired', 'true', 'Process')
      }
    }
    TestScript = { return (([string]::IsNullOrWhiteSpace($using:hostname)) -or ([System.Net.Dns]::GetHostName() -ieq $using:hostname)) }
  }

  Script RemovePageFiles {
    GetScript = "@{ Script = RemovePageFiles }"
    SetScript = {
      if ((Get-WmiObject Win32_ComputerSystem).AutomaticManagedPagefile -or @(Get-WmiObject Win32_PageFileSetting).length) {
        $sys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
        $sys.AutomaticManagedPagefile = $False
        $sys.Put()
        Get-WmiObject Win32_PageFileSetting -EnableAllPrivileges | % { $_.Delete() }
        Get-ChildItem -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches' | % {
          Set-ItemProperty -path $_.Name.Replace('HKEY_LOCAL_MACHINE', 'HKLM:') -name StateFlags0012 -type DWORD -Value 2
        }
        [Environment]::SetEnvironmentVariable('DscRebootRequired', 'true', 'Process')
      }
    }
    TestScript = { return ((-not ((Get-WmiObject Win32_ComputerSystem).AutomaticManagedPagefile)) -and (@(Get-WmiObject Win32_PageFileSetting).length -eq 0)) }
  }

  Script GpgKeyImport {
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
  File BuildsFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\builds' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script WindowsDesktopBuildSecrets {
    DependsOn = @('[Script]GpgKeyImport', '[File]BuildsFolder')
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
  

  $supportingModules = @(
    'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/OCC-Validate.psm1'
  )
  Script InstallSupportingModules {
    GetScript = "@{ Script = InstallSupportingModules }"
    SetScript = {
      $modulesPath = ('{0}\Modules' -f $pshome)
      foreach ($url in $using:supportingModules) {
        $filename = [IO.Path]::GetFileName($url)
        $moduleName = [IO.Path]::GetFileNameWithoutExtension($filename)
        $modulePath = ('{0}\{1}' -f $modulesPath, $moduleName)
        if (Test-Path -Path $modulePath -ErrorAction SilentlyContinue) {
          Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
          Remove-Item -path $modulePath -recurse -force
        }
        New-Item -ItemType Directory -Force -Path $modulePath
        (New-Object Net.WebClient).DownloadFile(('{0}?{1}' -f $url, [Guid]::NewGuid()), ('{0}\{1}' -f $modulePath, $filename))
        Unblock-File -Path ('{0}\{1}' -f $modulePath, $filename)
        Import-Module -Name $moduleName
      }
    }
    TestScript = { return $false }
  }

  switch -wildcard ((Get-WmiObject -class Win32_OperatingSystem).Caption) {
    'Microsoft Windows Server 2012*' {
      $manifest = (Invoke-WebRequest -Uri ('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/win2012.json?{0}' -f [Guid]::NewGuid()) -UseBasicParsing | ConvertFrom-Json)
    }
    'Microsoft Windows Server 2008*' {
      $manifest = (Invoke-WebRequest -Uri ('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/win2008.json?{0}' -f [Guid]::NewGuid()) -UseBasicParsing | ConvertFrom-Json)
    }
    default {
      $manifest = ('{"Items":[{"ComponentType":"DirectoryCreate","Path":"$env:SystemDrive\\log"}]}' | ConvertFrom-Json)
    }
  }
  # this hashtable maps json manifest component types to DSC component types for dependency mapping
  $componentMap = @{
    'DirectoryCreate' = 'File';
    'DirectoryDelete' = 'Script';
    'DirectoryCopy' = 'File';
    'CommandRun' = 'Script';
    'FileDownload' = 'Script';
    'ChecksumFileDownload' = 'Script';
    'SymbolicLink' = 'Script';
    'ExeInstall' = 'Script';
    'MsiInstall' = 'Package';
    'WindowsFeatureInstall' = 'WindowsFeature';
    'ZipInstall' = 'Archive';
    'ServiceControl' = 'Service';
    'EnvironmentVariableSet' = 'Script';
    'EnvironmentVariableUniqueAppend' = 'Script';
    'EnvironmentVariableUniquePrepend' = 'Script';
    'RegistryKeySet' = 'Registry';
    'RegistryValueSet' = 'Registry';
    'FirewallRule' = 'Script'
  }
  Log Manifest {
    Message = ('Manifest: {0}' -f $manifest)
  }
  foreach ($item in $manifest.Components) {
    switch ($item.ComponentType) {
      'DirectoryCreate' {
        File ('DirectoryCreate-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          Ensure = 'Present'
          Type = 'Directory'
          DestinationPath = $($item.Path)
        }
        Log ('Log-DirectoryCreate-{0}' -f $item.ComponentName) {
          DependsOn = ('[File]DirectoryCreate-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'DirectoryDelete' {
        Script ('DirectoryDelete-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ DirectoryDelete = $($item.Path) }"
          SetScript = {
            try {
              Remove-Item $($using:item.Path) -Confirm:$false -force
            } catch {
              Start-Process 'icacls' -ArgumentList @($($using:item.Path), '/grant', ('{0}:(OI)(CI)F' -f $env:Username), '/inheritance:r') -Wait -NoNewWindow -PassThru | Out-Null
              Remove-Item $($using:item.Path) -Confirm:$false -force
              # todo: another try catch block with move to recycle bin, empty recycle bin
            }
          }
          TestScript = { (-not (Test-Path -Path $($using:item.Path) -ErrorAction SilentlyContinue)) }
        }
        Log ('Log-DirectoryDelete-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]DirectoryDelete-{0}' -f $($item.Path).Replace(':', '').Replace('\', '_'))
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'DirectoryCopy' {
        File ('DirectoryCopy-{0}' -f $item.ComponentName) {
          Ensure = 'Present'
          Type = 'Directory'
          Recurse = $true
          SourcePath = $item.Source
          DestinationPath = $item.Target
        }
        Log ('Log-DirectoryCopy-{0}' -f $item.ComponentName) {
          DependsOn = ('[File]DirectoryCopy-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'CommandRun' {
        Script ('CommandRun-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ CommandRun = $item.ComponentName }"
          SetScript = {
            Start-Process $($using:item.Command) -ArgumentList @($using:item.Arguments | % { $($_) }) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}-{2}-stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:item.ComponentName) -RedirectStandardError ('{0}\log\{1}-{2}-stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:item.ComponentName)
          }
          TestScript = { return Validate-All -validations $using:item.Validate }
        }
        Log ('Log-CommandRun-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]CommandRun-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'FileDownload' {
        Script ('FileDownload-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ FileDownload = $item.ComponentName }"
          SetScript = {
            try {
              (New-Object Net.WebClient).DownloadFile($using:item.Source, $using:item.Target)
            } catch {
              # handle redirects (eg: sourceforge)
              Invoke-WebRequest -Uri $using:item.Source -OutFile $using:item.Target -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
            }
            Unblock-File -Path $using:item.Target
          }
          TestScript = { return (Test-Path -Path $using:item.Target -ErrorAction SilentlyContinue) }
        }
        Log ('Log-FileDownload-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]FileDownload-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'ChecksumFileDownload' {
        Script ('ChecksumFileDownload-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ FileDownload = $item.ComponentName }"
          SetScript = {
            try {
              (New-Object Net.WebClient).DownloadFile($using:item.Source, ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName($using:item.Target)))
            } catch {
              # handle redirects (eg: sourceforge)
              Invoke-WebRequest -Uri $using:item.Source -OutFile ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName($using:item.Target)) -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
            }
            Unblock-File -Path ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName($using:item.Target))
          }
          TestScript = { return (Test-Path -Path ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName($using:item.Target)) -ErrorAction SilentlyContinue) }
        }
        File ('ChecksumFileCopy-{0}' -f $item.ComponentName) {
          DependsOn = ('[File]ChecksumFileDownload-{0}' -f $item.ComponentName)
          Type = 'File'
          Checksum = 'SHA-1'
          SourcePath = ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName($item.Target))
          DestinationPath = $item.Target
          Ensure = 'Present'
          Force = $true
        }
        Log ('Log-ChecksumFileDownload-{0}' -f $item.ComponentName) {
          DependsOn = ('[File]ChecksumFileCopy-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'SymbolicLink' {
        Script ('SymbolicLink-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ SymbolicLink = $item.ComponentName }"
          SetScript = {
            if (Test-Path -Path $using:item.Target -PathType Container -ErrorAction SilentlyContinue) {
              & 'cmd' @('/c', 'mklink', '/D', $using:item.Link, $using:item.Target)
            } elseif (Test-Path -Path $using:item.Target -PathType Leaf -ErrorAction SilentlyContinue) {
              & 'cmd' @('/c', 'mklink', $using:item.Link, $using:item.Target)
            }
          }
          TestScript = { return ((Test-Path -Path $using:item.Link -ErrorAction SilentlyContinue) -and ((Get-Item $using:item.Link).Attributes.ToString() -match "ReparsePoint")) }
        }
        Log ('Log-SymbolicLink-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]SymbolicLink-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'ExeInstall' {
        Script ('ExeDownload-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ ExeDownload = $item.ComponentName }"
          SetScript = {
            # todo: handle non-http fetches
            try {
              (New-Object Net.WebClient).DownloadFile($using:item.Url, ('{0}\Temp\{1}.exe' -f $env:SystemRoot, $using:item.ComponentName))
            } catch {
              # handle redirects (eg: sourceforge)
              Invoke-WebRequest -Uri $using:item.Url -OutFile ('{0}\Temp\{1}.exe' -f $env:SystemRoot, $using:item.ComponentName) -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
            }
            Unblock-File -Path ('{0}\Temp\{1}.exe' -f $env:SystemRoot, $using:item.ComponentName)
          }
          TestScript = { return (Test-Path -Path ('{0}\Temp\{1}.exe' -f $env:SystemRoot, $using:item.ComponentName) -ErrorAction SilentlyContinue) }
        }
        Log ('Log-ExeDownload-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]ExeDownload-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, download completed' -f $item.ComponentType, $item.ComponentName)
        }
        Script ('ExeInstall-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]ExeDownload-{0}' -f $item.ComponentName)
          GetScript = "@{ ExeInstall = $item.ComponentName }"
          SetScript = {
            $exe = ('{0}\Temp\{1}' -f $env:SystemRoot, $using:item.ComponentName)
            $process = Start-Process $exe -ArgumentList $using:item.Arguments -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}-{2}-stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), [IO.Path]::GetFileNameWithoutExtension($exe)) -RedirectStandardError ('{0}\log\{1}-{2}-stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), [IO.Path]::GetFileNameWithoutExtension($exe))
            if (-not (($process.ExitCode -eq 0) -or ($using:item.AllowedExitCodes -contains $process.ExitCode))) {
              throw
            }
          }
          TestScript = { return Validate-All -validations $using:item.Validate }
        }
        Log ('Log-ExeInstall-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]ExeInstall-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'MsiInstall' {
        Script ('MsiDownload-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ MsiDownload = $item.ComponentName }"
          SetScript = {
            # todo: handle non-http fetches
            try {
              (New-Object Net.WebClient).DownloadFile($using:item.Url, ('{0}\Temp\{1}.msi' -f $env:SystemRoot, $using:item.ComponentName))
            } catch {
              # handle redirects (eg: sourceforge)
              Invoke-WebRequest -Uri $using:item.Url -OutFile ('{0}\Temp\{1}.msi' -f $env:SystemRoot, $using:item.ComponentName) -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
            }
            Unblock-File -Path ('{0}\Temp\{1}.msi' -f $env:SystemRoot, $using:item.ComponentName)
          }
          TestScript = { return (Test-Path -Path ('{0}\Temp\{1}.msi' -f $env:SystemRoot, $using:item.ComponentName) -ErrorAction SilentlyContinue) }
        }
        Log ('Log-MsiDownload-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]MsiDownload-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, download completed' -f $item.ComponentType, $item.ComponentName)
        }
        Package ('MsiInstall-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          Name = $item.Name
          Path = ('{0}\Temp\{1}.msi' -f $env:SystemRoot, $item.ComponentName)
          ProductId = $item.ProductId
          Ensure = 'Present'
          LogPath = ('{0}\log\{1}-{2}.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $item.ComponentName)
        }
        Log ('Log-MsiInstall-{0}' -f $item.ComponentName) {
          DependsOn = ('[Package]MsiInstall-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'WindowsFeatureInstall' {
        WindowsFeature ('WindowsFeatureInstall-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          Name = $item.Name
          Ensure = 'Present'
        }
        Log ('Log-WindowsFeatureInstall-{0}' -f $item.ComponentName) {
          DependsOn = ('[WindowsFeature]WindowsFeatureInstall-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'ZipInstall' {
        Script ('ZipDownload-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ ZipDownload = $item.ComponentName }"
          SetScript = {
            # todo: handle non-http fetches
            try {
              (New-Object Net.WebClient).DownloadFile($using:item.Url, ('{0}\Temp\{1}.zip' -f $env:SystemRoot, $using:item.ComponentName))
            } catch {
              # handle redirects (eg: sourceforge)
              Invoke-WebRequest -Uri $using:item.Url -OutFile ('{0}\Temp\{1}.zip' -f $env:SystemRoot, $using:item.ComponentName) -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
            }
            Unblock-File -Path ('{0}\Temp\{1}.zip' -f $env:SystemRoot, $using:item.ComponentName)
          }
          TestScript = { return (Test-Path -Path ('{0}\Temp\{1}.zip' -f $env:SystemRoot, $using:item.ComponentName) -ErrorAction SilentlyContinue) }
        }
        Log ('Log-ZipDownload-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]ZipDownload-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, download completed' -f $item.ComponentType, $item.ComponentName)
        }
        Archive ('ZipInstall-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          Path = ('{0}\Temp\{1}.zip' -f $env:SystemRoot, $item.ComponentName)
          Destination = $item.Destination
          Ensure = 'Present'
        }
        Log ('Log-ZipInstall-{0}' -f $item.ComponentName) {
          DependsOn = ('[Archive]ZipInstall-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'ServiceControl' {
        Service ('ServiceControl-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          Name = $item.Name
          State = $item.State
          StartupType = $item.StartupType
        }
        Log ('Log-ServiceControl-{0}' -f $item.ComponentName) {
          DependsOn = ('[Service]ServiceControl-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'EnvironmentVariableSet' {
        Script ('EnvironmentVariableSet-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ EnvironmentVariableSet = $item.ComponentName }"
          SetScript = {
            [Environment]::SetEnvironmentVariable($using:item.Name, $using:item.Value, $using:item.Target)
          }
          TestScript = { return ((Get-ChildItem env: | ? { $_.Name -ieq $using:item.Name } | Select-Object -first 1).Value -eq $using:item.Value) }
        }
        Log ('Log-EnvironmentVariableSet-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]EnvironmentVariableSet-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'EnvironmentVariableUniqueAppend' {
        Script ('EnvironmentVariableUniqueAppend-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ EnvironmentVariableUniqueAppend = $item.ComponentName }"
          SetScript = {
            $value = (@((@(((Get-ChildItem env: | ? { $_.Name -ieq $using:item.Name } | Select-Object -first 1).Value) -split ';') + $using:item.Values) | select -Unique) -join ';')
            [Environment]::SetEnvironmentVariable($using:item.Name, $value, $using:item.Target)
          }
          TestScript = { return $false }
        }
        Log ('Log-EnvironmentVariableUniqueAppend-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]EnvironmentVariableUniqueAppend-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'EnvironmentVariableUniquePrepend' {
        Script ('EnvironmentVariableUniquePrepend-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ EnvironmentVariableUniquePrepend = $item.ComponentName }"
          SetScript = {
            $value = (@(($using:item.Values + @(((Get-ChildItem env: | ? { $_.Name -ieq $using:item.Name } | Select-Object -first 1).Value) -split ';')) | select -Unique) -join ';')
            [Environment]::SetEnvironmentVariable($using:item.Name, $value, $using:item.Target)
          }
          TestScript = { return $false }
        }
        Log ('Log-EnvironmentVariableUniquePrepend-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]EnvironmentVariableUniquePrepend-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'RegistryKeySet' {
        Registry ('RegistryKeySet-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          Ensure = 'Present'
          Force = $true
          Key = $item.Key
          ValueName = $item.ValueName
        }
        Log ('Log-RegistryKeySet-{0}' -f $item.ComponentName) {
          DependsOn = ('[Registry]RegistryKeySet-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'RegistryValueSet' {
        Registry ('RegistryValueSet-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          Ensure = 'Present'
          Force = $true
          Key = $item.Key
          ValueName = $item.ValueName
          ValueType = $item.ValueType
          Hex = $item.Hex
          ValueData = $item.ValueData
        }
        Log ('Log-RegistryValueSet-{0}' -f $item.ComponentName) {
          DependsOn = ('[Registry]RegistryValueSet-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
      'FirewallRule' {
        Script ('FirewallRule-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ FirewallRule = $item.ComponentName }"
          SetScript = {
            New-NetFirewallRule -DisplayName ('{0} ({1} {2} {3}): {4}' -f $using:item.ComponentName, $using:item.Protocol, $using:item.LocalPort, $using:item.Direction, $using:item.Action) -Protocol $using:item.Protocol -LocalPort $using:item.LocalPort -Direction $using:item.Direction -Action $using:item.Action
          }
          TestScript = { return [bool](Get-NetFirewallRule -DisplayName ('{0} ({1} {2} {3}): {4}' -f $using:item.ComponentName, $using:item.Protocol, $using:item.LocalPort, $using:item.Direction, $using:item.Action) -ErrorAction SilentlyContinue) }
        }
        Log ('Log-FirewallRule-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]FirewallRule-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
    }
  }
  Script RemoveSupportingModules {
    GetScript = "@{ Script = RemoveSupportingModules }"
    SetScript = {
      $modulesPath = ('{0}\Modules' -f $pshome)
      foreach ($url in $using:supportingModules) {
        $filename = [IO.Path]::GetFileName($url)
        $moduleName = [IO.Path]::GetFileNameWithoutExtension($filename)
        $modulePath = ('{0}\{1}' -f $modulesPath, $moduleName)
        if (Test-Path -Path $modulePath -ErrorAction SilentlyContinue) {
          Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
          Remove-Item -path $modulePath -recurse -force
        }
      }
    }
    TestScript = { return (-not (Test-Path -Path ('{0}\Modules\OCC-*' -f $pshome) -ErrorAction SilentlyContinue)) }
  }
  Script Reboot {
    GetScript = "@{ Script = Reboot }"
    SetScript = {
      if ([Environment]::GetEnvironmentVariable('DscRebootRequired', 'Process') -ieq 'true') {
        [Environment]::SetEnvironmentVariable('DscRebootRequired', 'false', 'Process')
        Restart-Computer -Force
      }
    }
    TestScript = { return (-not ([Environment]::GetEnvironmentVariable('DscRebootRequired', 'Process') -ieq 'true')) }
  }
}
