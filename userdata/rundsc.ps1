<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Write-Log {
  param (
    [string] $message,
    [string] $severity = 'INFO',
    [string] $source = 'OpenCloudConfig',
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
  if ([Environment]::UserInteractive -and $env:OccConsoleOutput) {
    $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
    Write-Host -object $message -ForegroundColor $fc
  }
}
function Install-SupportingModules {
  param (
    [string] $sourceOrg,
    [string] $sourceRepo,
    [string] $sourceRev,
    [string] $modulesPath = ('{0}\Modules' -f $pshome),
    [string[]] $moduleUrls = @(
      ('https://raw.githubusercontent.com/{0}/{1}/{2}/userdata/OCC-Bootstrap.psm1' -f $sourceOrg, $sourceRepo, $sourceRev)
    )
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    foreach ($url in $moduleUrls) {
      $filename = [IO.Path]::GetFileName($url)
      $moduleName = [IO.Path]::GetFileNameWithoutExtension($filename)
      $modulePath = ('{0}\{1}' -f $modulesPath, $moduleName)
      if (Test-Path -Path $modulePath -ErrorAction SilentlyContinue) {
        try {
          Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
          Remove-Item -path $modulePath -recurse -force
          if (Test-Path -Path $modulePath -ErrorAction SilentlyContinue) {
            Write-Log -message ('{0} :: failed to remove module: {1}.' -f $($MyInvocation.MyCommand.Name), $moduleName) -severity 'ERROR'
          } else {
            Write-Log -message ('{0} :: removed module: {1}.' -f $($MyInvocation.MyCommand.Name), $moduleName) -severity 'DEBUG'
          }
        } catch {
          Write-Log -message ('{0} :: error removing module: {1}. {2}' -f $($MyInvocation.MyCommand.Name), $moduleName, $_.Exception.Message) -severity 'ERROR'
        }
      }
      try {
        New-Item -ItemType Directory -Force -Path $modulePath
        (New-Object Net.WebClient).DownloadFile(('{0}?{1}' -f $url, [Guid]::NewGuid()), ('{0}\{1}' -f $modulePath, $filename))
        Unblock-File -Path ('{0}\{1}' -f $modulePath, $filename)
        if (Test-Path -Path $modulePath -ErrorAction SilentlyContinue) {
          Write-Log -message ('{0} :: installed module: {1}.' -f $($MyInvocation.MyCommand.Name), $moduleName) -severity 'DEBUG'
        } else {
          Write-Log -message ('{0} :: failed to install module: {1} from {2}.' -f $($MyInvocation.MyCommand.Name), $moduleName, $url) -severity 'ERROR'
        }
      } catch {
        Write-Log -message ('{0} :: error installing module: {1} from {2}. {3}' -f $($MyInvocation.MyCommand.Name), $moduleName, $url, $_.Exception.Message) -severity 'ERROR'
      }
      try {
        Import-Module -Name $moduleName
        Write-Log -message ('{0} :: imported module: {1}.' -f $($MyInvocation.MyCommand.Name), $moduleName) -severity 'DEBUG'
      } catch {
        Write-Log -message ('{0} :: error importing module: {1}. {2}' -f $($MyInvocation.MyCommand.Name), $moduleName, $_.Exception.Message) -severity 'ERROR'
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Set-OpenCloudConfigSource {
  param (
    [hashtable] $sourceMap = @{
      'Organisation' = $null;
      'Repository' = $null;
      'Revision' = $null
    },
    [switch] $sourceOverrideEnabled = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\DisableSourceOverride' -ErrorAction SilentlyContinue) -and ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig' -Name 'DisableSourceOverride').DisableSourceOverride)) { $false } else { $true }),
    [switch] $workerTypeOverrideEnabled = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\DisableWorkerTypeOverride' -ErrorAction SilentlyContinue) -and ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig' -Name 'DisableWorkerTypeOverride').DisableWorkerTypeOverride)) { $false } else { $true })
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    Write-Log -message ('{0} :: registry override of occ source is {1}' -f $($MyInvocation.MyCommand.Name), $(if ($sourceOverrideEnabled) { 'enabled' } else { 'disabled' })) -severity 'INFO'
    Write-Log -message ('{0} :: registry override of worker type is {1}' -f $($MyInvocation.MyCommand.Name), $(if ($workerTypeOverrideEnabled) { 'enabled' } else { 'disabled' })) -severity 'INFO'
    # create occ registry key
    if (Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig' -ErrorAction SilentlyContinue) {
      Write-Log -message ('{0} :: detected registry path: HKLM:\SOFTWARE\Mozilla\OpenCloudConfig' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    } else {
      New-Item -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig' -Force
      Write-Log -message ('{0} :: created registry path: HKLM:\SOFTWARE\Mozilla\OpenCloudConfig' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
    }
    if (${env:COMPUTERNAME}.ToLower().StartsWith('t-w')) {
      $workerTypeOverrideMap = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mozilla-releng/OpenCloudConfig/master/cfg/datacenter-workertype-override-map.json' -UseBasicParsing | ConvertFrom-Json)
      try {
        $workerType = ($workerTypeOverrideMap | ? { $_.hostname -ieq $env:COMPUTERNAME }).workertype
        Write-Log -message ('{0} :: worker type override configuration ({1}) detected for {2}' -f $($MyInvocation.MyCommand.Name), $workerType, $env:COMPUTERNAME) -severity 'INFO'
        if ($workerType.EndsWith('-a')) {
          $sourceMap['Revision'] = 'alpha'
        } elseif ($workerType.EndsWith('-b')) {
          $sourceMap['Revision'] = 'beta'
        }
      } catch {
        switch -wildcard (${env:COMPUTERNAME}.ToLower()) {
          't-w1064-ms-*' {
            $workerType = 'gecko-t-win10-64-hw'
          }
          't-w1064-ux-*' {
            $workerType = 'gecko-t-win10-64-ux'
          }
        }
        Write-Log -message ('{0} :: worker type default configuration ({1}) determined for {2}' -f $($MyInvocation.MyCommand.Name), $workerType, $env:COMPUTERNAME) -severity 'DEBUG'
      }
      if ($workerType) {
        if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\WorkerType' -ErrorAction SilentlyContinue) -and ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig' -Name 'WorkerType').WorkerType -eq $workerType)) {
          Write-Log -message ('{0} :: worker type detected in registry as: {1}' -f $($MyInvocation.MyCommand.Name), (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig' -Name 'WorkerType').WorkerType) -severity 'DEBUG'
        } elseif ($workerTypeOverrideEnabled) {
          try {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig' -Type 'String' -Name 'WorkerType' -Value $workerType
            Write-Log -message ('{0} :: worker type set in registry to: {1}' -f $($MyInvocation.MyCommand.Name), $workerType) -severity 'INFO'
          }
          catch {
            Write-Log -message ('{0} :: error setting worker type in registry to: {1}. {2}' -f $($MyInvocation.MyCommand.Name), $workerType, $_.Exception.Message) -severity 'ERROR'
          }
        }
      }
    } else {
      try {
        $userdata = (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data')
        if (($userdata) -and ($userdata.Contains('</SourceOrganisation>') -or $userdata.Contains('</SourceRepository>') -or $userdata.Contains('</SourceRevision>'))) {
          foreach ($sourceItemName in $sourceMap.Keys) {
            try {
              $sourceMap[$sourceItemName] = [regex]::matches($userdata, ('<Source{0}>(.*)<\/Source{0}>' -f $sourceItemName))[0].Groups[1].Value
              if ($sourceMap[$sourceItemName]) {
                Write-Log -message ('{0} :: detected Source/{1} in userdata as: {2}' -f $($MyInvocation.MyCommand.Name), $sourceItemName, $sourceMap[$sourceItemName]) -severity 'INFO'
              }
            }
            catch {
              Write-Log -message ('{0} :: error parsing Source/{1} from userdata. {2}' -f $($MyInvocation.MyCommand.Name), $sourceItemName, $_.Exception.Message) -severity 'ERROR'
            }
          }
        }
      } catch {
        Write-Log -message ('{0} :: error downloading userdata. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
      }
    }
    # create occ/source registry key
    if (Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -ErrorAction SilentlyContinue) {
      Write-Log -message ('{0} :: detected registry path: HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    } else {
      New-Item -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Force
      Write-Log -message ('{0} :: created registry path: HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
    }
    foreach ($sourceItemName in $sourceMap.Keys) {
      if (Test-Path -Path ('HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source\{0}' -f $sourceItemName) -ErrorAction SilentlyContinue) {
        Write-Log -message ('{0} :: detected Source/{1} in registry as: {2}' -f $($MyInvocation.MyCommand.Name), $sourceItemName, (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name $sourceItemName)."$sourceItemName") -severity 'DEBUG'
      }
      if ($sourceMap.Item($sourceItemName)) {
        if ((Test-Path -Path ('HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source\{0}' -f $sourceItemName) -ErrorAction SilentlyContinue) -and ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name $sourceItemName)."$sourceItemName" -eq $sourceMap.Item($sourceItemName))) {
          Write-Log -message ('{0} :: Source/{1} detected in registry as: {2}' -f $($MyInvocation.MyCommand.Name), $sourceItemName, (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name $sourceItemName)."$sourceItemName") -severity 'DEBUG'
        } elseif($sourceOverrideEnabled) {
          try {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Type 'String' -Name $sourceItemName -Value $sourceMap.Item($sourceItemName)
            Write-Log -message ('{0} :: Source/{1} set in registry to: {2}' -f $($MyInvocation.MyCommand.Name), $sourceItemName, $sourceMap.Item($sourceItemName)) -severity 'INFO'
          }
          catch {
            Write-Log -message ('{0} :: error setting Source/{1} in registry to: {2}. {3}' -f $($MyInvocation.MyCommand.Name), $sourceItemName, $sourceMap.Item($sourceItemName), $_.Exception.Message) -severity 'ERROR'
          }
        }
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

Set-ExecutionPolicy -ExecutionPolicy 'RemoteSigned' -Force
Set-OpenCloudConfigSource
$sourceOrg = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Organisation' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Organisation').Organisation } else { 'mozilla-releng' })
$sourceRepo = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Repository' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Repository').Repository } else { 'OpenCloudConfig' })
$sourceRev = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Revision' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Revision').Revision } else { 'master' })

Install-SupportingModules -sourceOrg $sourceOrg -sourceRepo $sourceRepo -sourceRev $sourceRev
Invoke-OpenCloudConfig -sourceOrg $sourceOrg -sourceRepo $sourceRepo -sourceRev $sourceRev