# OpenCloudConfig

## Windows Server 2012 R2 with Visual Studio 2013

    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/try-win2012-vs2013.ps1')

## Windows Server 2012 R2 with Visual Studio 2015

    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/try-win2012-vs2015.ps1')

### Or as AWS EC2 userdata:

    <powershell>
    $config = 'try-win2012-vs2013.ps1'
    $repo = 'MozRelOps/OpenCloudConfig'
    $url = ('https://raw.githubusercontent.com/{0}/master/userdata/{1}' -f $repo, $config)
    Invoke-Expression (New-Object Net.WebClient).DownloadString($url)
    </powershell>
    <persist>true</persist>
