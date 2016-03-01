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
  Invoke-Expression "$config -OutputPath $mof"
  Start-DscConfiguration -Path "$mof" -Wait -Verbose -Force
}
$url = 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/try-win2012-vs2013'
foreach ($config in @('ResourceConfig', 'SoftwareConfig', 'ServiceConfig', 'FeatureConfig')) {
  Run-DesiredStateConfig -url ('{0}/{1}.ps1' -f $url, $config)
}