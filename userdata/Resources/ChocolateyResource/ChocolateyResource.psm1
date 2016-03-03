function Get-TargetResource {
  param (
    [ValidateSet("present","absent")]
    [string] $ensure,

    [parameter(Mandatory = $true)]
    [string] $package,

    [string] $version
  )
  $res = @{}
  if (Test-Path $chocolateyPath) {
    $res += @{ IsChocolateyInstalled = $true }
    $versionInfo = & $chocolateyPath @('list', "$package", '-lo')
    if ($versionInfo -match '0 packages installed') {
      $res += @{ IsInstalled = $false }
    } else {
      $res += @{ IsInstalled = $true }
      $res += @{ Version = $versionInfo.found }
    }
  } else {
    $res += @{ IsChocolateyInstalled = $false }
  }
  return $res
}

function Test-TargetResource {
  param (
    [ValidateSet("present","absent")]
    [string] $ensure,

    [parameter(Mandatory = $true)]
    [string] $package,

    [string] $version
  )
  $currentState = Get-TargetResource @PSBoundParameters
  if (!($currentState.IsChocolateyInstalled)) {
    Write-Verbose "Chocolatey is not installed"
    return $false
  }
  if ($ensure -ieq "present" -and $currentState.IsInstalled) {
    Write-Verbose "Package is already installed"
    return $true
  }
  if ($ensure -ieq "absent" -and !($currentState.IsInstalled)) {
    Write-Verbose "Package is already not installed"
    return $true
  }
  return $false
}

function Set-TargetResource {
  param (
    [ValidateSet("present","absent")]
    [string] $ensure,

    [parameter(Mandatory = $true)]
    [string] $package,

    [string] $version
  )
  $currentState = Get-TargetResource @PSBoundParameters
  if (!($currentState.IsChocolateyInstalled)) {
    Write-Verbose "ChocolateyResource: Before _installChocolatey"
    _installChocolatey
    Write-Verbose "ChocolateyResource: After _installChocolatey"
  }
  if ($ensure -ieq "present") {
    Write-Verbose "ChocolateyResource: Before installing Chocolatey package"
    & 'choco' @('install', '-y', '--force', $package, '--version', $version)  | Select-WriteHost | Out-Null
    Write-Verbose "ChocolateyResource: After installing Chocolatey package"
  } else {
    & $chocolateyPath @('uninstall', '-y', '--force', $package) | Select-WriteHost | Out-Null
  }
}

function _installChocolatey {
  Write-Verbose "Installing Chocolatey"
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Select-WriteHost | Out-Null
}

function Select-WriteHost {
  [CmdletBinding(DefaultParameterSetName = 'FromPipeline')]
  param (
    [Parameter(ValueFromPipeline = $true, ParameterSetName = 'FromPipeline')]
    [object] $InputObject,
   
    [Parameter(Mandatory = $true, ParameterSetName = 'FromScriptblock', Position = 0)]
    [ScriptBlock] $ScriptBlock,
   
    [switch] $Quiet
  )
  begin {
    function Cleanup {
      remove-item function:write-host -ea 0
    }

    function ReplaceWriteHost([switch] $Quiet, [string] $Scope) {
      $metaData = New-Object System.Management.Automation.CommandMetaData (Get-Command 'Microsoft.PowerShell.Utility\Write-Host')
      $proxy = [System.Management.Automation.ProxyCommand]::create($metaData)
      $content = if ($quiet) {
        $proxy -replace '(?s)\bbegin\b.+', '$Object'
      } else {
        $proxy -replace '($steppablePipeline.Process)', '$Object; $1'
      }
      Invoke-Expression "function ${scope}:Write-Host { $content }"
    }
 
    Cleanup
    if($pscmdlet.ParameterSetName -eq 'FromPipeline') {
      ReplaceWriteHost -Quiet:$quiet -Scope 'global'
    }
  }
  process {
    if ($pscmdlet.ParameterSetName -eq 'FromScriptBlock') {
      . ReplaceWriteHost -Quiet:$quiet -Scope 'local'
      & $scriptblock
    } else {
      $InputObject
    }
  }
  end {
    Cleanup
  }  
}

if ($env:ChocolateyInstall) {
  $chocolateyPath = "$env:ChocolateyInstall\choco.exe"
} else {
  $chocolateyPath = "$env:ProgramData\chocolatey\choco.exe"
}
