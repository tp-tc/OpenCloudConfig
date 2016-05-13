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
function Send-ZippedLogs {
  param (
    # todo: move all this config somewhere sensible
    [string] $to = 'releng-puppet-mail@mozilla.com',
    [string] $from = 'releng-puppet-mail@mozilla.com',
    [string] $subject = ('UserData Run Report for TaskCluster worker: {0}' -f $env:ComputerName),
    [string] $smtpServer = 'email-smtp.us-east-1.amazonaws.com',
    [int] $smtpPort = 2587,
    [string] $smtpUsername = 'AKIAIPJEOD57YDLBF35Q'
  )
  Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.Length -eq 0 } | % { Remove-Item -Path $_.FullName -Force }
  $logFile = (Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.userdata-run.log') } | Sort-Object LastAccessTime -Descending | Select-Object -First 1).FullName
  Start-Process ('{0}\7-Zip\7z.exe' -f $env:ProgramFiles) -ArgumentList @('a', $logFile.Replace('.log', '.zip'), ('{0}\log\*.log' -f $env:SystemDrive)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.zip-logs.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.zip-logs.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  try {
    # at ami creation smtp password is in userdata
    $smtpPassword = [regex]::matches((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data'), '(?s)<smtpPassword>(.*)</smtpPassword>').Groups[1].Value
  }
  catch {
    try {
      # provisioned instances contain no userdata (yet)
      (New-Object Net.WebClient).DownloadFile('https://github.com/MozRelOps/OpenCloudConfig/blob/master/userdata/Configuration/smtp.pass.gpg?raw=true', ('{0}\Temp\smtp.pass.gpg' -f $env:SystemRoot))
      # todo: lose the temp file
      Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('-d', ('{0}\Temp\smtp.pass.gpg' -f $env:SystemRoot)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\Temp\smtp.pass' -f $env:SystemRoot) -RedirectStandardError ('{0}\log\{1}.gpg-decrypt.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      $smtpPassword = Get-Content ('{0}\Temp\smtp.pass' -f $env:SystemRoot)
      Remove-Item -Path ('{0}\Temp\smtp.pass' -f $env:SystemRoot) -Force
      Remove-Item -Path ('{0}\Temp\smtp.pass.gpg' -f $env:SystemRoot) -Force
    }
    catch {
      $smtpPassword = $null
    }
  }
  if (-not ([string]::IsNullOrWhiteSpace($smtpPassword))) {
    $credential = New-Object Management.Automation.PSCredential $smtpUsername, (ConvertTo-SecureString "$smtpPassword" -AsPlainText -Force)
    $attachments = @($logFile.Replace('.log', '.zip'))
    $body = (Get-Content -Path @(Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.userdata-run.log') } | Sort-Object LastAccessTime | % { $_.FullName })) -join "`n"
    Send-MailMessage -To $to -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -From $from -Attachments $attachments -UseSsl -Credential $credential
  }
  Remove-Item -Path ('{0}\log\*.log' -f $env:SystemDrive) -Force
}

# set up a log folder, an execution policy that enables the dsc run and a winrm envelope size large enough for the dynamic dsc.
$logFile = ('{0}\log\{1}.userdata-run.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
New-Item -ItemType Directory -Force -Path ('{0}\log' -f $env:SystemDrive)
Set-ExecutionPolicy RemoteSigned -force | Tee-Object -filePath $logFile -append
& winrm @('set', 'winrm/config', '@{MaxEnvelopeSizekb="8192"}')

# install latest powershell from chocolatey if we don't have a recent version (required by DSC) (requires reboot)
if ($PSVersionTable.PSVersion.Major -lt 4) {
  Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Tee-Object -filePath $logFile -append
  & choco @('upgrade', 'powershell', '-y') | Out-File -filePath $logFile -append
  & shutdown @('-r', '-t', '0', '-c', 'Powershell upgraded', '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
}
# run dsc
else {
  Start-Transcript -Path $logFile -Append
  Run-RemoteDesiredStateConfig -url 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/DynamicConfig.ps1'
  Stop-Transcript
  if (((Get-Content $logFile) | % { (($_ -match 'requires a reboot') -or ($_ -match 'reboot required')) }) -contains $true) {
    & shutdown @('-r', '-t', '0', '-c', 'Userdata reboot required', '-f', '-d', 'p:4:1')
  } else {
    Send-ZippedLogs
    if ((Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { $_.Name.EndsWith('.userdata-run.zip') }).Count -eq 1) {
      & shutdown @('-s', '-t', '0', '-c', 'Userdata run complete', '-f', '-d', 'p:4:1')
    }
  }
}
