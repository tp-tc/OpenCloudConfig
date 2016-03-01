
# ResourceConfig downloads and installs custom Desired State Configuration (DSC) resources which are not included in vanilla Windows installs or AMIs
Configuration ResourceConfig {
  Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = "Present"
  }
  Script ResourceInstall {
    GetScript = {
      @{
        Result = $false
      }
    }
    SetScript = {
      foreach ($resource in @('ChocolateyResource')) {
        $path = ('{0}\System32\WindowsPowerShell\v1.0\Modules\PSDesiredStateConfiguration\DSCResources\{1}' -f $env:SystemRoot, $resource)
        if (!(Test-Path $path -PathType Container)) {
          New-Item $path -type directory -force
        }
        foreach ($ext in @('psd1', 'psm1', 'schema.mof')) {
          $source = ('https://raw.githubusercontent.com/MozRelOps/powershell-utilities/master/dsc/resources/{0}/{0}.{1}' -f $resource, $ext)
          $target = ('{0}\{1}.{2}' -f $path, $resource, $ext)
          (New-Object Net.WebClient).DownloadFile($source, $target)
          Unblock-File -Path $target
        }
      }
    }
    TestScript = {
      $false
    }
  }
}
