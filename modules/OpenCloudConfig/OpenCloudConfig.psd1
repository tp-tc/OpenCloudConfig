<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

@{

  # Script module or binary module file associated with this manifest
  RootModule = 'OpenCloudConfig.psm1'

  # Version number of this module.
  ModuleVersion = '0.0.46'

  # ID used to uniquely identify this module
  GUID = 'd1235f10-0ae3-4353-9a31-0abeb2b9093e'

  # Author of this module
  Author = 'grenade'

  # Company or vendor of this module
  CompanyName = 'Mozilla Corporation'

  # Copyright statement for this module
  Copyright = '(c) 2019 grenade. All rights reserved.'

  # Description of the functionality provided by this module
  Description = 'Install and configure software, environment and registry settings'

  # Minimum version of the Windows PowerShell engine required by this module
  PowerShellVersion = '2.0'

  # Name of the Windows PowerShell host required by this module
  # PowerShellHostName = ''

  # Minimum version of the Windows PowerShell host required by this module
  # PowerShellHostVersion = ''

  # Minimum version of the .NET Framework required by this module
  DotNetFrameworkVersion = '2.0'

  # Minimum version of the common language runtime (CLR) required by this module
  CLRVersion = '2.0.50727'

  # Processor architecture (None, X86, Amd64) required by this module
  # ProcessorArchitecture = ''

  # Modules that must be imported into the global environment prior to importing this module
  # RequiredModules = @()

  # Assemblies that must be loaded prior to importing this module
  # RequiredAssemblies = @()

  # Script files (.ps1) that are run in the caller's environment prior to importing this module
  # ScriptsToProcess = @()

  # Type files (.ps1xml) to be loaded when importing this module
  # TypesToProcess = @()

  # Format files (.ps1xml) to be loaded when importing this module
  # FormatsToProcess = @()

  # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
  NestedModules = @(
    'Archive.psm1',
    'DynamicConfig.psm1',
    'User.psm1',
    'Validate.psm1'
  )

  # Functions to export from this module and nested modules
  FunctionsToExport = @(

    # OpenCloudConfig.psm1
   'Write-Log',
   'Get-TooltoolResource',
   'Get-RemoteResource',

   # Archive.psm1
   'New-ZipFile',

   # DynamicConfig.psm1
   'Invoke-DirectoryCreate',
   'Confirm-DirectoryCreate',
   'Invoke-DirectoryDelete',
   'Confirm-DirectoryDelete',
   'Invoke-DirectoryCopy',
   'Confirm-DirectoryCopy',
   'Invoke-LoggedCommandRun',
   'Invoke-CommandRun',
   'Confirm-CommandRun',
   'Invoke-FileDownload',
   'Confirm-FileDownload',
   'Invoke-SymbolicLink',
   'Confirm-SymbolicLink',
   'Invoke-EnvironmentVariableSet',
   'Invoke-EnvironmentVariableUniqueAppend',
   'Invoke-EnvironmentVariableUniquePrepend',
   'Invoke-RegistryKeySetOwner',
   'Invoke-RegistryKeySet',
   'Invoke-RegistryValueSet',
   'Invoke-DisableIndexing',
   'Confirm-DisableIndexing',
   'Invoke-FirewallRuleSet',
   'Confirm-FirewallRuleSet',
   'Invoke-ReplaceInFile',
   'Invoke-ZipInstall',
   'Invoke-ExeInstall',
   'Confirm-ExeInstall',
   'Invoke-MsiInstall',
   'Confirm-MsiInstall',
   'Invoke-MsuInstall',
   'Confirm-MsuInstall',

   # User.psm1
   'Set-KnownFolderPath',

   # Validate.psm1
   'Confirm-All',
   'Confirm-PathsExistOrNotRequested',
   'Confirm-PathsNotExistOrNotRequested',
   'Confirm-CommandsReturnOrNotRequested',
   'Confirm-FilesContainOrNotRequested',
   'Confirm-ServiceExistAndStatusMatchOrNotRequested',
   'Confirm-LogValidation'
  )

  # Cmdlets to export from this module
  # CmdletsToExport = '*'

  # Variables to export from this module
  # VariablesToExport = '*'

  # Aliases to export from this module
  # AliasesToExport = '*'

  # List of all modules packaged with this module
  # ModuleList = @()

  # List of all files packaged with this module
  # FileList = @()

  # Private data to pass to the module specified in RootModule/ModuleToProcess
  PrivateData = @{
    PSData = @{     
      # Tags applied to this module. These help with module discovery in online galleries.
      # Tags = @('software')
      
      # A URL to the license for this module.
      LicenseUri = 'http://mozilla.org/MPL/2.0/'
      
      # A URL to the main website for this project.
      ProjectUri = 'https://github.com/mozilla-releng/OpenCloudConfig'
    }
  }

  # HelpInfo URI of this module
  # HelpInfoURI = ''

  # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
  # DefaultCommandPrefix = ''

}