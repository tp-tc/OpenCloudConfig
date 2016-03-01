
# FeatureConfig installs or removes operating system Windows Features
Configuration FeatureConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  WindowsFeature DotNetFrameworkInstall {
    Name = 'NET-Framework-Core'
    Ensure = 'Present'
  }
}
