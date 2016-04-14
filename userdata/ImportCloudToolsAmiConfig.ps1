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
    Script ('UserDelete-{0}' -f $user) {
      GetScript = { @{ Result = (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq $using:user })) } }
      SetScript = {
        Start-Process 'net' -ArgumentList @('user', $using:user, '/DELETE') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-{2}-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:user) -RedirectStandardError ('{0}\log\{1}.net-user-{2}-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $using:user)
      }
      TestScript = { if (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq $using:user })) { $true } else { $false } }
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
    Script ('PathRemove-{0}' -f $path.Replace(':', '').Replace('\', '_')) {
      GetScript = { @{ Result = (-not (Test-Path -Path $using:path -ErrorAction SilentlyContinue)) } }
      SetScript = { Remove-Item $using:path -Confirm:$false -force }
      TestScript = { if (-not (Test-Path -Path $using:path -ErrorAction SilentlyContinue)) { $true } else { $false } }
    }
  }

  $services = @(
    'KTS',
    'uvnc_service'
  )
  foreach ($service in $services) {
    Script ('ServiceRemove-{0}' -f $service.Replace(' ', '_')) {
      GetScript = { @{ Result = (-not (Get-Service -Name $using:service -ErrorAction SilentlyContinue)) } }
      SetScript = {
        Get-Service -Name $using:service | Stop-Service -PassThru
        $service = Get-WmiObject -Class Win32_Service -Filter "Name='$using:service'"
        $service.delete()
      }
      TestScript = { if (-not (Get-Service -Name $using:service -ErrorAction SilentlyContinue)) { $true } else { $false } }
    }
  }

  # todo: handle us-east-1 also
  Script HgFingerprintUpdate {
    GetScript = { @{ Result = (((Get-Content ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive)) | %{ $_ -match '1a:0e:4a:64:90:c1:d0:2f:79:46:95:b5:17:dc:63:45:cf:19:37:bd' }) -contains $true) } }
    SetScript = {
      [IO.File]::WriteAllLines(('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive), ((Get-Content ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive)) | % { $_ -replace 'ad:ab:0d:1e:fe:1c:78:5b:94:f9:76:b2:5a:12:51:9a:12:7b:66:a2','1a:0e:4a:64:90:c1:d0:2f:79:46:95:b5:17:dc:63:45:cf:19:37:bd' }), (New-Object Text.UTF8Encoding($false)))
    }
    TestScript = { if (((Get-Content ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive)) | %{ $_ -match '1a:0e:4a:64:90:c1:d0:2f:79:46:95:b5:17:dc:63:45:cf:19:37:bd' }) -contains $true) { $true } else { $false } }
  }
}