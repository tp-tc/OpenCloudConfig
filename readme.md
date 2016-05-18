# OpenCloudConfig

open cloud config is a tool for creating cloud instances with a specific configuration in a repeatable, source controlled manner.

instance configuration is defined in json format and currently includes implementations for these instance configuration mechanisms (most source parameters are expected to be a URL):

- DirectoryCreate: Create an empty folder or validates that it already exists
- DirectoryDelete: Deletes a folder and all contents or validates that it does not exist
- DirectoryCopy: Copies a folder and all contents or validates that destination is identical to source (including contents)
- CommandRun: Runs a command from the cmd (COMSPEC) command prompt. Provides an optional mechanism for first performing a validation step to check if the command shoul be run.
- FileDownload: Downloads a file from source or validates that a file with the same name exists at destination
- ChecksumFileDownload: Downloads a file from source or validates that a file with the same name and SHA1 signature exists at destination
- SymbolicLink: Creates a symbolic link (file or directory) or validates that it already exists
- ExeInstall: Installs an executable or validates that it has already been installed (using optional validation commands)
- MsiInstall: Installs an MSI or validates that it has already been installed (using package identifier)
- WindowsFeatureInstall: Installs a Windows feature (like a .Net framework) or validates that it is already installed
- ZipInstall: Extracts a compressed archive from source to destination or validates that all archive contents exist at destination
- ServiceControl: Sets a service startup type and triggers the expected service state or validates that the startup type and service is already in the expected state
- EnvironmentVariableSet: Sets an environment variable or validates that it has been set to the provided value
- EnvironmentVariableUniqueAppend: Appends one or more values to a collection environment variable delimited by semicolons or validates that the variable already contains the required values
- EnvironmentVariableUniquePrepend: Prepends one or more values to a collection environment variable delimited by semicolons or validates that the variable already contains the required values
- RegistryKeySet: Sets a registry key or validates that the key already exists
- RegistryValueSet: Sets a registry key and value or validates that the key already exists and contains the specified value
- FirewallRule: Sets a firewall rule or validates that the rule already exists

currently only Windows instances are supported and Powershell Desired State Configuration is used as the provider.

an instance can be configured to use the win2012.json manifest in this repository by running the following command at an elevated powershell prompt:

    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/win2012.ps1')

or as EC2 userdata:

    <powershell>
    $config = 'win2012.ps1'
    $repo = 'MozRelOps/OpenCloudConfig'
    $url = ('https://raw.githubusercontent.com/{0}/master/userdata/{1}' -f $repo, $config)
    Invoke-Expression (New-Object Net.WebClient).DownloadString($url)
    </powershell>
    <persist>true</persist>
    <secrets>
      <rootGpgKey>
    -----BEGIN PGP PRIVATE KEY BLOCK-----
    Replace with your key.
    Generate a key and ascii representation needed here, with the following commands:
    echo Key-Type: 1> gpg-gen-key.options
    echo Key-Length: 4096>> gpg-gen-key.options
    echo Subkey-Type: 1>> gpg-gen-key.options
    echo Subkey-Length: 4096>> gpg-gen-key.options
    echo Name-Real: windows-userdata>> gpg-gen-key.options
    echo Name-Email: windows-userdata@example.com>> gpg-gen-key.options
    echo Expire-Date: 0>> gpg-gen-key.options
    gpg --batch --gen-key gpg-gen-key.options
    gpg --export-secret-key -a windows-userdata > private.key
    -----END PGP PRIVATE KEY BLOCK-----
      </rootGpgKey>
    </secrets>
