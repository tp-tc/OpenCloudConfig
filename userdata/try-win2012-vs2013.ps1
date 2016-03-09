function Run-RemoteDesiredStateConfig {
  param (
    [string] $url,
    [string] $log
  )
  $config = [IO.Path]::GetFileNameWithoutExtension($url)
  $target = ('{0}\{1}.ps1' -f $env:Temp, $config)
  (New-Object Net.WebClient).DownloadFile($url, $target)
  Unblock-File -Path $target
  . $target
  $mof = ('{0}\{1}' -f $env:Temp, $config)
  Invoke-Expression "$config -OutputPath $mof"
  Start-DscConfiguration -Path "$mof" -Wait -Verbose -Force | Tee-Object -filePath $log -append
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
    'Software/MaintenanceToolChainConfig',
    'Software/VisualStudio2013Config',
    'FeatureConfig',
    'Software/CompilerToolChainConfig',
    'Software/TaskClusterToolChainConfig',
    'ServiceConfig'
  )
  foreach ($config in $configs) {
    Run-RemoteDesiredStateConfig -url ('{0}/{1}.ps1' -f $url, $config) -log $logFile | Tee-Object -filePath $logFile -append
  }
}
