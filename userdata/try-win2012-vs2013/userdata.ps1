function Run-DesiredStateConfig {
  param (
    [string] $url
  )
  $config = [IO.Path]::GetFileNameWithoutExtension($url)
  $target = ('{0}\{1}.ps1' -f $env:Temp, $config)
  (New-Object Net.WebClient).DownloadFile($url, $target)
  Unblock-File -Path $target
  . $target
  $mof = ('{0}\{1}' -f $env:Temp, $config)
  New-Item -ItemType Directory -Force -Path $mof
  & $config @('-OutputPath', $mof)
  Start-DscConfiguration -Path $mof -Wait -Verbose -Force
}

$configs = @(
  'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/try-win2012-vs2013/ResourceConfig.ps1',
  'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/try-win2012-vs2013/ServiceConfig.ps1',
  'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/try-win2012-vs2013/FeatureConfig.ps1',
  'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/try-win2012-vs2013/SoftwareConfig.ps1'
)
foreach ($config in $configs) {
  Run-DesiredStateConfig -url $config
}