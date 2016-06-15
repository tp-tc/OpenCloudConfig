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
  $configurationData = @{ AllNodes = @(@{ NodeName = '*'; WorkerType = 'win7gpu' } ) }
  Start-DscConfiguration -ConfigurationData $configurationData -Path "$mof" -Wait -Verbose -Force
}

# set up a log folder, an execution policy that enables the dsc run and a winrm envelope size large enough for the dynamic dsc.
$logFile = ('{0}\log\{1}.userdata-run.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
New-Item -ItemType Directory -Force -Path ('{0}\log' -f $env:SystemDrive)
Set-ExecutionPolicy RemoteSigned -force | Tee-Object -filePath $logFile -append
& winrm @('set', 'winrm/config', '@{MaxEnvelopeSizekb="8192"}')

$rebootReasons = @()
# install latest powershell from chocolatey if we don't have a recent version (required by DSC) (requires reboot)
if ($PSVersionTable.PSVersion.Major -lt 4) {
  Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Tee-Object -filePath $logFile -append
  & choco @('upgrade', 'powershell', '-y') | Out-File -filePath $logFile -append
  $rebootReasons += 'powershell upgraded'
}
$hostname = ((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id'))
if ((-not ([string]::IsNullOrWhiteSpace($hostname))) -and (-not ([System.Net.Dns]::GetHostName() -ieq $hostname))) {
  (Get-WmiObject Win32_ComputerSystem).Rename($hostname)
  $rebootReasons += 'host renamed'
}
# blow away any paging files we find, they reduce performance on ec2 instances with plenty of RAM (requires reboot, if found). if they're on the ephemeral disks, they also prevent us from raid striping.
#if ((Get-WmiObject Win32_ComputerSystem).AutomaticManagedPagefile -or @(Get-WmiObject Win32_PageFileSetting).length) {
#  $sys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
#  $sys.AutomaticManagedPagefile = $false
#  $sys.Put()
#  Get-WmiObject Win32_PageFileSetting -EnableAllPrivileges | % { $_.Delete() }
#  Get-ChildItem -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches' | % { Set-ItemProperty -path $_.Name.Replace('HKEY_LOCAL_MACHINE', 'HKLM:') -name StateFlags0012 -type DWORD -Value 2 }
#  $rebootReasons += 'pagefile(s) removed'
#}
if($rebootReasons.length) {
  & shutdown @('-r', '-t', '0', '-c', [string]::Join(', ', $rebootReasons), '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
} else {
  Start-Transcript -Path $logFile -Append
  Run-RemoteDesiredStateConfig -url 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/DynamicConfig.ps1'
  Stop-Transcript
  if (((Get-Content $logFile) | % { (($_ -match 'requires a reboot') -or ($_ -match 'reboot is required')) }) -contains $true) {
    & shutdown @('-r', '-t', '0', '-c', 'a package installed by dsc requested a restart', '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
  } else {
    # symlink mercurial to ec2 region config. todo: find a way to do this in the manifest (cmd)
    $hgini = 'C:\mozilla-build\python\Scripts\mercurial.ini'
    if (Test-Path -Path $hgini -ErrorAction SilentlyContinue) {
      & del $hgini # use cmd del (not ps remove-item) here in order to preserve targets
    }
    & cmd @('/c', 'mklink', $hgini, ($hgini.Replace('.ini', ('.{0}.ini' -f ((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/placement/availability-zone') -replace '.$')))))

    if (-not (Get-ScheduledTask -TaskName 'RunDesiredStateConfigurationAtStartup' -ErrorAction SilentlyContinue)) {
      New-Item -ItemType Directory -Force -Path 'C:\dsc'
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/win2012.ps1', 'C:\dsc\win2012.ps1')
      & schtasks @('/create', '/tn', 'RunDesiredStateConfigurationAtStartup', '/sc', 'onstart', '/ru', 'SYSTEM', '/rl', 'HIGHEST', '/tr', 'powershell.exe -File C:\dsc\win2012.ps1') | Out-File -filePath $logFile -append
    }
    Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.Length -eq 0 } | % { Remove-Item -Path $_.FullName -Force }
    New-ZipFile -ZipFilePath $logFile.Replace('.log', '.zip') -Item @(Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.FullName -ne $logFile } | % { $_.FullName })
    Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.FullName -ne $logFile } | % { Remove-Item -Path $_.FullName -Force }
    if ((Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { $_.Name.EndsWith('.userdata-run.zip') }).Count -eq 1) {
      & shutdown @('-s', '-t', '0', '-c', 'dsc run complete', '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
    } elseif (Test-Path -Path 'C:\generic-worker\run-generic-worker.bat' -ErrorAction SilentlyContinue) {
      Start-Sleep -seconds 30 # give g-w a moment to fire up, if it doesn't, boot loop.
      if (@(Get-Process | ? { $_.ProcessName -eq 'generic-worker' }).length -eq 0) {
        & shutdown @('-r', '-t', '0', '-c', 'starting generic worker', '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
      }
    }
  }
}
