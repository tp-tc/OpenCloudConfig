<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration TaskClusterToolChainConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  # log folder for installation logs
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }

  Script PSToolsDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\PSTools.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://download.sysinternals.com/files/PSTools.zip', ('{0}\Temp\PSTools.zip' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\PSTools.zip' -f $env:SystemRoot)
    }
    TestScript = { if ((Test-Path -Path ('{0}\Temp\PSTools.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
  Archive PSToolsExtract {
    Path = ('{0}\Temp\PSTools.zip' -f $env:SystemRoot)
    Destination = ('{0}\PSTools' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  
  Script NssmDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://www.nssm.cc/release/nssm-2.24.zip', ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot)
    }
    TestScript = { if ((Test-Path -Path ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
  Archive NssmExtract {
    Path = ('{0}\Temp\nssm-2.24.zip' -f $env:SystemRoot)
    Destination = ('{0}\' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  
  File GenericWorkerFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\generic-worker' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script GenericWorkerDownload {
    DependsOn = @('[File]GenericWorkerFolder')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } } # todo: version check
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://github.com/taskcluster/generic-worker/releases/download/v1.0.11/generic-worker-windows-amd64.exe', ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive)
    }
    TestScript = { if (Test-Path -Path ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } } # todo: version check
  }
  Script GenericWorkerInstall {
    DependsOn = @('[Script]GenericWorkerDownload', '[File]LogFolder')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\generic-worker\generic-worker.config' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\generic-worker\generic-worker.exe' -f $env:SystemDrive) -ArgumentList ('install --config {0}\generic-worker\generic-worker.config' -f $env:SystemDrive) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.generic-worker-windows-amd64.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.generic-worker-windows-amd64.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (Test-Path -Path ('{0}\generic-worker\generic-worker.config' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
}
