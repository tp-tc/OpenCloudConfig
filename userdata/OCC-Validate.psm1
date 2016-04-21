<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Validate-PathsExistOrNotRequested {
  #[CmdletBinding()]
  param(
    [object[]] $items
  )
  begin {}
  process {
    # either no validation paths-exist are specified
    return ((-not ($items)) -or (
      # validation paths-exist are specified
      (($items) -and ($items.Length -gt 0)) -and
      # all validation paths-exist are satisfied (exist on the instance)
      (-not (@($items | % {
        (Test-Path -Path $_.Path -ErrorAction SilentlyContinue)
      }) -contains $false))
    ))
  }
  end {}
}

function Validate-PathsNotExistOrNotRequested {
  #[CmdletBinding()]
  param(
    [object[]] $items
  )
  begin {}
  process {
    # either no validation paths-exist are specified
    return ((-not ($items)) -or (
      # validation paths-exist are specified
      (($items) -and ($items.Length -gt 0)) -and
      # all validation paths-exist are satisfied (exist on the instance)
      (-not (@($items | % {
        (-not (Test-Path -Path $_.Path -ErrorAction SilentlyContinue))
      }) -contains $false))
    ))
  }
  end {}
}

function Validate-CommandsReturnOrNotRequested {
  #[CmdletBinding()]
  param(
    [object[]] $items
  )
  begin {}
  process {
    # either no validation commands-return are specified
    return ((-not ($items)) -or (
      # validation commands-return are specified
      (($items) -and ($items.Length -gt 0)) -and
      # all validation commands-return are satisfied
      (-not (@($items | % {
        $cr = $_
        @(@(& $cr.Command $cr.Arguments) | ? {
          $_ -match $cr.Match
        })
      }) -contains $false))
    ))
  }
  end {}
}

function Validate-FilesContainOrNotRequested {
  #[CmdletBinding()]
  param(
    [object[]] $items
  )
  begin {}
  process {
    # either no validation files-contain are specified
    return ((-not ($items)) -or (
      # validation files-contain are specified
      (($items) -and ($items.Length -gt 0)) -and
      # all validation files-contain are satisfied
      (-not (@($items | % {
        $fc = $_
        (((Get-Content $fc.Path) | % {
          $_ -match $fc.Match
        }) -contains $true) # a line within the file contained a match
      }) -contains $false)) # no files failed to contain a match (see '-not' above)
    ))
  }
  end {}
}
