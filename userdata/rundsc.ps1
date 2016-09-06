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
function Remove-LegacyStuff {
  param (
    [string[]] $users = @(
      'cltbld',
      'GenericWorker'
    ),
    [string[]] $paths = @(
      ('{0}\default_browser' -f $env:SystemDrive),
      ('{0}\etc' -f $env:SystemDrive),
      ('{0}\generic-worker' -f $env:SystemDrive),
      ('{0}\gpo_files' -f $env:SystemDrive),
      ('{0}\inetpub' -f $env:SystemDrive),
      ('{0}\installersource' -f $env:SystemDrive),
      ('{0}\installservice.bat' -f $env:SystemDrive),
      ('{0}\log\*.zip' -f $env:SystemDrive),
      ('{0}\mozilla-build-bak' -f $env:SystemDrive),
      ('{0}\mozilla-buildbuildbotve' -f $env:SystemDrive),
      ('{0}\mozilla-buildpython27' -f $env:SystemDrive),
      ('{0}\opt' -f $env:SystemDrive),
      ('{0}\opt.zip' -f $env:SystemDrive),
      ('{0}\Puppet Labs' -f $env:ProgramFiles),
      ('{0}\PuppetLabs' -f $env:ProgramData),
      ('{0}\puppetagain' -f $env:ProgramData),
      ('{0}\quickedit' -f $env:SystemDrive),
      ('{0}\slave' -f $env:SystemDrive),
      ('{0}\sys-scripts' -f $env:SystemDrive),
      ('{0}\timeset.bat' -f $env:SystemDrive),
      ('{0}\updateservice' -f $env:SystemDrive),
      ('{0}\Users\Administrator\Desktop\TESTER RUNNER' -f $env:SystemDrive),
      ('{0}\Users\Administrator\Desktop\PyYAML-3.11' -f $env:SystemDrive),
      ('{0}\Users\Administrator\Desktop\PyYAML-3.11.zip' -f $env:SystemDrive),
      ('{0}\Users\Public\Desktop\*.lnk' -f $env:SystemDrive),
      ('{0}\Users\root\Desktop\*.reg' -f $env:SystemDrive)
    ),
    [string[]] $services = @(
      'puppet',
      'uvnc_service'
    ),
    [string[]] $scheduledTasks = @(
      'enabel-userdata-execution',
      '"Make sure userdata runs"',
      '"Run Generic Worker on login"',
      'timesync',
      'runner'
    ),
    [hashtable] $registryEntries = @{
      # g-w won't set autologin password if these keys pre-exist
      # https://github.com/taskcluster/generic-worker/blob/fb74177141c39afaa1daae53b6fb2a01edd8f32d/plat_windows.go#L440
      'DefaultUserName' = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon';
      'DefaultPassword' = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon';
      'AutoAdminLogon' = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    }
  )

  # clear the event log
  wevtutil el | % { wevtutil cl $_ }

  # remove scheduled tasks
  foreach ($scheduledTask in $scheduledTasks) {
    try {
      Start-Process 'schtasks.exe' -ArgumentList @('/Delete', '/tn', $scheduledTask, '/F') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.schtask-{2}-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $scheduledTask) -RedirectStandardError ('{0}\log\{1}.schtask-{2}-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $scheduledTask)
    }
    catch {}
  }

  # remove user accounts
  foreach ($user in $users) {
    if (@(Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq $user }).length -gt 0) {
      Start-Process 'logoff' -ArgumentList @((((quser /server:. | ? { $_ -match $user }) -split ' +')[2]), '/server:.') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-{2}-logoff.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $user) -RedirectStandardError ('{0}\log\{1}.net-user-{2}-logoff.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $user)
      Start-Process 'net' -ArgumentList @('user', $user, '/DELETE') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-{2}-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $user) -RedirectStandardError ('{0}\log\{1}.net-user-{2}-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $user)
    }
    if (Test-Path -Path ('{0}\Users\{1}' -f $env:SystemDrive, $user) -ErrorAction SilentlyContinue) {
      Remove-Item ('{0}\Users\{1}' -f $env:SystemDrive, $user) -confirm:$false -recurse:$true -force -ErrorAction SilentlyContinue
    }
  }

  # delete paths
  foreach ($path in $paths) {
    Remove-Item $path -confirm:$false -recurse:$true -force -ErrorAction SilentlyContinue
  }

  # delete old mozilla-build. presence of python27 indicates old mozilla-build
  if (Test-Path -Path ('{0}\mozilla-build\python27' -f $env:SystemDrive) -ErrorAction SilentlyContinue) {
    Remove-Item ('{0}\mozilla-build' -f $env:SystemDrive) -confirm:$false -recurse:$true -force -ErrorAction SilentlyContinue
  }

  # delete services
  foreach ($service in $services) {
    if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
      Get-Service -Name $service | Stop-Service -PassThru
      (Get-WmiObject -Class Win32_Service -Filter "Name='$service'").delete()
    }
  }

  # remove registry entries
  foreach ($name in $registryEntries.Keys) {
    $path = $registryEntries.Item($name)
    $item = (Get-Item -Path $path)
    if (($item -ne $null) -and ($item.GetValue($name) -ne $null)) {
      Remove-ItemProperty -path $path -name $name
    }
  }
}
function Map-DriveLetters {
  param (
    [hashtable] $driveLetterMap = @{
      'D:' = 'Y:';
      'E:' = 'Z:'
    }
  )
  $driveLetterMap.Keys | % {
    $old = $_
    $new = $driveLetterMap.Item($_)
    if (Test-Path -Path ('{0}\' -f $old) -ErrorAction SilentlyContinue) {
      $volume = Get-WmiObject -Class win32_volume -Filter "DriveLetter='$old'"
      if ($null -ne $volume) {
        $volume.DriveLetter = $new
        $volume.Put()
      }
    }
  }
}

# set up a log folder, an execution policy that enables the dsc run and a winrm envelope size large enough for the dynamic dsc.
$logFile = ('{0}\log\{1}.userdata-run.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
New-Item -ItemType Directory -Force -Path ('{0}\log' -f $env:SystemDrive)
Set-ExecutionPolicy RemoteSigned -force | Out-File -filePath $logFile -append
& winrm @('set', 'winrm/config', '@{MaxEnvelopeSizekb="8192"}')

# userdata that contains json, indicates a taskcluster-provisioned worker/spot instance.
# userdata that contains pseudo-xml indicates a base instance or one created during ami generation.
try {
  $isWorker = ((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data')).StartsWith('{')
} catch {
  $isWorker = $false
}

# if importing releng amis, do a little housekeeping
switch -wildcard ((Get-WmiObject -class Win32_OperatingSystem).Caption) {
  'Microsoft Windows 10*' {
    $workerType = 'win10'
    $renameInstance = $true
    if (-not ($isWorker)) {
      Remove-LegacyStuff
    }
    Map-DriveLetters
  }
  'Microsoft Windows 7*' {
    $workerType = 'win7'
    $renameInstance = $true
    if (-not ($isWorker)) {
      Remove-LegacyStuff
    }
    Map-DriveLetters
    # absence of the bat file indicates incomplete install. re-install will fail if the scheduled task pre-exists
    if (-not (Test-Path -Path 'C:\generic-worker\run-generic-worker.bat' -ErrorAction SilentlyContinue)) {
      $scheduledTask = '"Run Generic Worker on login"'
      try {
        Start-Process 'schtasks.exe' -ArgumentList @('/Delete', '/tn', $scheduledTask, '/F') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.schtask-{2}-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $scheduledTask) -RedirectStandardError ('{0}\log\{1}.schtask-{2}-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $scheduledTask)
      }
      catch {}
    }
  }
  default {
    $workerType = 'win2012'
    $renameInstance = $true
  }
}

# install recent powershell (required by DSC) (requires reboot)
if ($PSVersionTable.PSVersion.Major -lt 4) {
  & sc.exe @('config', 'wuauserv', 'start=', 'demand')
  & net @('start', 'wuauserv')
  switch -wildcard ((Get-WmiObject -class Win32_OperatingSystem).Caption) {
    'Microsoft Windows 7*' {
      # install .net 4.5.2
      (New-Object Net.WebClient).DownloadFile('https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe', ('{0}\Temp\NDP452-KB2901907-x86-x64-AllOS-ENU.exe' -f $env:SystemRoot))
      & ('{0}\Temp\NDP452-KB2901907-x86-x64-AllOS-ENU.exe' -f $env:SystemRoot) @('Setup', '/q', '/norestart', '/log', ('{0}\log\{1}.NDP452-KB2901907-x86-x64-AllOS-ENU.exe.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")))
      # install wmf 5
      (New-Object Net.WebClient).DownloadFile('https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win7-KB3134760-x86.msu', ('{0}\Temp\Win7-KB3134760-x86.msu' -f $env:SystemRoot))
      & wusa @(('{0}\Temp\Win7-KB3134760-x86.msu' -f $env:SystemRoot), '/quiet', '/norestart', ('/log:{0}\log\{1}.Win7-KB3134760-x86.msu.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")))
    }
  }
  $rebootReasons += 'powershell upgraded'
}

# rename the instance
$instanceId = ((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id'))
if ($renameInstance -and ([bool]($instanceId)) -and (-not ([System.Net.Dns]::GetHostName() -ieq $instanceId))) {
  [Environment]::SetEnvironmentVariable("COMPUTERNAME", "$instanceId", "Machine")
  $env:COMPUTERNAME = $instanceId
  (Get-WmiObject Win32_ComputerSystem).Rename($instanceId)
  $rebootReasons += 'host renamed'
}

if ($rebootReasons.length) {
  if ($rebootReasons[0] -ne 'powershell upgraded') {
    & shutdown @('-r', '-t', '0', '-c', [string]::Join(', ', $rebootReasons), '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
  }
} else {
  Start-Transcript -Path $logFile -Append
  switch -wildcard ((Get-WmiObject -class Win32_OperatingSystem).Caption) {
    'Microsoft Windows 7*' {
      # set network interface to private (reverted after dsc run) http://www.hurryupandwait.io/blog/fixing-winrm-firewall-exception-rule-not-working-when-internet-connection-type-is-set-to-public
      ([Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}"))).GetNetworkConnections() | % { $_.GetNetwork().SetCategory(1) }
      # this setting persists only for the current session
      Enable-PSRemoting -Force
    }
    default {
      # this setting persists only for the current session
      Enable-PSRemoting -SkipNetworkProfileCheck -Force
    }
  }
  Run-RemoteDesiredStateConfig -url 'https://raw.githubusercontent.com/mozilla-releng/OpenCloudConfig/master/userdata/DynamicConfig.ps1'
  switch -wildcard ((Get-WmiObject -class Win32_OperatingSystem).Caption) {
    'Microsoft Windows 7*' {
      # set network interface to public
      ([Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}"))).GetNetworkConnections() | % { $_.GetNetwork().SetCategory(0) }
    }
  }

  # create a scheduled task to run dsc at startup
  Remove-Item -Path 'C:\dsc' -confirm:$false -recurse:$true -force -ErrorAction SilentlyContinue
  New-Item -Path 'C:\dsc' -ItemType Directory -force
  (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/mozilla-releng/OpenCloudConfig/master/userdata/rundsc.ps1', 'C:\dsc\rundsc.ps1')
  & schtasks @('/create', '/tn', 'RunDesiredStateConfigurationAtStartup', '/sc', 'onstart', '/ru', 'SYSTEM', '/rl', 'HIGHEST', '/tr', 'powershell.exe -File C:\dsc\rundsc.ps1', '/f')

  Stop-Transcript
  if (((Get-Content $logFile) | % { (($_ -match 'requires a reboot') -or ($_ -match 'reboot is required')) }) -contains $true) {
    & shutdown @('-r', '-t', '0', '-c', 'a package installed by dsc requested a restart', '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
  } else {
    # archive dsc logs
    Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.Length -eq 0 } | % { Remove-Item -Path $_.FullName -Force }
    New-ZipFile -ZipFilePath $logFile.Replace('.log', '.zip') -Item @(Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.FullName -ne $logFile } | % { $_.FullName })
    Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.FullName -ne $logFile } | % { Remove-Item -Path $_.FullName -Force }

    if ((-not ($isWorker)) -and ((Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | ? { $_.Name.EndsWith('.userdata-run.zip') }).Count -eq 1) -and (Test-Path -Path 'C:\generic-worker\run-generic-worker.bat' -ErrorAction SilentlyContinue)) {
      & shutdown @('-s', '-t', '0', '-c', 'dsc run complete', '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
    } elseif ($isWorker) {
      if (-not (Test-Path -Path 'Z:\' -ErrorAction SilentlyContinue)) { # if the Z: drive isn't mapped, map it.
        Map-DriveLetters
      }
      if (Test-Path -Path 'C:\generic-worker\run-generic-worker.bat' -ErrorAction SilentlyContinue) {
        Start-Sleep -seconds 30 # give g-w a moment to fire up, if it doesn't, boot loop.
        if ((@(Get-Process | ? { $_.ProcessName -eq 'generic-worker' }).length -eq 0) -and (@(Get-Process | ? { $_.ProcessName -eq 'powershell' }).length -eq 1)) {
          & net @('user', 'GenericWorker', (Get-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -name 'DefaultPassword').DefaultPassword)
          & shutdown @('-r', '-t', '0', '-c', 'reboot to rouse the generic worker', '-f', '-d', 'p:4:1') | Out-File -filePath $logFile -append
        }
      }
    }
  }
}
