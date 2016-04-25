<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration DiskConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  # log folder for installation logs
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script StripeDisks {
    GetScript = "@{ StripeDisks = $true }"
    SetScript = {
      $outfile = ('{0}\log\{1}.diskpart.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      $errfile = ('{0}\log\{1}.diskpart.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      $ephemeralVolumeCount = @(Get-WmiObject Win32_Volume | ? { ($_.DriveLetter -and !($_.SystemVolume) -and (-not ($_.DriveLetter -ieq $env:SystemDrive))) }).length
      $volumeOffset = ((@(Get-WmiObject Win32_Volume).length) - $ephemeralVolumeCount)
      $diskpartscript = @(
        '',
        "select volume 1`nremove all dismount`nselect disk 1`nclean`nconvert gpt`ncreate partition primary`nformat quick fs=ntfs`nselect volume 1`nassign letter=X",
        "select disk 1`nclean`nconvert dynamic`nselect disk 2`n clean`nconvert dynamic`ncreate volume stripe disk=1,2`nformat quick fs=ntfs`nassign letter=X"
      )
      if (($ephemeralVolumeCount -gt 0) -and ($volumeOffset -gt 0) -and ($ephemeralVolumeCount -lt $diskpartscript.length)) {
        $cs = gwmi Win32_ComputerSystem
        if ($cs.AutomaticManagedPagefile) {
          $cs.AutomaticManagedPagefile = $False
          $cs.Put()
          Start-Sleep -s 5
        }
        $pagefilesetting = gwmi win32_pagefilesetting
        if ($pagefilesetting) {
          $pagefilesetting.Delete()
          Start-Sleep -s 5
        }
        Get-ChildItem -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches' | % {
          Set-ItemProperty -path $_.Name.Replace('HKEY_LOCAL_MACHINE', 'HKLM:') -name StateFlags0012 -type DWORD -Value 2
        }
        New-Item -path ('{0}\mnt.dp' -f $env:Temp) -value $diskpartscript[$ephemeralVolumeCount] -itemType file -force
        Start-Process 'diskpart' -ArgumentList @('/s', ('{0}\mnt.dp' -f $env:Temp)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput $outfile -RedirectStandardError $errfile
      }
    }
    TestScript = { return ((Test-Path -Path 'X:\' -ErrorAction SilentlyContinue) -and (-not (Test-Path -Path 'Y:\' -ErrorAction SilentlyContinue)) -and (-not (Test-Path -Path 'Z:\' -ErrorAction SilentlyContinue))) }
  }
  Script disable8dot3 {
    GetScript = "@{ disable8dot3 = $true }"
    SetScript = {
      $outfile = ('{0}\log\{1}.fsutil.disable8dot3.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      $errfile = ('{0}\log\{1}.fsutil.disable8dot3.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Process 'fsutil' -ArgumentList @('behavior', 'set', 'disable8dot3', '1') -Wait -NoNewWindow -PassThru -RedirectStandardOutput $outfile -RedirectStandardError $errfile
    }
    TestScript = { return $false }
  }
  Script disablelastaccess {
    GetScript = "@{ disablelastaccess = $true }"
    SetScript = {
      $outfile = ('{0}\log\{1}.fsutil.disablelastaccess.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      $errfile = ('{0}\log\{1}.fsutil.disablelastaccess.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Process 'fsutil' -ArgumentList @('behavior', 'set', 'disablelastaccess', '1') -Wait -NoNewWindow -PassThru -RedirectStandardOutput $outfile -RedirectStandardError $errfile
    }
    TestScript = { return $false }
  }
}