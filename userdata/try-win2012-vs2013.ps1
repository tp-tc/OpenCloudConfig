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
function Send-Log {
  param (
    [string] $logfile,
    [string] $subject,
    [string[]] $attachments = $null,
    [string] $to = 'releng-puppet-mail@mozilla.com',
    [string] $from = ('{0}@{1}.{2}' -f $env:USERNAME, $env:COMPUTERNAME, $env:USERDOMAIN),
    [string] $smtpServer = 'smtp.mail.scl3.mozilla.com'
  )
  if (Test-Path $logfile) {
    Send-MailMessage -To $to -Subject $subject -Body ([IO.File]::ReadAllText($logfile)) -SmtpServer $smtpServer -From $from -Attachments $attachments
  } else {
    Write-Log -message ("{0} :: skipping log mail, file: {1} not found" -f $($MyInvocation.MyCommand.Name), $logfile) -severity 'WARN'
  }
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
  Start-Transcript -Path $logFile -Append
  foreach ($config in $configs) {
    Run-RemoteDesiredStateConfig -url ('{0}/{1}.ps1' -f $url, $config)
  }
  Stop-Transcript
}
Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) -include '*.log' | Where-Object { !$_.PSIsContainer -and $_.Length -eq 0 } | % {
  Remove-Item -Path $_.FullName -Force
}
& ('{0}\7-Zip\7z.exe' -f $env:ProgramFiles) @('a', $logFile.Replace('.log', '.zip'), ('{0}\log\*.log' -f $env:SystemDrive))
Send-Log -logfile $logFile -subject ('UserData Run Report for TaskCluster worker: {0}' -f $env:ComputerName) -attachments @($logFile.Replace('.log', '.zip'))
Remove-Item -Path ('{0}\log\*.log' -f $env:SystemDrive) -Force