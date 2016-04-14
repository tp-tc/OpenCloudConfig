Configuration ImportCloudToolsAmiConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  Script CltbldUserRemove {
    GetScript = { @{ Result = (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' })) } }
    SetScript = {
      Start-Process 'logoff' -ArgumentList @((((quser /server:. | ? { $_ -match 'cltbld' }) -split ' +')[2]), '/server:.') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-cltbld-logoff.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.net-user-cltbld-logoff.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Process 'net' -ArgumentList @('user', 'cltbld', '/DELETE') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-cltbld-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.net-user-cltbld-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' })) { $true } else { $false } }
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
}