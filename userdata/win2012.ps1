function Run-RemoteDesiredStateConfig {
  param (
    [string] $url
  )
  $config = [IO.Path]::GetFileNameWithoutExtension($url)
  $target = ('{0}\{1}.ps1' -f $env:Temp, $config)
  (New-Object Net.WebClient).DownloadFile($url, $target)
  Unblock-File -Path $target
  . $target
  $mof = ('{0}\{1}' -f $env:Temp, $config)
  Invoke-Expression "$config -OutputPath $mof"
  Start-DscConfiguration -Path "$mof" -Wait -Verbose -Force
}
$logFile = ('{0}\log\{1}.userdata-run.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
New-Item -ItemType Directory -Force -Path ('{0}\log' -f $env:SystemDrive)
Set-ExecutionPolicy RemoteSigned -force | Tee-Object -filePath $logFile -append
if ($PSVersionTable.PSVersion.Major -lt 4) {
  Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Tee-Object -filePath $logFile -append
  & choco @('upgrade', 'powershell', '-y') | Out-File -filePath $logFile -append
  & shutdown @('-r', '-t', '0', '-c', 'Powershell upgraded', '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
} else {
  $url = 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata'
  $configs = @(
    'ResourceConfig',
    'UserConfig',
    'Software/MaintenanceToolChainConfig',
    'FeatureConfig',
    'Software/CompilerToolChainConfig',
    'Software/TaskClusterToolChainConfig',
    'ServiceConfig',
    'RegistryConfig'
  )
  Start-Transcript -Path $logFile -Append
  foreach ($config in $configs) {
    Run-RemoteDesiredStateConfig -url ('{0}/{1}.ps1' -f $url, $config)
  }
  Stop-Transcript
  Run-RemoteDesiredStateConfig -url ('{0}/MaintenanceConfig.ps1' -f $url)
  if ((Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { $_.Name.EndsWith('.userdata-run.zip') }).Count -eq 1) {
    & shutdown @('-s', '-t', '0', '-c', 'Userdata run complete', '-f', '-d', 'p:4:1')
  }
}
