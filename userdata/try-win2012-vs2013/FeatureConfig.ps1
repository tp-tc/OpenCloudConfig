
# FeatureConfig installs or removes operating system Windows Features
Configuration FeatureConfig {
  WindowsFeature DotNetFrameworkInstall {
    Name = NET-Framework-Core
    Ensure = Present
  }
}
