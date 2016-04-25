function Run-RemoteDesiredStateConfig {
  param (
    [string] $url
  )
  # terminate any running dsc process
  $dscpid = (Get-WmiObject msft_providers | ? {$_.provider -like 'dsccore'} | Select-Object -ExpandProperty HostProcessIdentifier)
  if ($dscpid) {
    Get-Process -Id $dscpid | Stop-Process -f
  }
  $config = [IO.Path]::GetFileNameWithoutExtension($url)
  $target = ('{0}\{1}.ps1' -f $env:Temp, $config)
  (New-Object Net.WebClient).DownloadFile(('{0}?{1}' -f $url, [Guid]::NewGuid()), $target)
  Unblock-File -Path $target
  . $target
  $mof = ('{0}\{1}' -f $env:Temp, $config)
  Invoke-Expression "$config -OutputPath $mof"
  Start-DscConfiguration -Path "$mof" -Wait -Verbose -Force
}
$logFile = ('{0}\log\{1}.userdata-run.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
if ((Get-WmiObject Win32_ComputerSystem).AutomaticManagedPagefile -or @(Get-WmiObject win32_pagefilesetting).length) {
  $sys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
  $sys.AutomaticManagedPagefile = $False
  $sys.Put()
  Get-WmiObject Win32_PageFileSetting -EnableAllPrivileges | % { $_.Delete() }
  Get-ChildItem -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches' | % {
    Set-ItemProperty -path $_.Name.Replace('HKEY_LOCAL_MACHINE', 'HKLM:') -name StateFlags0012 -type DWORD -Value 2
  }
  & shutdown @('-r', '-t', '0', '-c', 'Pagefiles disabled', '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
} else {
  $url = 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata'
  $configs = @(
    'DiskConfig',
    'SpotConfig'
  )
  Start-Transcript -Path $logFile -Append
  foreach ($config in $configs) {
    Run-RemoteDesiredStateConfig -url ('{0}/{1}.ps1' -f $url, $config)
  }
  Stop-Transcript
  if (((Get-Content $logFile) | % { $_ -match 'A reboot is required to progress further' }) -contains $true) {
    & shutdown @('-r', '-t', '0', '-c', 'Userdata reboot required', '-f', '-d', 'p:4:1')
  } else {
    Run-RemoteDesiredStateConfig -url ('{0}/MaintenanceConfig.ps1' -f $url)
  }
}
