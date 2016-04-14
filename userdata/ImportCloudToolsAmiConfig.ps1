Configuration ImportCloudToolsAmiConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  Script CltbldUserRemove {
    GetScript = { @{ Result = (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' })) } }
    SetScript = {
      Start-Process 'net' -ArgumentList @('user', 'cltbld', '/DELETE') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-cltbld-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.net-user-cltbld-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (-not (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' })) { $true } else { $false } }
  }
  $paths = @(
    ('{0}\etc' -f $env:SystemDrive),
    ('{0}\opt' -f $env:SystemDrive),
    ('{0}\PuppetLabs' -f $env:ProgramData),
    ('{0}\puppetagain' -f $env:ProgramData),
    ('{0}\installersource' -f $env:SystemDrive),
    ('{0}\Users\cltbld' -f $env:SystemDrive)
  )
  foreach ($path in $paths) {
    Script ('PathRemove-{0}' -f $path.Replace(':', '').Replace('\', '_')) {
      GetScript = { @{ Result = (-not (Test-Path -Path $path -ErrorAction SilentlyContinue)) } }
      SetScript = { Remove-Item $path -Recurse -Confirm:$false -force }
      TestScript = { if (-not (Test-Path -Path $path -ErrorAction SilentlyContinue)) { $true } else { $false } }
    }
  }
}
