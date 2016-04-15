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
        File ('DirectoryCreate-{0}' -f $item.Path.Replace(':', '').Replace('\', '_')) {
          Ensure = 'Present'
          Type = 'Directory'
          DestinationPath = $item.Path
        }
        Log ('Log-DirectoryCreate-{0}' -f $item.Path.Replace(':', '').Replace('\', '_')) {
          DependsOn = ('[File]DirectoryCreate-{0}' -f $item.Path.Replace(':', '').Replace('\', '_'))
          Message = ('Directory: {0}, created (or present)' -f $item.Path)
        }
      }
      'DirectoryDelete' {
        Script ('DirectoryDelete-{0}' -f $item.Path.Replace(':', '').Replace('\', '_')) {
          GetScript = "@{ DirectoryDelete = $item.Path }"
          SetScript = {
            try {
              Remove-Item $using:item.Path -Confirm:$false -force
            } catch {
              Start-Process 'icacls' -ArgumentList @($using:item.Path, '/grant', ('{0}:(OI)(CI)F' -f $env:Username), '/inheritance:r') -Wait -NoNewWindow -PassThru | Out-Null
              Remove-Item $using:item.Path -Confirm:$false -force
              # todo: another try catch block with move to recycle bin, empty recycle bin
            }
          }
          TestScript = { (-not (Test-Path -Path $using:item.Path -ErrorAction SilentlyContinue)) }
        }
        Log ('LogDirectoryDelete-{0}' -f $item.Path.Replace(':', '').Replace('\', '_')) {
          DependsOn = ('[Script]DirectoryDelete-{0}' -f $item.Path.Replace(':', '').Replace('\', '_'))
          Message = ('Directory: {0}, deleted (or not present)' -f $item.Path)
        }
      }
      'ExeInstall' {
        Script ('Download-{0}' -f [IO.Path]::GetFileNameWithoutExtension($item.LocalName)) {
          GetScript = "@{ ExeDownload = $item.Url }"
          SetScript = {
            try {
              (New-Object Net.WebClient).DownloadFile($using:item.Url, ('{0}\Temp\{1}' -f $env:SystemRoot, $using:item.LocalName))
            } catch {
              # handle redirects (eg: sourceforge)
              Invoke-WebRequest -Uri $using:item.Url -OutFile ('{0}\Temp\{1}' -f $env:SystemRoot, $using:item.LocalName) -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
            }
            Unblock-File -Path ('{0}\Temp\{1}' -f $env:SystemRoot, $using:item.LocalName)
          }
          TestScript = { return (Test-Path -Path ('{0}\Temp\{1}' -f $env:SystemRoot, $using:item.LocalName) -ErrorAction SilentlyContinue) }
        }
        Log ('LogDownload-{0}' -f [IO.Path]::GetFileNameWithoutExtension($item.LocalName)) {
          DependsOn = ('[Script]Download-{0}' -f [IO.Path]::GetFileNameWithoutExtension($item.LocalName))
          Message = ('Download: {0}, succeeded (or present)' -f [IO.Path]::GetFileNameWithoutExtension($item.LocalName))
        }
        Script ('Install-{0}' -f [IO.Path]::GetFileNameWithoutExtension($item.LocalName)) {
          DependsOn = ('[Script]Download-{0}' -f [IO.Path]::GetFileNameWithoutExtension($item.LocalName))
          GetScript = "@{ ExeInstall = $env:SystemRoot\Temp\$item.LocalName }"
          SetScript = {
            $exe = ('{0}\Temp\{1}' -f $env:SystemRoot, $using:item.LocalName)
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
                    (Test-Path -Path $_.Path -ErrorAction SilentlyContinue)
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
                    (((Get-Content $fc.Path) | % {
                      $_ -match $fc.Match
                    }) -contains $true) # a line within the file contained a match
                  }) -contains $false)) # no files failed to contain a match (see '-not' above)
                )
              )
            )
          }
        }
        Log ('LogInstall-{0}' -f [IO.Path]::GetFileNameWithoutExtension($item.LocalName)) {
          DependsOn = ('[Script]Install-{0}' -f [IO.Path]::GetFileNameWithoutExtension($item.LocalName))
          Message = ('Install: {0}, succeeded (or present)' -f [IO.Path]::GetFileNameWithoutExtension($item.LocalName))
        }
      }
    }
  }
}
