<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration DynamicConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  switch -wildcard ((Get-WmiObject -class Win32_OperatingSystem).Caption) {
    'Microsoft Windows Server 2012*' {
      $manifest = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/win2012.json' -UseBasicParsing | ConvertFrom-Json)
    }
    'Microsoft Windows Server 2008*' {
      $manifest = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/win2008.json' -UseBasicParsing | ConvertFrom-Json)
    }
    default {
      $manifest = ('{"Items":[{"ComponentType":"DirectoryCreate","Path":"$env:SystemDrive\\log"}]}' | ConvertFrom-Json)
    }
  }
  Log Manifest {
    Message = ('Manifest: {0}' -f $manifest)
  }
  foreach ($item in $manifest.Items) {
    switch ($item.ComponentType) {
      'DirectoryCreate' {
        File ('DirectoryCreate-{0}' -f ($item.Path.Format -f $item.Path.Tokens).Replace(':', '').Replace('\', '_')) {
          Ensure = 'Present'
          Type = 'Directory'
          DestinationPath = ($item.Path.Format -f $item.Path.Tokens)
        }
        Log ('Log-{0}' -f ($item.Path.Format -f $item.Path.Tokens).Replace(':', '').Replace('\', '_')) {
          DependsOn = ('[File]{0}' -f ($item.Path.Format -f $item.Path.Tokens).Replace(':', '').Replace('\', '_'))
          Message = ('Directory: {0}, created (or present)' -f ($item.Path.Format -f $item.Path.Tokens))
        }
      }
      'DirectoryDelete' {
        Script ('DirectoryDelete-{0}' -f ($item.Path.Format -f $item.Path.Tokens).Replace(':', '').Replace('\', '_')) {
          GetScript = { @{ Result = $false } }
          SetScript = {
            try {
              Remove-Item ($using:item.Path.Format -f $using:item.Path.Tokens) -Confirm:$false -force
            } catch {
              Start-Process 'icacls' -ArgumentList @(($using:item.Path.Format -f $using:item.Path.Tokens), '/grant', ('{0}:(OI)(CI)F' -f $env:Username), '/inheritance:r') -Wait -NoNewWindow -PassThru | Out-Null
              Remove-Item ($using:item.Path.Format -f $using:item.Path.Tokens) -Confirm:$false -force
              # todo: another try catch block with move to recycle bin, empty recycle bin
            }
          }
          TestScript = { (-not (Test-Path -Path ($using:item.Path.Format -f $using:item.Path.Tokens) -ErrorAction SilentlyContinue)) }
        }
        Log ('LogDirectoryDelete-{0}' -f ($item.Path.Format -f $item.Path.Tokens).Replace(':', '').Replace('\', '_')) {
          DependsOn = ('[Script]DirectoryDelete-{0}' -f ($item.Path.Format -f $item.Path.Tokens).Replace(':', '').Replace('\', '_'))
          Message = ('Directory: {0}, deleted (or not present)' -f ($item.Path.Format -f $item.Path.Tokens))
        }
      }
      'ExeInstall' {
        Script ('Download-{0}' -f [IO.Path]::GetFileNameWithoutExtension((if (-not [string]::IsNullOrWhitespace($item.LocalName)) { $item.LocalName } else { $item.Url }))) {
          GetScript = { @{ Result = $false } }
          SetScript = {
            try {
              (New-Object Net.WebClient).DownloadFile($using:item.Url, ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName((if (-not [string]::IsNullOrWhitespace($using:item.LocalName)) { $using:item.LocalName } else { $using:item.Url }))))
            } catch {
              # handle redirects (eg: sourceforge)
              Invoke-WebRequest -Uri $using:item.Url -OutFile ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName((if (-not [string]::IsNullOrWhitespace($using:item.LocalName)) { $using:item.LocalName } else { $using:item.Url }))) -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
            }
            Unblock-File -Path ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName((if (-not [string]::IsNullOrWhitespace($using:item.LocalName)) { $using:item.LocalName } else { $using:item.Url })))
          }
          TestScript = { return (Test-Path -Path ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName((if (-not [string]::IsNullOrWhitespace($using:item.LocalName)) { $using:item.LocalName } else { $using:item.Url }))) -ErrorAction SilentlyContinue) }
        }
        Log ('LogDownload-{0}' -f [IO.Path]::GetFileNameWithoutExtension((if (-not [string]::IsNullOrWhitespace($item.LocalName)) { $item.LocalName } else { $item.Url }))) {
          DependsOn = ('[Script]Download-{0}' -f [IO.Path]::GetFileNameWithoutExtension((if (-not [string]::IsNullOrWhitespace($item.LocalName)) { $item.LocalName } else { $item.Url })))
          Message = ('Download: {0}, succeeded (or present)' -f [IO.Path]::GetFileNameWithoutExtension((if (-not [string]::IsNullOrWhitespace($item.LocalName)) { $item.LocalName } else { $item.Url })))
        }
        Script ('Install-{0}' -f [IO.Path]::GetFileNameWithoutExtension((if (-not [string]::IsNullOrWhitespace($item.LocalName)) { $item.LocalName } else { $item.Url }))) {
          DependsOn = ('[Script]Download-{0}' -f [IO.Path]::GetFileNameWithoutExtension((if (-not [string]::IsNullOrWhitespace($using:item.LocalName)) { $using:item.LocalName } else { $using:item.Url })))
          GetScript = { @{ Result = $false } }
          SetScript = {
            $exe = ('{0}\Temp\{1}' -f $env:SystemRoot, [IO.Path]::GetFileName((if (-not [string]::IsNullOrWhitespace($using:item.LocalName)) { $using:item.LocalName } else { $using:item.Url })))
            $process = Start-Process $exe -ArgumentList @('/Q') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}-{2}-stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), [IO.Path]::GetFileNameWithoutExtension($exe)) -RedirectStandardError ('{0}\log\{1}-{2}-stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), [IO.Path]::GetFileNameWithoutExtension($exe))
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

                # either no validation paths-exist are specified
                (-not ($using:item.Validate.PathsExist)) -or (

                  # validation paths-exist are specified
                  (($using:item.Validate.PathsExist) -and ($using:item.Validate.PathsExist.Length -gt 0)) -and

                  # all validation paths-exist are satisfied (exist on the instance)
                  (-not (@($using:item.Validate.PathsExist | % {
                    (Test-Path -Path ($_.Path.Format -f $_.Path.Tokens) -ErrorAction SilentlyContinue)
                  }) -contains $false))
                )
              ) -and (

                # either no validation commands-return are specified
                (-not ($using:item.Validate.CommandsReturn)) -or (

                  # validation commands-return are specified
                  (($using:item.Validate.CommandsReturn) -and ($using:item.Validate.CommandsReturn.Length -gt 0)) -and

                  # all validation commands-return are satisfied
                  ($false) # todo: implement
                )
              ) -and (
                # either no validation files-contain are specified
                (-not ($using:item.Validate.FilesContain)) -or (

                  # validation files-contain are specified
                  (($using:item.Validate.FilesContain) -and ($using:item.Validate.FilesContain.Length -gt 0)) -and

                  # all validation files-contain are satisfied
                  (-not (@($using:item.Validate.FilesContain | % {
                    $fc = $_
                    (((Get-Content ($fc.Path.Format -f $fc.Path.Tokens)) | % {
                      $_ -match $fc.Match
                    }) -contains $true) # a line within the file contained a match
                  }) -contains $false)) # no files failed to contain a match (see '-not' above)
                )
              )
            )
          }
        }
        Log ('LogInstall-{0}' -f [IO.Path]::GetFileNameWithoutExtension((if (-not [string]::IsNullOrWhitespace($item.LocalName)) { $item.LocalName } else { $item.Url }))) {
          DependsOn = ('[Script]Install-{0}' -f [IO.Path]::GetFileNameWithoutExtension((if (-not [string]::IsNullOrWhitespace($item.LocalName)) { $item.LocalName } else { $item.Url })))
          Message = ('Install: {0}, succeeded (or present)' -f [IO.Path]::GetFileNameWithoutExtension((if (-not [string]::IsNullOrWhitespace($item.LocalName)) { $item.LocalName } else { $item.Url })))
        }
      }
    }
  }
}
