<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Validate-PathsExist {
  param(
    [object[]] $items
  )
  begin {}
  process {
    # either no validation paths-exist are specified
    return ((-not ($items)) -or (

      # validation paths-exist are specified
      (($items) -and ($items.Length -gt 0)) -and

      # all validation paths-exist are satisfied (exist on the instance)
      (-not (@($items | % {
        (Test-Path -Path $_.Path -ErrorAction SilentlyContinue)
      }) -contains $false))
    ))
  }
  end {}
}


Configuration DynamicConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
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
    'CommandRun' = 'Script';
    'FileDownload' = 'Script';
    'SymbolicLink' = 'Script';
    'ExeInstall' = 'Script';
    'MsiInstall' = 'Package';
    'EnvironmentVariableSet' = 'Script';
    'EnvironmentVariableUniqueAppend' = 'Script';
    'RegistryValueSet' = 'Script'
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
      'CommandRun' {
        Script ('CommandRun-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ CommandRun = $item.ComponentName }"
          SetScript = {
            Start-Process $($using:item.Command) -ArgumentList @($using:item.Arguments | % { $($_) }) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}-{2}-stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:item.ComponentName) -RedirectStandardError ('{0}\log\{1}-{2}-stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:item.ComponentName)
          }
          TestScript = { $false } # todo: implement
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
          TestScript = {
            (
              # if no validations are specified, this function will return $false and cause the exe package to be (re)installed.
              (
                (($using:item.Validate.PathsExist) -and ($using:item.Validate.Paths.Length -gt 0)) -or
                (($using:item.Validate.CommandsReturn) -and ($using:item.Validate.CommandsReturn.Length -gt 0)) -or
                (($using:item.Validate.FilesContain) -and ($using:item.Validate.FilesContain.Length -gt 0))
              ) -and (
                Validate-PathsExist -items $using:item.Validate.PathsExist
              ) -and (

                # either no validation commands-return are specified
                (-not ($using:item.Validate.CommandsReturn)) -or (

                  # validation commands-return are specified
                  (($using:item.Validate.CommandsReturn) -and ($using:item.Validate.CommandsReturn.Length -gt 0)) -and

                  # all validation commands-return are satisfied
                  (-not (@($using:item.Validate.CommandsReturn | % {
                    $cr = $_
                    @(@(& $cr.Command $cr.Arguments) | ? {
                      $_ -match $cr.Match
                    })
                  }) -contains $false))
                )
              ) -and (
                # either no validation files-contain are specified
                (-not ($using:item.Validate.FilesContain)) -or (

                  # validation files-contain are specified
                  (($using:item.Validate.FilesContain) -and ($using:item.Validate.FilesContain.Length -gt 0)) -and

                  # all validation files-contain are satisfied
                  (-not (@($using:item.Validate.FilesContain | % {
                    $fc = $_
                    (((Get-Content $fc.Path) | % {
                      $_ -match $fc.Match
                    }) -contains $true) # a line within the file contained a match
                  }) -contains $false)) # no files failed to contain a match (see '-not' above)
                )
              )
            )
          }
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
      'RegistryValueSet' {
        Script ('RegistryValueSet-{0}' -f $item.ComponentName) {
          DependsOn = @( @($item.DependsOn) | ? { (($_) -and ($_.ComponentType)) } | % { ('[{0}]{1}-{2}' -f $componentMap.Item($_.ComponentType), $_.ComponentType, $_.ComponentName) } )
          GetScript = "@{ RegistryValueSet = $item.ComponentName }"
          SetScript = {
            Set-ItemProperty -Path $using:item.Path -Type $using:item.Type -Name $using:item.Name -Value $using:item.Value
          }
          TestScript = { return (Get-ItemProperty -Path $using:item.Path -Name $using:item.Name -eq $using:item.Value) }
        }
        Log ('Log-RegistryValueSet-{0}' -f $item.ComponentName) {
          DependsOn = ('[Script]RegistryValueSet-{0}' -f $item.ComponentName)
          Message = ('{0}: {1}, completed' -f $item.ComponentType, $item.ComponentName)
        }
      }
    }
  }
}
