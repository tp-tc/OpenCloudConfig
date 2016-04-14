Configuration ImportCloudToolsAmiConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  $users = @('cltbld')
  foreach ($user in $users) {
    Script ('UserLogoff-{0}' -f $user) {
      GetScript = { @{ Result = $false } }
      SetScript = {
        Get-WmiObject win32_process | ? { $_.user -eq 'root' }
        Get-WmiObject win32_process | ? { $_.user -eq $using:user }
        Start-Process 'logoff' -ArgumentList @((((quser /server:. | ? { $_ -match $using:user }) -split ' +')[2]), '/server:.') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-{2}-logoff.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:user) -RedirectStandardError ('{0}\log\{1}.net-user-{2}-logoff.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:user)
      }
      TestScript = { $false }
    }
    Log ('LogUserLogoff-{0}' -f $user) {
      DependsOn = ('[Script]UserLogoff-{0}' -f $user)
      Message = ('User: {0}, logged off' -f $user)
    }
    Script ('UserDelete-{0}' -f $user) {
      GetScript = { @{ Result = (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq $using:user })) } }
      SetScript = {
        Start-Process 'net' -ArgumentList @('user', $using:user, '/DELETE') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-{2}-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:user) -RedirectStandardError ('{0}\log\{1}.net-user-{2}-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:user)
      }
      TestScript = { if (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq $using:user })) { $true } else { $false } }
    }
    Log ('LogUserDelete-{0}' -f $user) {
      DependsOn = ('[Script]UserDelete-{0}' -f $user)
      Message = ('User: {0}, deleted' -f $user)
    }
  }

  $paths = @(
    ('{0}\etc' -f $env:SystemDrive),
    ('{0}\opt' -f $env:SystemDrive),
    ('{0}\mozilla-buildbuildbotve' -f $env:SystemDrive),
    ('{0}\mozilla-buildpython27' -f $env:SystemDrive),
    ('{0}\PuppetLabs' -f $env:ProgramData),
    ('{0}\puppetagain' -f $env:ProgramData),
    ('{0}\installersource' -f $env:SystemDrive),
    ('{0}\Users\cltbld' -f $env:SystemDrive)
  )
  foreach ($path in $paths) {
    Script ('PathDelete-{0}' -f $path.Replace(':', '').Replace('\', '_')) {
      GetScript = { @{ Result = (-not (Test-Path -Path $using:path -ErrorAction SilentlyContinue)) } }
      SetScript = {
        try {
          Remove-Item $using:path -Confirm:$false -force
        } catch {
          Start-Process ('icacls' -f ${env:ProgramFiles(x86)}) -ArgumentList @($using:path, '/grant', ('{0}:(OI)(CI)F' -f $env:Username), '/inheritance:r') -Wait -NoNewWindow -PassThru | Out-Null
          Remove-Item $using:path -Confirm:$false -force
        }
      }
      TestScript = { if (-not (Test-Path -Path $using:path -ErrorAction SilentlyContinue)) { $true } else { $false } }
    }
    Log ('LogPathDelete-{0}' -f $path.Replace(':', '').Replace('\', '_')) {
      DependsOn = ('[Script]PathDelete-{0}' -f $path.Replace(':', '').Replace('\', '_'))
      Message = ('Path: {0}, deleted' -f $path)
    }
  }

  $services = @(
    'KTS',
    'uvnc_service'
  )
  foreach ($service in $services) {
    Script ('ServiceDelete-{0}' -f $service.Replace(' ', '_')) {
      GetScript = { @{ Result = (-not (Get-Service -Name $using:service -ErrorAction SilentlyContinue)) } }
      SetScript = {
        Get-Service -Name $using:service | Stop-Service -PassThru
        $service = Get-WmiObject -Class Win32_Service -Filter "Name='$using:service'"
        $service.delete()
      }
      TestScript = { if (-not (Get-Service -Name $using:service -ErrorAction SilentlyContinue)) { $true } else { $false } }
    }
    Log ('LogServiceDelete-{0}' -f $service.Replace(' ', '_')) {
      DependsOn = ('[Script]ServiceDelete-{0}' -f $service.Replace(' ', '_'))
      Message = ('Service: {0}, deleted' -f $service)
    }
  }

  Script MercurialDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\Mercurial-3.7.3-x64.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://mercurial-scm.org/release/windows/Mercurial-3.7.3-x64.exe', ('{0}\Temp\Mercurial-3.7.3-x64.exe' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\Mercurial-3.7.3-x64.exe' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\Mercurial-3.7.3-x64.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script MercurialInstall {
    DependsOn = @('[Script]MercurialDownload', '[File]LogFolder')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Mercurial\hg.exe' -f $env:ProgramFiles) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\Temp\Mercurial-3.7.3-x64.exe' -f $env:SystemRoot) -ArgumentList '/VERYSILENT' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.Mercurial-3.7.3-x64.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.Mercurial-3.7.3-x64.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (Test-Path -Path ('{0}\Mercurial\hg.exe' -f $env:ProgramFiles) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script MercurialSymbolicLink {
    DependsOn = @('[Script]MercurialInstall')
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\mozilla-build\hg' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\mozilla-build\hg' -f $env:SystemDrive)).Attributes.ToString() -match "ReparsePoint")) } }
    SetScript = {
      if (Test-Path -Path ('{0}\mozilla-build\hg' -f $env:SystemDrive) -ErrorAction SilentlyContinue) {
        Remove-Item ('{0}\mozilla-build\hg' -f $env:SystemDrive) -Confirm:$false -recurse -force
      }
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\mozilla-build' -f $env:SystemDrive) -Name 'hg' -Target ('{0}\Mercurial' -f $env:ProgramFiles)
      } else {
        & cmd @('/c', 'mklink', '/D', ('{0}\mozilla-build\hg' -f $env:SystemDrive), ('{0}\Mercurial' -f $env:ProgramFiles))
      }
    }
    TestScript = { if ((Test-Path -Path ('{0}\mozilla-build\hg' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\mozilla-build\hg' -f $env:SystemDrive)).Attributes.ToString() -match "ReparsePoint")) { $true } else { $false } }
  }
  Script MercurialConfigure {
    DependsOn = '[Script]MercurialSymbolicLink'
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\mozilla-build\hg\hgrc.d\cacert.pem' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/Mercurial/mercurial.ini', ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive)
    }
    TestScript = { if ((Test-Path -Path ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\mozilla-build\hg\hgrc.d\cacert.pem' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
}