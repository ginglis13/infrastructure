# User data script for self hosted Windows runners
Start-Transcript -Path "C:\UserData.log" -Append
$progressPreference = 'silentlyContinue'

$RUNNER_DIR="C:\actions-runner"

Write-Information "Installing latest powershell7 version..."
Invoke-Expression "& { $(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') } -useMSI -EnablePSRemoting -Quiet"

Write-Information "Starting powershell7..."
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force

New-Item -Path $Profile -ItemType File -Force 'Set-PSReadLineOption -EditMode Emacs' | Out-File -Append $Profile

New-Item -Path $Home\setup -ItemType Directory
Set-Location $Home\setup

Write-Information "Installing winget and its dependencies..."

Add-AppxPackage 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
Invoke-WebRequest -Uri https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.3 -OutFile .\microsoft.ui.xaml.2.7.3.zip
Expand-Archive .\microsoft.ui.xaml.2.7.3.zip
Add-AppxPackage .\microsoft.ui.xaml.2.7.3\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.appx

# Install Windows Terminal
Invoke-WebRequest -Uri https://github.com/microsoft/terminal/releases/download/v1.17.11461.0/Microsoft.WindowsTerminal_1.17.11461.0_8wekyb3d8bbwe.msixbundle -OutFile .\Microsoft.WindowsTerminal_1.17.11461.0_8wekyb3d8bbwe.msixbundle
Add-AppxProvisionedPackage -Online -PackagePath .\Microsoft.WindowsTerminal_1.17.11461.0_8wekyb3d8bbwe.msixbundle -SkipLicense
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.WindowsTerminal_1.17.11461.0_8wekyb3d8bbwe

# https://github.com/microsoft/winget-cli/releases/tag/v1.6.1573-preview
Invoke-WebRequest -Uri https://github.com/microsoft/winget-cli/releases/download/v1.6.1573-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle -OutFile  .\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
Invoke-WebRequest -Uri https://github.com/microsoft/winget-cli/releases/download/v1.6.1573-preview/ba27c402ae29410eb93cfa9cb27f1376_License1.xml -OutFile .\ba27c402ae29410eb93cfa9cb27f1376_License1.xml
Add-AppxProvisionedPackage -Online -PackagePath .\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle -LicensePath .\ba27c402ae29410eb93cfa9cb27f1376_License1.xml
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe

Write-Information "Manually update package cache and install dependencies"
$pws7script = @'
# Fix winget on Windows Server by manually updating the package cache
Import-Module -Name Appx -UseWindowsPowerShell  
Invoke-WebRequest 'https://cdn.winget.microsoft.com/cache/source.msix' -OutFile 'source.msix' -UseBasicParsing
Add-AppxPackage -Path source.msix
ECHO Y | cmd /c winget upgrade --all --silent
# Install dependencies via winget
winget install -e --id Git.Git
winget install -e --id GnuWin32.Make

# Install AWS tools
Install-Module -Name AWS.Tools.Common -Force
Install-Module -Name AWS.Tools.SecretsManager -Force

# Install jq
Invoke-WebRequest -Uri 'https://github.com/stedolan/jq/releases/latest/download/jq-win64.exe' -OutFile 'jq.exe'
New-Item -Path 'C:\Progam Files\jq' -ItemType Directory
Move-Item -Path 'jq.exe' -Destination 'C:\Progam Files\jq' 

#  Install Go
Invoke-WebRequest -Uri 'https://go.dev/dl/go1.21.0.windows-amd64.msi' -OutFile 'go1.21.0.windows-amd64.msi'
Start-Process msiexec.exe -Wait -ArgumentList '/I C:\Users\Administrator\setup\go1.21.0.windows-amd64.msi /quiet'
# Configure path
$newPath = ("C:\Program Files\Git\usr\bin\;" + "$env:Path" + ";C:\Program Files\Git\bin\;" + "C:\Program Files (x86)\GnuWin32\bin\;" + "C:\Program Files\Go\bin\;" + "C:\Progam Files\jq\;") 
$env:Path = $newPath
# Persist the path to the registry for new shells
Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
'@

# Write PowerShell 7 script to file
$pws7script | Out-File $Home\setup\setup7.ps1

# Execute script with PowerShell 7
$ConsoleCommand = "$Home\setup\setup7.ps1"
Start-Process "C:\Program Files\PowerShell\7\pwsh" -Wait -NoNewWindow -PassThru -ArgumentList "-Command  &{ $ConsoleCommand }"

Write-Information "Downloading and configuring GitHub Actions Runner..."
mkdir $RUNNER_DIR; cd $RUNNER_DIR
Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.309.0/actions-runner-win-x64-2.309.0.zip -OutFile actions-runner-win-x64-2.309.0.zip
if((Get-FileHash -Path actions-runner-win-x64-2.309.0.zip -Algorithm SHA256).Hash.ToUpper() -ne 'cd1920154e365689130aa1f90258e0da47faecce547d0374475cdd2554dbf09a'.ToUpper()){ throw 'Computed checksum did not match' }
Add-Type -AssemblyName System.IO.Compression.FileSystem ;  [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD/actions-runner-win-x64-2.309.0.zip", "$PWD")

$GH_KEY=(Get-SECSecretValue -SecretId $REPO-runner-reg-key -Region $REGION).SecretString
$LABEL_OS_VER=$([System.Environment]::OSVersion.Version.Major)
$LABEL_BUILD_VER=$([System.Environment]::OSVersion.Version.Build)

$LABEL_ARCH="amd64"

#TODO: ginglis13 -> runfinch
$RUNNER_REG_TOKEN=((Invoke-WebRequest -Method POST -Headers @{"Accept" = "application/vnd.github+json"; "Authorization" =  "Bearer $GH_KEY";  "X-GitHub-Api-Version" = "2022-11-28"} -Uri https://api.github.com/repos/ginglis13/$REPO/actions/runners/registration-token).Content | jq -r '.token')

Write-Information "Starting GitHub Actions Runner..."

#TODO: ginglis13 -> runfinch
cd $RUNNER_DIR; ./config.cmd --url https://github.com/ginglis13/$REPO --unattended --token  $RUNNER_REG_TOKEN --work _work --labels  '$LABEL_ARCH,$LABEL_OS_VER,$LABEL_BUILD_VER,$LABEL_STAGE'
Start-Service "actions.runner.*"