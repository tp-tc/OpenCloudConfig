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
$url = 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata'
$configs = @(
  'FeatureConfig',
  'ResourceConfig',
  'Software/SublimeText3Config',
  'Software/VisualStudio2013Config',
  'Software/CompilerToolChainConfig',
  'Software/TaskClusterToolChainConfig',
  'Software/MaintenanceToolChainConfig',
  'ServiceConfig'
)
foreach ($config in $configs) {
  Run-RemoteDesiredStateConfig -url ('{0}/{1}.ps1' -f $url, $config)
}