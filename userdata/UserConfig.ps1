
Configuration UserConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Script RootUserCreate {
    GetScript = { @{ Result = (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' }) } }
    SetScript = {
      $password = [regex]::matches((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data'), '(?s)<rootPassword>(.*)</rootPassword>').Groups[1].Value
      if (!$password) {
        $password = [Guid]::NewGuid().ToString().Substring(0, 13)
      }
      & net @('user', 'root', $password, '/ADD', '/active:yes', '/expires:never')
      Start-Job -ScriptBlock {
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'QuickEdit' -Value '0x00000001' # on
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'InsertMode' -Value '0x00000001' # on
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'ScreenBufferSize' -Value '0x012c00a0' # 160x300
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'WindowSize' -Value '0x003c00a0' # 160x60
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'HistoryBufferSize' -Value '0x000003e7' # 999 (max)
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'ScreenColors' -Value '0x0000000a' # green on black
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'FontSize' -Value '0x000c0000' # 12
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'FontFamily' -Value '0x00000036' # Consolas
        Set-ItemProperty 'HKCU:\Console\' -Type 'String' -Name 'FaceName' -Value 'Consolas'
        Set-ItemProperty 'HKCU:\Control Panel\Cursors\' -Type 'String' -Name 'IBeam' -Value '%SYSTEMROOT%\Cursors\beam_r.cur'
        ((New-Object -c Shell.Application).Namespace('{0}\system32' -f $env:SystemRoot).parsename('cmd.exe')).InvokeVerb('taskbarpin')
        ((New-Object -c Shell.Application).Namespace('{0}\Sublime Text 3' -f $env:ProgramFiles).parsename('sublime_text.exe')).InvokeVerb('taskbarpin')
      } -Credential (New-Object Management.Automation.PSCredential 'root', (ConvertTo-SecureString "$password" -AsPlainText -Force))
      #& icacls @(('{0}\Users\root' -f $env:SystemDrive), '/T', '/C', '/grant', 'Administrators:(F)')
    }
    TestScript = { if (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' }) { $true } else { $false } }
  }
  Group RootAsAdministrator {
    DependsOn = '[Script]RootUserCreate'
    GroupName = 'Administrators'
    Ensure = 'Present'
    MembersToInclude = 'root'
  }
}
