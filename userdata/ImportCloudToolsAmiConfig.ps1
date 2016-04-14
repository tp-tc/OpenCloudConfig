Configuration ImportCloudToolsAmiConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  Script CltbldUserRemove {
    GetScript = { @{ Result = (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' })) } }
    SetScript = {
      Start-Process 'net' -ArgumentList @('user', 'cltbld', '/DELETE') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-cltbld-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.net-user-cltbld-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' })) { $true } else { $false } }
  }
  File CltbldUserFolderRemove {
    Type = 'Directory'
    DestinationPath = ('{0}\Users\cltbld' -f $env:SystemDrive)
    Ensure = 'Absent'
    Force = $true
  }
  File OptFolderRemove {
    Type = 'Directory'
    DestinationPath = ('{0}\opt' -f $env:SystemDrive)
    Ensure = 'Absent'
    Force = $true
  }
  File EtcFolderRemove {
    Type = 'Directory'
    DestinationPath = ('{0}\etc' -f $env:SystemDrive)
    Ensure = 'Absent'
    Force = $true
  }
  Service PuppetServiceRemove {
    Name = 'puppet'
    Ensure = 'Absent'
    Force = $true
  }
  File PuppetLabsRemove {
    Type = 'Directory'
    DestinationPath = ('{0}\PuppetLabs' -f $env:ProgramData)
    Ensure = 'Absent'
    Force = $true
  }
  File PuppetAgainRemove {
    Type = 'Directory'
    DestinationPath = ('{0}\puppetagain' -f $env:ProgramData)
    Ensure = 'Absent'
    Force = $true
  }
  File InstallerSourceRemove {
    Type = 'Directory'
    DestinationPath = ('{0}\installersource' -f $env:SystemDrive)
    Ensure = 'Absent'
    Force = $true
  }
}
