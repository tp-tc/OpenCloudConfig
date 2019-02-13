<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Confirm-All {
  [CmdletBinding()]
  param(
    [object] $validations,

    [string] $componentName,

    [string] $eventLogName = 'Application',

    [Alias('source')]
    [string] $eventLogSource
  )
  begin {
    if ((Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') -and $componentName -and $eventLogSource) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: begin - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
    }
  }
  process {
    if (-not ($validations) -or (
        (-not ($validations.PathsExist)) -and
        (-not ($validations.PathsNotExist)) -and
        (-not ($validations.CommandsReturn)) -and
        (-not ($validations.FilesContain)) -and
        (-not ($validations.ServiceStatus))
      )
    ) {
      if ((Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') -and $componentName -and $eventLogSource) {
        Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: no validations specified' -f $($MyInvocation.MyCommand.Name), $componentName)
      } else {
        Write-Verbose ('{0} :: No validations specified.' -f $($MyInvocation.MyCommand.Name))
      }
      # if no validations are specified, we return false, so that the component is deemed to be not yet applied.
      return $false
    }
    return (
      # if no validations are specified, this function will return $false and cause the calling resource's set script to be run
      (
        (($validations.PathsExist) -and ($validations.PathsExist.Length -gt 0)) -or
        (($validations.PathsNotExist) -and ($validations.PathsNotExist.Length -gt 0)) -or
        (($validations.CommandsReturn) -and ($validations.CommandsReturn.Length -gt 0)) -or
        (($validations.FilesContain) -and ($validations.FilesContain.Length -gt 0)) -or
        (($validations.ServiceStatus) -and ($validations.ServiceStatus.Length -gt 0))
      ) -and (
        Confirm-PathsExistOrNotRequested -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -componentName $componentName -items $validations.PathsExist
      ) -and (
        Confirm-PathsNotExistOrNotRequested -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -componentName $componentName -items $validations.PathsNotExist
      ) -and (
        Confirm-CommandsReturnOrNotRequested -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -componentName $componentName -items $validations.CommandsReturn
      ) -and (
        Confirm-FilesContainOrNotRequested -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -componentName $componentName -items $validations.FilesContain
      ) -and (
        Confirm-ServiceExistAndStatusMatchOrNotRequested -verbose:$verbose -eventLogName $eventLogName -eventLogSource $eventLogSource -componentName $componentName -items $validations.ServiceStatus
      )
    )
  }
  end {
    if ((Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') -and $componentName -and $eventLogSource) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: end - {2:o}' -f $($MyInvocation.MyCommand.Name), $componentName, (Get-Date).ToUniversalTime())
    }
  }
}

function Confirm-PathsExistOrNotRequested {
  [CmdletBinding()]
  param(
    [object[]] $items,

    [string] $componentName,

    [string] $eventLogName = 'Application',

    [Alias('source')]
    [string] $eventLogSource
  )
  begin {
    if ((Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') -and $componentName -and $eventLogSource) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: {2} validation{3} specified' -f $($MyInvocation.MyCommand.Name), $componentName, $items.Length, ('s','')[($items.Length -eq 1)])
    } else {
      Write-Verbose ('{0} :: {1} validation{2} specified.' -f $($MyInvocation.MyCommand.Name), $items.Length, ('s','')[($items.Length -eq 1)])
    }
  }
  process {
    # either no validation paths-exist are specified
    return ((-not ($items)) -or (
      # validation paths-exist are specified
      (($items) -and ($items.Length -gt 0)) -and
      # all validation paths-exist are satisfied (exist on the instance)
      (-not (@($items | % {
        if (Test-Path -Path $_ -ErrorAction SilentlyContinue) {
          Write-Verbose ('Path present: {0}' -f $_)
          $true
        } else {
          Write-Verbose ('Path absent: {0}' -f $_)
          $false
        }
      }) -contains $false))
    ))
  }
  end {}
}

function Confirm-PathsNotExistOrNotRequested {
  [CmdletBinding()]
  param(
    [object[]] $items,

    [string] $componentName,

    [string] $eventLogName = 'Application',

    [Alias('source')]
    [string] $eventLogSource
  )
  begin {
    if ((Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') -and $componentName -and $eventLogSource) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: {2} validation{3} specified' -f $($MyInvocation.MyCommand.Name), $componentName, $items.Length, ('s','')[($items.Length -eq 1)])
    } else {
      Write-Verbose ('{0} :: {1} validation{2} specified.' -f $($MyInvocation.MyCommand.Name), $items.Length, ('s','')[($items.Length -eq 1)])
    }
  }
  process {
    # either no validation paths-exist are specified
    return ((-not ($items)) -or (
      # validation paths-exist are specified
      (($items) -and ($items.Length -gt 0)) -and
      # all validation paths-exist are satisfied (exist on the instance)
      (-not (@($items | % {
        if (-not (Test-Path -Path $_ -ErrorAction SilentlyContinue)) {
          Write-Verbose ('Path absent: {0}' -f $_)
          $true
        } else {
          Write-Verbose ('Path present: {0}' -f $_)
          $false
        }
      }) -contains $false))
    ))
  }
  end {}
}

function Confirm-CommandsReturnOrNotRequested {
  [CmdletBinding()]
  param(
    [object[]] $items,

    [string] $componentName,

    [string] $eventLogName = 'Application',

    [Alias('source')]
    [string] $eventLogSource
  )
  begin {
    if ((Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') -and $componentName -and $eventLogSource) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: {2} validation{3} specified' -f $($MyInvocation.MyCommand.Name), $componentName, $items.Length, ('s','')[($items.Length -eq 1)])
    } else {
      Write-Verbose ('{0} :: {1} validation{2} specified.' -f $($MyInvocation.MyCommand.Name), $items.Length, ('s','')[($items.Length -eq 1)])
    }
  }
  process {
    # either no validation commands-return are specified
    return ((-not ($items)) -or (
      # validation commands-return are specified
      (($items) -and ($items.Length -gt 0)) -and
      # all validation commands-return are satisfied
      ((@($items | % {
        $cr = $_
        Write-Verbose ('Command: {0} {1}' -f $cr.Command, ($cr.Arguments -join ' '))
        if ($cr.Match) {
          Write-Verbose ('Search (match): {0}' -f $cr.Match)
          try {
            if (@(& $cr.Command $cr.Arguments 2>&1) -contains $cr.Match) {
              Write-Verbose ('Output (match): {0}' -f $_)
              $true
            } else {
              $false
            }
          } catch {
            $false
          }
        } elseif ($cr.Like) {
          Write-Verbose ('Search (like): {0}' -f $cr.Like)
          if (@(& $cr.Command $cr.Arguments 2>&1) -like $cr.Like) {
            Write-Verbose ('Output (like): {0}' -f $_)
            $true
          } else {
            $false
          }
        } else {
          $false
        }
      }) -notcontains $false))
    ))
  }
  end {}
}

function Confirm-FilesContainOrNotRequested {
  [CmdletBinding()]
  param(
    [object[]] $items,

    [string] $componentName,

    [string] $eventLogName = 'Application',

    [Alias('source')]
    [string] $eventLogSource
  )
  begin {
    if ((Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') -and $componentName -and $eventLogSource) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: {2} validation{3} specified' -f $($MyInvocation.MyCommand.Name), $componentName, $items.Length, ('s','')[($items.Length -eq 1)])
    } else {
      Write-Verbose ('{0} :: {1} validation{2} specified.' -f $($MyInvocation.MyCommand.Name), $items.Length, ('s','')[($items.Length -eq 1)])
    }
  }
  process {
    # either no validation files-contain are specified
    return ((-not ($items)) -or (
      # validation files-contain are specified
      (($items) -and ($items.Length -gt 0)) -and
      # all validation files-contain are satisfied
      (-not (@($items | % {
        $fc = $_
        Write-Verbose ('Path: {0}' -f $fc.Path)
        Write-Verbose ('Search: {0}' -f $fc.Match)
        if (Test-Path -Path $fc.Path -ErrorAction SilentlyContinue) {
          Write-Verbose ('Path present: {0}' -f $fc.Path)
          (((Get-Content -Path $fc.Path) | % {
            if ($_ -match $fc.Match) {
              Write-Verbose ('Contents matched: {0}' -f $_)
              $true
            } else {
              $false
            }
          }) -contains $true) # a line within the file contained a match
        } else {
          Write-Verbose ('Path absent: {0}' -f $fc.Path)
          $false
        }
      }) -contains $false)) # all files existed and no files failed to contain a match (see '-not' above)
    ))
  }
  end {}
}

function Confirm-ServiceExistAndStatusMatchOrNotRequested {
  [CmdletBinding()]
  param(
    [object[]] $items,

    [string] $componentName,

    [string] $eventLogName = 'Application',

    [Alias('source')]
    [string] $eventLogSource
  )
  begin {
    if ((Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') -and $componentName -and $eventLogSource) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: {2} validation{3} specified' -f $($MyInvocation.MyCommand.Name), $componentName, $items.Length, ('s','')[($items.Length -eq 1)])
    } else {
      Write-Verbose ('{0} :: {1} validation{2} specified.' -f $($MyInvocation.MyCommand.Name), $items.Length, ('s','')[($items.Length -eq 1)])
    }
  }
  process {
    # either no validation files-contain are specified
    return ((-not ($items)) -or (
      # validation files-contain are specified
      (($items) -and ($items.Length -gt 0)) -and
      # all validations for service state are satisfied
      (-not (@($items | % {
        $ss = $_
        $service = (Get-Service -Name $ss.Name -ErrorAction 'SilentlyContinue')
        if ($service) {
          if ($service.Status -ieq $ss.Status) {
            Write-Verbose ('Service: {0}, expected status: {1} matches actual status: {2}' -f $ss.Name, $ss.Status, $service.Status)
            $true
          } else {
            Write-Verbose ('Service: {0}, expected status: {1} does not match actual status: {2}' -f $ss.Name, $ss.Status, $service.Status)
            $false
          }
        } else {
          Write-Verbose ('Service: {0} not found' -f $ss.Name)
          $false
        }
      }) -contains $false)) # all service names existed and all service states matched validation values (see '-not' above)
    ))
  }
  end {}
}

function Confirm-LogValidation {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [Alias('satisfied')]
    [bool] $validationsSatisfied,

    [string] $componentName,

    [string] $eventLogName = 'Application',

    [Alias('source')]
    [string] $eventLogSource = 'OpenCloudConfig'
  )
  begin {
    if ((Get-Command -Name 'Write-Log' -ErrorAction 'SilentlyContinue') -and $componentName -and $eventLogSource) {
      Write-Log -verbose:$verbose -logName $eventLogName -source $eventLogSource -severity 'debug' -message ('{0} ({1}) :: {2}' -f $($MyInvocation.MyCommand.Name), $componentName, @('validations not satisfied','validations satisfied')[$validationsSatisfied])
    } else {
      Write-Verbose @('Validations not satisfied','Validations satisfied')[$validationsSatisfied]
    }
  }
  process {
    return $validationsSatisfied
  }
  end {}
}