<#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
@{
  ModuleVersion = '0.0.1'
  GUID = '111e57ab-a13a-4d07-b2db-146606cf1318'
  Author = 'grenade@mozilla.com'
  CompanyName = 'Mozilla'
  Copyright = '© 2015 Mozilla Corporation. All rights reserved.'
  Description = 'Installation of Chocolatey packages via Desired State Configuration.'
  PowerShellVersion = '3.0'
  CLRVersion = '4.0'
  RequiredModules = @()
  NestedModules = @("ChocolateyResource.psm1")
  FunctionsToExport = @("Get-TargetResource", "Set-TargetResource", "Test-TargetResource")
  HelpInfoURI = 'https://github.com/MozRelOps/powershell-utilities'
}
