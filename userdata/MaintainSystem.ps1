<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Write-Log {
  param (
    [string] $message,
    [string] $severity = 'INFO',
    [string] $source = 'MaintainSystem',
    [string] $logName = 'Application'
  )
  if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
    New-EventLog -LogName $logName -Source $source
  }
  switch ($severity) {
    'DEBUG' {
      $entryType = 'SuccessAudit'
      $eventId = 2
      break
    }
    'WARN' {
      $entryType = 'Warning'
      $eventId = 3
      break
    }
    'ERROR' {
      $entryType = 'Error'
      $eventId = 4
      break
    }
    default {
      $entryType = 'Information'
      $eventId = 1
      break
    }
  }
  Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
  if ([Environment]::UserInteractive) {
    $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
    Write-Host -object $message -ForegroundColor $fc
  }
}
function Run-MaintainSystem {
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    Remove-OldTaskDirectories
    Invoke-OccReset
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Remove-OldTaskDirectories {
  param (
    [string[]] $targets = @('Z:\task_*', 'C:\Users\task_*')
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    foreach ($target in ($targets | ? { (Test-Path -Path ('{0}:\' -f $_[0]) -ErrorAction SilentlyContinue) })) {
      $all_task_paths = @(Get-ChildItem -Path $target | Sort-Object -Property { $_.LastWriteTime })
      if ($all_task_paths.length -gt 1) {
        Write-Log -message ('{0} :: {1} task directories detected matching pattern: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths.length, $target) -severity 'INFO'
        $old_task_paths = $all_task_paths[0..($all_task_paths.Length-2)]
        foreach ($old_task_path in $old_task_paths) {
          try {
            & takeown.exe @('/a', '/f', $old_task_path, '/r', '/d', 'Y')
            & icacls.exe @($old_task_path, '/grant', 'Administrators:F', '/t')
            Remove-Item -Path $old_task_path -Force -Recurse
            Write-Log -message ('{0} :: removed task directory: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime) -severity 'INFO'
          } catch {
            Write-Log -message ('{0} :: failed to remove task directory: {1}, with last write time: {2}. {3}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime, $_.Exception.Message) -severity 'ERROR'
          }
        }
      } elseif ($all_task_paths.length -eq 1) {
        Write-Log -message ('{0} :: a single task directory was detected at: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths[0].FullName, $all_task_paths[0].LastWriteTime) -severity 'DEBUG'
      } else {
        Write-Log -message ('{0} :: no task directories detected matching pattern: {1}' -f$($MyInvocation.MyCommand.Name), $target) -severity 'DEBUG'
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Invoke-OccReset {
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    try {
      if (${env:COMPUTERNAME}.ToLower().StartsWith('t-w1064-')) {
        $guid = [Guid]::NewGuid()
        $scriptUrl = ('https://raw.githubusercontent.com/mozilla-releng/OpenCloudConfig/master/userdata/rundsc.ps1?{0}' -f $guid)
        $newScriptPath = ('C:\dsc\rundsc-{0}.ps1' -f $guid)
        (New-Object Net.WebClient).DownloadFile($scriptUrl, $newScriptPath)

        $oldScriptPath = 'C:\dsc\rundsc.ps1'
        if (Test-Path -Path $oldScriptPath -ErrorAction SilentlyContinue) {
          $newSha512Hash = (Get-FileHash -Path $newScriptPath -Algorithm 'SHA512').Hash
          $oldSha512Hash = (Get-FileHash -Path $oldScriptPath -Algorithm 'SHA512').Hash

          if ($newSha512Hash -ne $oldSha512Hash) {
            Write-Log -message ('{0} :: rundsc hashes do not match (old: {1}, new: {2})' -f $($MyInvocation.MyCommand.Name), ('{0}...{1}' -f $oldSha512Hash.Substring(0, 9), $oldSha512Hash.Substring($oldSha512Hash.length - 9, 9)), ('{0}...{1}' -f $newSha512Hash.Substring(0, 9), $newSha512Hash.Substring($newSha512Hash.length - 9, 9))) -severity 'INFO'
            Remove-Item -Path $oldScriptPath -force -ErrorAction SilentlyContinue
            Move-item -LiteralPath $newScriptPath -Destination $oldScriptPath
          } else {
            Write-Log -message ('{0} :: rundsc hashes match (old: {1}, new: {2})' -f $($MyInvocation.MyCommand.Name), ('{0}...{1}' -f $oldSha512Hash.Substring(0, 9), $oldSha512Hash.Substring($oldSha512Hash.length - 9, 9)), ('{0}...{1}' -f $newSha512Hash.Substring(0, 9), $newSha512Hash.Substring($newSha512Hash.length - 9, 9))) -severity 'DEBUG'
            Remove-Item -Path $newScriptPath -force -ErrorAction SilentlyContinue
          }
        } else {
          Move-item -LiteralPath $newScriptPath -Destination $oldScriptPath
          Write-Log -message ('{0} :: existing rundsc not found. downloaded rundsc applied' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
        }

        $gwConfigPath = 'C:\generic-worker\gen_worker.config'
        $gwExePath = 'C:\generic-worker\generic-worker.exe'
        if (Test-Path -Path $gwConfigPath -ErrorAction SilentlyContinue) {
          Write-Log -message ('{0} :: gw config found at {1}' -f $($MyInvocation.MyCommand.Name), $gwConfigPath) -severity 'DEBUG'
          if (Test-Path -Path $gwExePath -ErrorAction SilentlyContinue) {
            if (@(& $gwExePath @('--version') 2>&1) -like 'generic-worker 10.11.2 *') {
              Write-Log -message ('{0} :: gw 10.11.2 exe found at {1}' -f $($MyInvocation.MyCommand.Name), $gwExePath) -severity 'DEBUG'

              $gwConfig = Get-Content $gwConfigPath -raw | ConvertFrom-Json
              if (($gwConfig.accessToken) -and ($gwConfig.accessToken.length)) {
                Write-Log -message ('{0} :: gw accessToken appears to be set in {1} with a length of {2}' -f $($MyInvocation.MyCommand.Name), $gwConfigPath, $gwConfig.accessToken.length) -severity 'DEBUG'
              } else {
                Write-Log -message ('{0} :: gw accessToken is not set in {1}' -f $($MyInvocation.MyCommand.Name), $gwConfigPath) -severity 'DEBUG'
                #[System.IO.File]::WriteAllLines($gwConfigPath, ($gwConfig | ConvertTo-Json -Depth 3), (New-Object -TypeName 'System.Text.UTF8Encoding' -ArgumentList $false))
              }
              
            } elseif (@(& $gwExePath @('--version') 2>&1) -like 'generic-worker 13.*') {
              Write-Log -message ('{0} :: gw 13+ exe found at {1}' -f $($MyInvocation.MyCommand.Name), $gwExePath) -severity 'DEBUG'

              $gwConfig = Get-Content $gwConfigPath -raw | ConvertFrom-Json
              if ($gwConfig.signingKeyLocation) {
                Write-Log -message ('{0} :: removing signingKeyLocation {1} from {2}' -f $($MyInvocation.MyCommand.Name), $gwConfig.signingKeyLocation, $gwConfigPath) -severity 'DEBUG'
                $gwConfig.PSObject.Properties.Remove('signingKeyLocation') #"signingKeyLocation": "C:\\generic-worker\\generic-worker-gpg-signing-key.key",
              }
              $ed25519SigningKeyLocationPath = 'C:\generic-worker\ed25519.key'
              if (Test-Path -Path $ed25519SigningKeyLocationPath -ErrorAction SilentlyContinue) {
                Write-Log -message ('{0} :: detected ed25519SigningKey at {1}' -f $($MyInvocation.MyCommand.Name), $ed25519SigningKeyLocationPath) -severity 'DEBUG'
              } else {
                & $gwExePath @('new-ed25519-keypair', '--file', $ed25519SigningKeyLocationPath)
                Write-Log -message ('{0} :: generated ed25519SigningKey at {1}' -f $($MyInvocation.MyCommand.Name), $ed25519SigningKeyLocationPath) -severity 'INFO'
              }
              if (-not ($gwConfig.ed25519SigningKeyLocation)) {
                Write-Log -message ('{0} :: adding ed25519SigningKeyLocation {1} to {2}' -f $($MyInvocation.MyCommand.Name), $ed25519SigningKeyLocationPath, $gwConfigPath) -severity 'INFO'
                $gwConfig.Add('ed25519SigningKeyLocation', $ed25519SigningKeyLocationPath)
              }
              $openpgpSigningKeyLocationPath = 'C:\generic-worker\openpgp.key'
              if (Test-Path -Path $openpgpSigningKeyLocationPath -ErrorAction SilentlyContinue) {
                Write-Log -message ('{0} :: detected openpgpSigningKey at {1}' -f $($MyInvocation.MyCommand.Name), $openpgpSigningKeyLocationPath) -severity 'DEBUG'
              } else {
                & $gwExePath @('new-openpgp-keypair', '--file', $openpgpSigningKeyLocationPath)
                Write-Log -message ('{0} :: generated openpgpSigningKey at {1}' -f $($MyInvocation.MyCommand.Name), $openpgpSigningKeyLocationPath) -severity 'INFO'
              }
              if (-not ($gwConfig.openpgpSigningKeyLocation)) {
                Write-Log -message ('{0} :: adding openpgpSigningKeyLocation {1} to {2}' -f $($MyInvocation.MyCommand.Name), $openpgpSigningKeyLocationPath, $gwConfigPath) -severity 'INFO'
                $gwConfig.Add('openpgpSigningKeyLocation', $openpgpSigningKeyLocationPath)
              }
              [System.IO.File]::WriteAllLines($gwConfigPath, ($gwConfig | ConvertTo-Json -Depth 3), (New-Object -TypeName 'System.Text.UTF8Encoding' -ArgumentList $false))
            }
          }
        } else {
          Write-Log -message ('{0} :: existing gw config not found' -f $($MyInvocation.MyCommand.Name)) -severity 'WARN'
        }
      }
    } catch {
      Write-Log -message ('{0} :: exception - {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
Run-MaintainSystem
