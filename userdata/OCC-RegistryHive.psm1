<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

Function Import-RegistryHive
{
    <#
    .SYNOPSIS
        Import a registry hive from a file.
    .DESCRIPTION
        Import a registry hive from a file. An imported hive is loaded into a named PSDrive available globally in the current session.
    .EXAMPLE
        C:\PS>Import-RegistryHive -File 'C:\Users\Default\NTUSER.DAT' -Key 'HKLM\TEMP_HIVE' -Name TempHive
        C:\PS>Get-ChildItem TempHive:\
    .PARAMETER File
        The registry hive file to load, eg. NTUSER.DAT
    .PARAMETER Key
        The registry key to load the hive into, in the format HKLM\MY_KEY or HKCU\MY_KEY
    .PARAMETER Name
        The name of the PSDrive to access the hive, excluding the characters ;~/\.:
    .OUTPUTS
        $null or Exception on error
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String] $File,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^HK(LM|CU)\\[a-zA-Z0-9- _\\]+$')]
        [String] $Key,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[^;~/\\\.\:]+$')]
        [String] $Name
    )
    
    # check whether the drive name is available
    $TestDrive = Get-PSDrive -Name $Name -EA SilentlyContinue
    if ($TestDrive -ne $null)
    {
        $ErrorRecord = New-Object Management.Automation.ErrorRecord(
            (New-Object Management.Automation.SessionStateException("A drive with the name '$Name' already exists.")),
            'DriveNameUnavailable', [Management.Automation.ErrorCategory]::ResourceUnavailable, $null
        )
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    
    # load the registry hive from file using reg.exe
    $Process = Start-Process -FilePath "$env:WINDIR\system32\reg.exe" -ArgumentList "load $Key $File" -WindowStyle Hidden -PassThru -Wait
    
    if ($Process.ExitCode)
    {
        $ErrorRecord = New-Object Management.Automation.ErrorRecord(
            (New-Object Management.Automation.PSInvalidOperationException("The registry hive '$File' failed to load. Verify the source path or target registry key.")),
            'HiveLoadFailure', [Management.Automation.ErrorCategory]::ObjectNotFound, $null
        )
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    
    try
    {
        # create a global drive using the registry provider, with the root path as the previously loaded registry hive
        New-PSDrive -Name $Name -PSProvider Registry -Root $Key -Scope Global -EA Stop | Out-Null
    }
    catch
    {
        # validate patten on $Name in the Params and the drive name check at the start make it very unlikely New-PSDrive will fail
        $ErrorRecord = New-Object Management.Automation.ErrorRecord(
            (New-Object Management.Automation.PSInvalidOperationException("An unrecoverable error creating drive '$Name' has caused the registy key '$Key' to be left loaded, this must be unloaded manually.")),
            'DriveCreateFailure', [Management.Automation.ErrorCategory]::InvalidOperation, $null
        )
        $PSCmdlet.ThrowTerminatingError($ErrorRecord);
    }
}

Function Remove-RegistryHive
{
    <#
    .SYNOPSIS
        Remove a registry hive loaded via Import-RegistryHive.
    .DESCRIPTION
        Remove a registry hive loaded via Import-RegistryHive. Removing the the hive will remove the associated PSDrive and unload the registry key created during the import.
    .EXAMPLE
        C:\PS>Remove-RegistryHive -Name TempHive
    .PARAMETER Name
        The name of the PSDrive used to access the hive.
    .OUTPUTS
        $null or Exception on error
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[^;~/\\\.\:]+$')]
        [String] $Name
    )
    
    # get the drive that was used to map the registry hive
    $Drive = Get-PSDrive -Name $Name -EA SilentlyContinue

    # if $Drive is $null the drive name was incorrect
    if ($Drive -eq $null)
    {
        $ErrorRecord = New-Object Management.Automation.ErrorRecord(
            (New-Object Management.Automation.DriveNotFoundException("The drive '$Name' does not exist.")),
            'DriveNotFound', [Management.Automation.ErrorCategory]::ResourceUnavailable, $null
        )
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }

    # $Drive.Root is the path to the registry key, save this before the drive is removed
    $Key = $Drive.Root
    
    try
    {
        # remove the drive, the only reason this should fail is if the reasource is busy
        Remove-PSDrive $Name -EA Stop
    }
    catch
    {
        $ErrorRecord = New-Object Management.Automation.ErrorRecord(
            (New-Object Management.Automation.PSInvalidOperationException("The drive '$Name' could not be removed, it may still be in use.")),
            'DriveRemoveFailure', [Management.Automation.ErrorCategory]::ResourceBusy, $null
        )
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }

    $Process = Start-Process -FilePath "$env:WINDIR\system32\reg.exe" -ArgumentList "unload $Key" -WindowStyle Hidden -PassThru -Wait

    if ($Process.ExitCode)
    {
        # if "reg unload" fails due to the resource being busy, the drive gets added back to keep the original state
        New-PSDrive -Name $Name -PSProvider Registry -Root $Key -Scope Global -EA Stop | Out-Null

        $ErrorRecord = New-Object Management.Automation.ErrorRecord(
            (New-Object Management.Automation.PSInvalidOperationException("The registry key '$Key' could not be unloaded, it may still be in use.")),
            'HiveUnloadFailure', [Management.Automation.ErrorCategory]::ResourceBusy, $null
        )
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
}