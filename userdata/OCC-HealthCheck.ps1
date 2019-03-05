
function Invoke-InstanceHealthCheck {
  begin {
    if (Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') {
      Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
  }
  process {
    Write-LogDirectoryContents -path 'C:\generic-worker'
  }
  end {
    if (Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') {
      Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
  }
}

function Write-LogDirectoryContents {
  param (
    [string] $path
  )
  begin {
    if (Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') {
      Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
  }
  process {
    if (Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') {
      if (Test-Path -Path $path -ErrorAction 'SilentlyContinue') {
        $directoryContents = (Get-ChildItem -Path $path -ErrorAction 'SilentlyContinue')
        if ($directoryContents.Length) {
          Write-Log -message ('{0} :: directory contents of "{1}":' -f $($MyInvocation.MyCommand.Name), $path) -severity 'DEBUG'
          foreach ($directoryEntry in $directoryContents) {
            Write-Log -message ('{0} :: {1}:' -f $($MyInvocation.MyCommand.Name), $directoryEntry.Name) -severity 'DEBUG'
          }
        } else {
          Write-Log -message ('{0} :: directory "{1}" is empty' -f $($MyInvocation.MyCommand.Name), $path) -severity 'DEBUG'
        }
      } else {
        Write-Log -message ('{0} :: directory "{1}" not found' -f $($MyInvocation.MyCommand.Name), $path) -severity 'DEBUG'
      }
    }
  }
  end {
    if (Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') {
      Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
  }
}

Invoke-InstanceHealthCheck