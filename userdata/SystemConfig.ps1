Configuration SystemConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Script HostnameSet {
    GetScript = { @{ Result = (([Net.Dns]::GetHostName() -ieq (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id')) -and ($env:COMPUTERNAME -ieq (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id'))) } }
    SetScript = {
      $env:COMPUTERNAME = (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id')
      [Environment]::SetEnvironmentVariable("COMPUTERNAME", $env:COMPUTERNAME, "Machine")
      (Get-WmiObject Win32_ComputerSystem).Rename($env:COMPUTERNAME)
    }
    TestScript = { if (([Net.Dns]::GetHostName() -ieq (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id')) -and ($env:COMPUTERNAME -ieq (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id'))) { $true } else { $false } }
  }
}