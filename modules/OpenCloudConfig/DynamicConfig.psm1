<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Invoke-DirectoryCreate {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $path,

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      New-Item -Path $path -ItemType 'directory' -force
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: created directory {2}.' -f  $($MyInvocation.MyCommand.Name), $componentName, $path)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: error creating directory {2}. {3}' -f  $($MyInvocation.MyCommand.Name), $componentName, $path, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-DirectoryCreate {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $path,

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      $result = (Test-Path -Path $path -PathType 'Container' -ErrorAction SilentlyContinue)
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: directory {2} existence {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $path, $(if ($result) { 'confirmed' } else { 'refuted' }))
    } catch {
      $result = $false
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to confirm or refute directory {2} existence. {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $path, $_.Exception.Message)
    }
    return $result
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-DirectoryDelete {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $path,

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      Remove-Item $path -Confirm:$false -recurse -force
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: deleted directory {2}.' -f  $($MyInvocation.MyCommand.Name), $componentName, $path)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'warn' -message ('{0} ({1}) :: error deleting directory {2}. {3}' -f  $($MyInvocation.MyCommand.Name), $componentName, $path, $_.Exception.Message)
      try {
        Start-Process 'icacls' -ArgumentList @($path, '/grant', ('{0}:(OI)(CI)F' -f $env:Username), '/inheritance:r') -Wait -NoNewWindow -PassThru | Out-Null
        Remove-Item $path -Confirm:$false -recurse -force
      } catch {
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: error resetting permissions or deleting directory ({2}). {3}' -f  $($MyInvocation.MyCommand.Name), $componentName, $path, $_.Exception.Message)
      }
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-DirectoryDelete {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $path,

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      $result = (-not (Test-Path -Path $path -PathType 'Container' -ErrorAction SilentlyContinue))
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: directory {2} absence {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $path, $(if ($result) { 'confirmed' } else { 'refuted' }))
    } catch {
      $result = $false
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to confirm or refute directory {2} absence. {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $path, $_.Exception.Message)
    }
    return $result
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-DirectoryCopy {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $source,

    [Parameter(Mandatory = $true)]
    [string] $target,

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      Copy-Item -Path $source -Destination $target -Container
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: copied directory {2} to {3}.' -f  $($MyInvocation.MyCommand.Name), $componentName, $source, $target)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: error copying directory {2} to {3}. {4}' -f  $($MyInvocation.MyCommand.Name), $componentName, $source, $target, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-DirectoryCopy {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $source,

    [Parameter(Mandatory = $true)]
    [string] $target,

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      # todo: compare folder contents
      $result = (Test-Path -Path $target -PathType 'Container' -ErrorAction SilentlyContinue)
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: directory {2} existence {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $target, $(if ($result) { 'confirmed' } else { 'refuted' }))
    } catch {
      $result = $false
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to confirm or refute directory {2} existence. {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $target, $_.Exception.Message)
    }
    return $result
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-CommandRun {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $command,

    [string[]] $arguments,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    $redirectStandardOutput = ('{0}\log\{1}-{2}-stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), [IO.Path]::GetFileNameWithoutExtension($command))
    $redirectStandardError = ('{0}\log\{1}-{2}-stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), [IO.Path]::GetFileNameWithoutExtension($command))
    try {
      $process = (Start-Process $command -ArgumentList $arguments -NoNewWindow -RedirectStandardOutput $redirectStandardOutput -RedirectStandardError $redirectStandardError -PassThru)
      Wait-Process -InputObject $process # see: https://stackoverflow.com/a/43728914/68115
      if ($process.ExitCode -and $process.TotalProcessorTime) {
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: command ({2} {3}) exited with code: {4} after a processing time of: {5}.' -f $($MyInvocation.MyCommand.Name), $componentName, $command, ($arguments -join ' '), $process.ExitCode, $process.TotalProcessorTime)
      } else {
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: command ({2} {3}) executed.' -f $($MyInvocation.MyCommand.Name), $componentName, $command, ($arguments -join ' '))
      }
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: error executing command ({2} {3}). {4}' -f $($MyInvocation.MyCommand.Name), $componentName, $command, ($arguments -join ' '), $_.Exception.Message)
      $standardErrorFile = (Get-Item -Path $redirectStandardError -ErrorAction SilentlyContinue)
      if (($standardErrorFile) -and $standardErrorFile.Length) {
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: ({2} {3}). {4}' -f $($MyInvocation.MyCommand.Name), $componentName, $command, ($arguments -join ' '), (Get-Content -Path $redirectStandardError -Raw))
      }
    }
    $standardErrorFile = (Get-Item -Path $redirectStandardError -ErrorAction SilentlyContinue)
    if (($standardErrorFile) -and $standardErrorFile.Length) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: ({2} {3}). {4}' -f $($MyInvocation.MyCommand.Name), $componentName, $command, ($arguments -join ' '), (Get-Content -Path $redirectStandardError -Raw))
    }
    $standardOutputFile = (Get-Item -Path $redirectStandardOutput -ErrorAction SilentlyContinue)
    if (($standardOutputFile) -and $standardOutputFile.Length) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: ({2} {3}). log: {4}' -f $($MyInvocation.MyCommand.Name), $componentName, $command, ($arguments -join ' '), $redirectStandardOutput)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-CommandRun {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [string] $validations,

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      $result = (Confirm-All -validations $validations -verbose)
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: {2} validations {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $(if (($validations) -and $validations.Length) { $validations.Length } else { 0 }), $(if ($result) { 'confirmed' } else { 'refuted' }))
    } catch {
      $result = $false
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to confirm or refute {2} validations. {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $(if (($validations) -and $validations.Length) { $validations.Length } else { 0 }), $_.Exception.Message)
    }
    return $result
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-FileDownload {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $localPath,

    [string] $url,

    [string] $sha512,

    [string] $tooltoolHost,

    [string] $tokenPath,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    if (($sha512) -and (Test-Path -Path $tokenPath -ErrorAction SilentlyContinue)) {
      if ((Get-TooltoolResource -localPath $localPath -sha512 $sha512 -tokenPath $tokenPath -tooltoolHost $tooltoolHost -eventLogName $eventLogName -eventLogSource $eventLogSource)) {
        Write-Verbose ('downloaded {0} from tooltool' -f $localPath)
      } else {
        Write-Verbose ('failed to download {0} from tooltool' -f $localPath)
      }
    } else {
      if ((Get-RemoteResource -localPath $localPath -url $url -eventLogSource $eventLogSource)) {
        Write-Verbose ('downloaded {0} from {1}' -f $localPath, $url)
      } else {
        Write-Verbose ('failed to download {0} from {1}' -f $localPath, $url)
      }
    }
    Unblock-File -Path $localPath
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-FileDownload {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $localPath,

    [string] $sha512,

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      $result = ((Test-Path -Path $localPath -PathType 'Leaf' -ErrorAction SilentlyContinue) -and ((-not ($sha512)) -or (((Get-FileHash -Path $localPath -Algorithm 'SHA512').Hash -eq $sha512))))
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: download {2} existence {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $localPath, $(if ($result) { 'confirmed' } else { 'refuted' }))
    } catch {
      $result = $false
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to confirm or refute download {2} existence. {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $localPath, $_.Exception.Message)
    }
    return $result
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-SymbolicLink {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $target,

    [Parameter(Mandatory = $true)]
    [string] $link,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      if (Test-Path -Path $target -PathType Container -ErrorAction SilentlyContinue) {
        & 'cmd' @('/c', 'mklink', '/D', $link, $target)
      } elseif (Test-Path -Path $target -PathType Leaf -ErrorAction SilentlyContinue) {
        & 'cmd' @('/c', 'mklink', $link, $target)
      }
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: created symlink {2} to {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $link, $target)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to create symlink {2} to {3}. {4}' -f $($MyInvocation.MyCommand.Name), $componentName, $link, $target, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-SymbolicLink {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $target,

    [Parameter(Mandatory = $true)]
    [string] $link,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      # todo: check that link points to target (https://stackoverflow.com/a/16926224/68115)
      $result = ((Test-Path -Path $link -ErrorAction SilentlyContinue) -and ((Get-Item $link).Attributes.ToString() -match 'ReparsePoint'))
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: symlink {2} existence {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $link, $(if ($result) { 'confirmed' } else { 'refuted' }))
    } catch {
      $result = $false
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to confirm or refute symlink {2} existence. {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $link, $target, $_.Exception.Message)
    }
    return $result
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-EnvironmentVariableSet {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $name,

    [Parameter(Mandatory = $true)]
    [string] $value,

    [Parameter(Mandatory = $true)]
    [string] $target,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      [Environment]::SetEnvironmentVariable($name, $value, $target)
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: environment variable: {2} set to: {3} for {4}' -f $($MyInvocation.MyCommand.Name), $componentName, $name, $value, $target)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to set environment variable: {2} to: {3} for {4}. {5}' -f $($MyInvocation.MyCommand.Name), $componentName, $name, $value, $target, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-EnvironmentVariableUniqueAppend {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    Invoke-EnvironmentVariableSet -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component.ComponentName -name $component.Name -value (@((@((((Get-ChildItem env: | ? { $_.Name -ieq $component.Name } | Select-Object -first 1).Value) -split ';') | ? { $component.Values -notcontains $_ }) + $component.Values) | Select-Object -Unique) -join ';') -target $component.Target
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-EnvironmentVariableUniquePrepend {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    Invoke-EnvironmentVariableSet -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component.ComponentName -name $component.Name -value (@(($component.Values + @((((Get-ChildItem env: | ? { $_.Name -ieq $component.Name } | Select-Object -first 1).Value) -split ';') | ? { $component.Values -notcontains $_ })) | Select-Object -Unique) -join ';') -target $component.Target
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-RegistryKeySetOwner {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $key,

    [Parameter(Mandatory = $true)]
    [string] $sid,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      $ntdll = Add-Type -Member '[DllImport("ntdll.dll")] public static extern int RtlAdjustPrivilege(ulong a, bool b, bool c, ref bool d);' -Name NtDll -PassThru
      @{ SeTakeOwnership = 9; SeBackup =  17; SeRestore = 18 }.Values | % { $null = $ntdll::RtlAdjustPrivilege($_, 1, 0, [ref]0) }
      $subkey = ($key).Replace(('{0}\' -f ($key).Split('\')[0]), '')
      switch -regex (($key).Split('\')[0]) {
        'HKCU|HKEY_CURRENT_USER' {
          $hive = 'CurrentUser'
        }
        'HKLM|HKEY_LOCAL_MACHINE' {
          $hive = 'LocalMachine'
        }
        'HKCR|HKEY_CLASSES_ROOT' {
          $hive = 'ClassesRoot'
        }
        'HKCC|HKEY_CURRENT_CONFIG' {
          $hive = 'CurrentConfig'
        }
        'HKU|HKEY_USERS' {
          $hive = 'Users'
        }
      }
      $regKey = [Microsoft.Win32.Registry]::$hive.OpenSubKey($subkey, 'ReadWriteSubTree', 'TakeOwnership')
      $acl = New-Object System.Security.AccessControl.RegistrySecurity
      $acl.SetOwner([System.Security.Principal.SecurityIdentifier]$sid)
      $regKey.SetAccessControl($acl)
      $acl.SetAccessRuleProtection($false, $false)
      $regKey.SetAccessControl($acl)
      $regKey = $regKey.OpenSubKey('', 'ReadWriteSubTree', 'ChangePermissions')
      $acl.ResetAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule([System.Security.Principal.SecurityIdentifier]$sid, 'FullControl', @('ObjectInherit', 'ContainerInherit'), 'None', 'Allow')))
      $regKey.SetAccessControl($acl)
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: registry key owner set to: {2} for {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $sid, $key)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to set registry key owner to: {2} for {3}. {4}' -f $($MyInvocation.MyCommand.Name), $componentName,  $sid, $key, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-RegistryKeySet {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $path,

    [Parameter(Mandatory = $true)]
    [string] $valueName,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      New-Item -Path $path -Name $valueName -Force
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: registry key {2} created at {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $valueName, $path)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to create registry key {2} at {3}. {4}' -f $($MyInvocation.MyCommand.Name), $componentName, $valueName, $path, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-RegistryValueSet {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $path,

    [Parameter(Mandatory = $true)]
    [string] $valueName,

    [Parameter(Mandatory = $true)]
    [string] $valueType,

    [Parameter(Mandatory = $true)]
    [string] $valueData,

    [switch] $hex = $false,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    switch -regex (($path).Split('\')[0]) {
      'HKEY_CURRENT_USER' {
        $path = $path.Replace('HKEY_CURRENT_USER\', 'HKCU:\')
      }
      'HKEY_LOCAL_MACHINE' {
        $path = $path.Replace('HKEY_LOCAL_MACHINE\', 'HKLM:\')
      }
      'HKEY_CLASSES_ROOT' {
        $path = $path.Replace('HKEY_CLASSES_ROOT\', 'HKCR:\')
      }
      'HKEY_CURRENT_CONFIG' {
        $path = $path.Replace('HKEY_CURRENT_CONFIG\', 'HKCC:\')
      }
      'HKEY_USERS' {
        $path = $path.Replace('HKEY_USERS\', 'HKU:\')
      }
    }
    try {
      if (-not (Get-Item -Path $path -ErrorAction 'SilentlyContinue')) {
        try {
          New-Item -Path $path -Force
          Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: registry path: {2} created' -f $($MyInvocation.MyCommand.Name), $componentName, $path)
        } catch {
          Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to create registry path {2}. {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $path, $_.Exception.Message)
        }
      } else {
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: registry path: {2} detected' -f $($MyInvocation.MyCommand.Name), $componentName, $path)
      }
      if (Get-ItemProperty -Path $path -Name $valueName -ErrorAction 'SilentlyContinue') {
        Set-ItemProperty -Path $path -Name $valueName -Value $valueData -Force
      } else {
        New-ItemProperty -Path $path -Name $valueName -PropertyType $valueType -Value $valueData -Force
      }
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: registry value set to: [{2}]{3}{4} for key {5} at path {6}' -f $($MyInvocation.MyCommand.Name), $componentName, $valueType, $valueData, $(if ($hex) { '(hex)' } else { '' }), $valueName, $path)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to set registry value to: [{2}]{3}{4} for key {5} at path {6}. {7}' -f $($MyInvocation.MyCommand.Name), $componentName, $valueType, $valueData, $(if ($hex) { '(hex)' } else { '' }), $valueName, $path, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-DisableIndexing {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      # Disable indexing on all disk volumes.
      Get-WmiObject Win32_Volume -Filter "IndexingEnabled=$true" | Set-WmiInstance -Arguments @{IndexingEnabled=$false}
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: indexing disabled' -f $($MyInvocation.MyCommand.Name), $componentName)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed disable indexing. {2}' -f $($MyInvocation.MyCommand.Name), $componentName, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-FirewallRuleSet {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $action,

    [string] $direction,

    [string] $remoteAddress,

    [string] $program,

    [string] $protocol,

    [string] $localPort,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    $dir = $(if ($direction -ieq 'Outbound') { 'out' } else { 'in' })
    if (($protocol) -and ($localPort)) {
      $ruleName = ('{0} ({1} {2} {3}): {4}' -f $componentName, $protocol, $localPort, $direction, $action)
      try {
        if (Get-Command 'New-NetFirewallRule' -errorAction SilentlyContinue) {
          if ($remoteAddress) {
            New-NetFirewallRule -DisplayName $ruleName -Protocol $protocol -LocalPort $localPort -Direction $direction -Action $action -RemoteAddress $remoteAddress
          } else {
            New-NetFirewallRule -DisplayName $ruleName -Protocol $protocol -LocalPort $localPort -Direction $direction -Action $action
          }
        } else {
          if ($remoteAddress) {
            & 'netsh.exe' @('advfirewall', 'firewall', 'add', 'rule', ('name="{0}"' -f $ruleName), ('dir={0}' -f $dir), ('action={0}' -f $action), ('protocol={0}' -f $protocol), ('localport={0}' -f $localPort), ('remoteip={0}' -f $remoteAddress))
          } else {
            & 'netsh.exe' @('advfirewall', 'firewall', 'add', 'rule', ('name="{0}"' -f $ruleName), ('dir={0}' -f $dir), ('action={0}' -f $action), ('protocol={0}' -f $protocol), ('localport={0}' -f $localPort))
          }
        }
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: firewall rule: {2} created' -f $($MyInvocation.MyCommand.Name), $componentName, $ruleName)
      } catch {
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to create firewall rule: {2}. {3}' -f $($MyInvocation.MyCommand.Name), $componentName,  $ruleName, $_.Exception.Message)
      }
    } elseif (($protocol -eq 'ICMPv4') -or ($protocol -eq 'ICMPv6')) {
      $ruleName = ('{0} ({1} {2} {3}): {4}' -f $componentName, $protocol, $action)
      try {
        if (Get-Command 'New-NetFirewallRule' -errorAction SilentlyContinue) {
          if ($remoteAddress) {
            New-NetFirewallRule -DisplayName $ruleName -Protocol $protocol -IcmpType 8 -Action $action -RemoteAddress $remoteAddress
          } else {
            New-NetFirewallRule -DisplayName $ruleName -Protocol $protocol -IcmpType 8 -Action $action
          }
        } else {
          if ($remoteAddress) {
            & 'netsh.exe' @('advfirewall', 'firewall', 'add', 'rule', ('name="{0}"' -f $ruleName), ('dir={0}' -f $dir), ('action={0}' -f $action), ('protocol={0}:8,any' -f $protocol), ('localport={0}' -f $localPort), ('remoteip={0}' -f $remoteAddress))
          } else {
            & 'netsh.exe' @('advfirewall', 'firewall', 'add', 'rule', ('name="{0}"' -f $ruleName), ('dir={0}' -f $dir), ('action={0}' -f $action), ('protocol={0}:8,any' -f $protocol), ('localport={0}' -f $localPort))
          }
        }
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: firewall rule: {2} created' -f $($MyInvocation.MyCommand.Name), $componentName, $ruleName)
      } catch {
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to create firewall rule: {2}. {3}' -f $($MyInvocation.MyCommand.Name), $componentName,  $ruleName, $_.Exception.Message)
      }
    } elseif ($program) {
      $ruleName = ('{0} ({1} {2}): {3}' -f $componentName, $program, $direction, $action)
      try {
        if (Get-Command 'New-NetFirewallRule' -errorAction SilentlyContinue) {
          if ($remoteAddress) {
            New-NetFirewallRule -DisplayName $ruleName -Program $program -Direction $direction -Action $action -RemoteAddress $remoteAddress
          } else {
            New-NetFirewallRule -DisplayName $ruleName -Program $program -Direction $direction -Action $action
          }
        } else {
          if ($remoteAddress) {
            & 'netsh.exe' @('advfirewall', 'firewall', 'add', 'rule', ('name="{0}"' -f $ruleName), ('dir={0}' -f $dir), ('action={0}' -f $action), ('program={0}' -f $program), ('remoteip={0}' -f $remoteAddress))
          } else {
            & 'netsh.exe' @('advfirewall', 'firewall', 'add', 'rule', ('name="{0}"' -f $ruleName), ('dir={0}' -f $dir), ('action={0}' -f $action), ('program={0}' -f $program))
          }
        }
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: firewall rule: {2} created' -f $($MyInvocation.MyCommand.Name), $componentName, $ruleName)
      } catch {
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to create firewall rule: {2}. {3}' -f $($MyInvocation.MyCommand.Name), $componentName,  $ruleName, $_.Exception.Message)
      }
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-ReplaceInFile {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $path,

    [Parameter(Mandatory = $true)]
    [string] $matchString,

    [Parameter(Mandatory = $true)]
    [string] $replaceString,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    try {
      $content = ((Get-Content -Path $path) | Foreach-Object { $_ -replace $matchString, (Invoke-Expression -Command $replaceString) })
      [System.IO.File]::WriteAllLines($path, $content, (New-Object System.Text.UTF8Encoding $false))
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: replaced occurences of: {2} with: {3} in: {4}' -f $($MyInvocation.MyCommand.Name), $componentName, $matchString, $replaceString, $path)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to replace occurences of: {2} with: {3} in: {4}. {5}' -f $($MyInvocation.MyCommand.Name), $componentName, $matchString, $replaceString, $path, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
function Invoke-ZipInstall {
  [CmdletBinding()]
  param (
    [Alias('component')]
    [Parameter(Mandatory = $true)]
    [string] $componentName,

    [Parameter(Mandatory = $true)]
    [string] $path,

    [Parameter(Mandatory = $true)]
    [string] $destination,

    [switch] $overwrite = $false,
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
  process {
    if ($overwrite) {
      Invoke-DirectoryDelete -verbose:$verbose -component $componentName -path $destination -eventLogName $eventLogName -eventLogSource $eventLogSource
    }
    try {
      [System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination)
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'info' -message ('{0} ({1}) :: zip: {2} extracted to: {3}' -f $($MyInvocation.MyCommand.Name), $componentName, $path, $destination)
    } catch {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'error' -message ('{0} ({1}) :: failed to extract zip: {2} to: {3}. {4}' -f $($MyInvocation.MyCommand.Name), $componentName, $path, $destination, $_.Exception.Message)
    }
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-DownloadInstall {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,

    [Parameter(Mandatory = $true)]
    [ValidateSet('exe', 'msi', 'msu')]
    [string] $format,

    [string] $localPath = $(if ($format -eq 'msi') { ('{0}\Temp\{1}_{2}.msi' -f $env:SystemRoot, $component.ComponentName, $component.ProductId) } else { ('{0}\Temp\{1}.{2}' -f $env:SystemRoot, $(if ($component.sha512) { $component.sha512 } else { $component.ComponentName }), $format) }),

    [string] $tooltoolHost = 'tooltool.mozilla-releng.net',
    [string] $tokenPath = ('{0}\builds\occ-installers.tok' -f $env:SystemDrive),
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    switch ($format) {
      'exe' {
        $command = $localPath
        $arguments = @($component.Arguments | % { $($_) })
      }
      'msi' {
        $command = ('{0}\system32\msiexec.exe' -f $env:WinDir)
        $arguments = @('/i', $localPath, '/log', ('{0}\log\{1}-{2}.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $component.ComponentName), '/quiet', '/norestart')
      }
      'msu' {
        $command = ('{0}\system32\wusa.exe' -f $env:WinDir)
        $arguments = @($localPath, '/quiet', '/norestart')
      }
    }
    Invoke-FileDownload -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component.ComponentName -localPath $localPath -sha512 $($component.sha512) -tooltoolHost $tooltoolHost -tokenPath $tokenPath -url $component.Url
    Invoke-CommandRun -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component.ComponentName -command $command -arguments $arguments
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-DownloadInstall {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,

    [string] $localPath = $(if ($format -eq 'msi') { ('{0}\Temp\{1}_{2}.msi' -f $env:SystemRoot, $component.ComponentName, $component.ProductId) } else { ('{0}\Temp\{1}.{2}' -f $env:SystemRoot, $(if ($component.sha512) { $component.sha512 } else { $component.ComponentName }), $format) }),

    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    return ((Confirm-FileDownload -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component.ComponentName -localPath $localPath -sha512 $($component.sha512)) -and (Confirm-CommandRun -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component.ComponentName -validations $component.Validate))
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-ExeInstall {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,

    [string] $localPath = ('{0}\Temp\{1}.exe' -f $env:SystemRoot, $(if ($component.sha512) { $component.sha512 } else { $component.ComponentName })),
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    Invoke-DownloadInstall -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component -localPath $localPath -format 'exe'
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-ExeInstall {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,

    [string] $localPath = ('{0}\Temp\{1}.exe' -f $env:SystemRoot, $(if ($component.sha512) { $component.sha512 } else { $component.ComponentName })),
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    return (Confirm-DownloadInstall -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component -localPath $localPath)
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-MsiInstall {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,

    [string] $localPath = ('{0}\Temp\{1}_{2}.msi' -f $env:SystemRoot, $component.ComponentName, $component.ProductId),
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    Invoke-DownloadInstall -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component -localPath $localPath -format 'msi'
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-MsiInstall {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,

    [string] $localPath = ('{0}\Temp\{1}_{2}.msi' -f $env:SystemRoot, $component.ComponentName, $component.ProductId),
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    return (Confirm-DownloadInstall -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component -localPath $localPath)
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}

function Invoke-MsuInstall {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,

    [string] $localPath = ('{0}\Temp\{1}.msu' -f $env:SystemRoot, $(if ($component.sha512) { $component.sha512 } else { $component.ComponentName })),
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    Invoke-DownloadInstall -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component -localPath $localPath -format 'msu'
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}

function Confirm-MsuInstall {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [object] $component,

    [string] $localPath = ('{0}\Temp\{1}.msu' -f $env:SystemRoot, $(if ($component.sha512) { $component.sha512 } else { $component.ComponentName })),
    
    [string] $eventLogName = 'Application',
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
  process {
    return (Confirm-DownloadInstall -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -component $component -localPath $localPath)
  }
  end {
    Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $component.ComponentName, (Get-Date).ToUniversalTime())
  }
}