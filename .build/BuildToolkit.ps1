# Folder Pathes
$RootPath = $MyInvocation.PSScriptRoot;
$BuildTools = "$RootPath\packages";

# Artifacts
$ArtifactsDir = "$RootPath\artifacts";

# Build
$BuildArtifacts = "$ArtifactsDir\build";

# Documentation
$DocumentationDir = "$RootPath\docs";

# Tests
$NunitReportsDir = "$ArtifactsDir\Tests";

# Nuget
$NugetPackageArtifacts = "$ArtifactsDir\Packages";

# Licensing
$LicensingArtifacts = "$ArtifactsDir\Licensing";

# Load partial scripts
. "$PSScriptRoot\Output.ps1";


# Functions
function Invoke-Initialize() {
    Write-Step "Initializing BuildToolkit"

    # First check the powershell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host ("The needed major powershell version for this script is 5. Your version: " + ($PSVersionTable.PSVersion.ToString()))
        exit 1;
    }

    # Initialize Folders
    CreateFolderIfNotExists $BuildTools;
    CreateFolderIfNotExists $ArtifactsDir;

    $DefaultVersion = "1.0.0"

    # Environment Variable Defaults
    if (-not $env:MORYX_BUILD_CONFIG) {
        $env:MORYX_BUILD_CONFIG = "Release";
    }

    if (-not $env:MORYX_BUILD_VERBOSITY) {
        $env:MORYX_BUILD_VERBOSITY = "minimal"
    }

    if (-not $env:MORYX_COMMERCIAL_BUILD) {
        $env:MORYX_COMMERCIAL_BUILD = $True;
    }

    if (-not $env:MORYX_TEST_VERBOSITY) {
        $env:MORYX_TEST_VERBOSITY = "normal"
    }

    if (-not $env:MORYX_NUGET_VERBOSITY) {
        $env:MORYX_NUGET_VERBOSITY = "normal"
    }

    if (-not $env:MORYX_OPTIMIZE_CODE) {
        $env:MORYX_OPTIMIZE_CODE = $True;
    }
    else {
        if (-not [bool]::TryParse($env:MORYX_OPTIMIZE_CODE,  [ref]$env:MORYX_OPTIMIZE_CODE)) {
            $env:MORYX_OPTIMIZE_CODE = $True;
        }
    }

    if (-not $env:MORYX_PACKAGE_TARGET) {
        $env:MORYX_PACKAGE_TARGET = "";
    }

    if (-not $env:MORYX_PACKAGE_TARGET_V3) {
        $env:MORYX_PACKAGE_TARGET_V3 = "";
    }

    if (-not $env:MORYX_ASSEMBLY_VERSION) {
        $env:MORYX_ASSEMBLY_VERSION = $DefaultVersion;
    }

    if (-not $env:MORYX_FILE_VERSION) {
        $env:MORYX_FILE_VERSION = $DefaultVersion;
    }

    if (-not $env:MORYX_INFORMATIONAL_VERSION) {
        $env:MORYX_INFORMATIONAL_VERSION = $DefaultVersion;
    }

    if (-not $env:MORYX_PACKAGE_VERSION) {
        $env:MORYX_PACKAGE_VERSION = $DefaultVersion;
    }

    # Printing Variables
    Write-Step "Printing global variables"
    Write-Variable "RootPath" $RootPath;
    Write-Variable "DocumentationDir" $DocumentationDir;
    Write-Variable "NunitReportsDir" $NunitReportsDir;

    Write-Step "Printing global scope"

    Write-Step "Printing environment variables"
    Write-Variable "MORYX_OPTIMIZE_CODE" $env:MORYX_OPTIMIZE_CODE;
    Write-Variable "MORYX_BUILD_CONFIG" $env:MORYX_BUILD_CONFIG;
    Write-Variable "MORYX_BUILD_VERBOSITY" $env:MORYX_BUILD_VERBOSITY;
    Write-Variable "MORYX_COMMERCIAL_BUILD" $env:MORYX_COMMERCIAL_BUILD;
    Write-Variable "MORYX_TEST_VERBOSITY" $env:MORYX_TEST_VERBOSITY;
    Write-Variable "MORYX_NUGET_VERBOSITY" $env:MORYX_NUGET_VERBOSITY;
    Write-Variable "MORYX_PACKAGE_TARGET" $env:MORYX_PACKAGE_TARGET;
    Write-Variable "MORYX_PACKAGE_TARGET_V3" $env:MORYX_PACKAGE_TARGET_V3;

    Write-Variable "MORYX_ASSEMBLY_VERSION" $env:MORYX_ASSEMBLY_VERSION;
    Write-Variable "MORYX_FILE_VERSION" $env:MORYX_FILE_VERSION;
    Write-Variable "MORYX_INFORMATIONAL_VERSION" $env:MORYX_INFORMATIONAL_VERSION;
    Write-Variable "MORYX_PACKAGE_VERSION" $env:MORYX_PACKAGE_VERSION;
}

function Invoke-Build([string]$Target = "", [string]$Source = "", [string]$Options = "") {
    Write-Step "Start Building"

    $additonalOptions = "";
    if (-not [string]::IsNullOrEmpty($Options)) {
        $additonalOptions = ",$Options";
    }

    $sourceOption = "";
    if (-not [string]::IsNullOrEmpty($Source)) {
        $sourceOption = "--source", $Source;
    }

    $msbuildParams = "Optimize=" + (&{If($env:MORYX_OPTIMIZE_CODE -eq $True) {"true"} Else {"false"}}) + ",DebugSymbols=true$additonalOptions";
    $buildArgs = "--configuration", "$env:MORYX_BUILD_CONFIG";
    $buildArgs += "--verbosity", $env:MORYX_BUILD_VERBOSITY;
    $buildArgs += $sourceOption
    $buildArgs += "-p:$msbuildParams"
	$buildArgs += "-p:Version=$env:MORYX_PACKAGE_VERSION"
    $buildArgs += "-p:AssemblyVersion=$env:MORYX_ASSEMBLY_VERSION"
    $buildArgs += "-p:FileVersion=$env:MORYX_FILE_VERSION"
    & dotnet build $Target @buildArgs
    Invoke-ExitCodeCheck $LastExitCode;
    Copy-Build-To-Artifacts $BuildArtifacts;
}

function Copy-Build-To-Artifacts([string]$TargetPath){
    ForEach($csprojItem in Get-ChildItem $SearchPath -Recurse -Include "*.csproj") { 
        # Check if the project should be packed
        if (-not (ShouldCreatePackage $csprojItem)) { continue; }

        $projectName = ([System.IO.Path]::GetFileNameWithoutExtension($csprojItem.Name));
        $assemblyPath = [System.IO.Path]::Combine($csprojItem.DirectoryName, "bin", $env:MORYX_BUILD_CONFIG);
        
        # Remove `staticwebassets.runtime.json` since it has no relevance for 
        # publishing but would break the build
        Get-ChildItem -Path $assemblyPath -Recurse -Filter "*.staticwebassets.runtime.json" | 
            ForEach-Object { Remove-Item $_.FullName -Force }

        # Check if the project was build
        If(-not (Test-Path $assemblyPath)){ continue; }

        $assemblyArtifactPath = [System.IO.Path]::Combine($TargetPath, $projectName, "bin", $env:MORYX_BUILD_CONFIG);
        CopyAndReplaceFolder $assemblyPath $assemblyArtifactPath;

        $objPath = [System.IO.Path]::Combine($csprojItem.DirectoryName, "obj");
        $objArtifactPath = [System.IO.Path]::Combine($TargetPath, $projectName, "obj");
        CopyAndReplaceFolder $objPath $objArtifactPath;

        $wwwrootPath = [System.IO.Path]::Combine($csprojItem.DirectoryName, "wwwroot");
        if(Test-Path $wwwrootPath) { 
            $wwwrootArtifactPath = [System.IO.Path]::Combine($TargetPath, $projectName, "wwwroot");
            CopyAndReplaceFolder $wwwrootPath $wwwrootArtifactPath;
        }

        Write-Host "Copied build of $csprojItem to artifacts..." 
    }
}

function Invoke-CoverTests($SearchPath = $RootPath, $SearchFilter = "*.csproj") {   
    Write-Step "Starting cover tests from $SearchPath"
    
    if (-not (Test-Path $SearchPath)) {
        Write-Host-Warning "$SearchPath does not exists, ignoring!";
        return;
    }

    $testProjects = Get-ChildItem $SearchPath -Recurse -Include $SearchFilter
    if ($testProjects.Length -eq 0) {
        Write-Host-Warning "No test projects found!"
        return;
    }

    ForEach($testProject in $testProjects ) { 
        $projectName = ([System.IO.Path]::GetFileNameWithoutExtension($testProject.Name));
        Write-Host "Testing ${projectName}...";
        
        dotnet test --no-restore ${testProject} --collect:"XPlat Code Coverage"
        Invoke-ExitCodeCheck $LastExitCode;
    }
}

function Get-CsprojIsSdkProject($CsprojItem) {
    [xml]$csprojContent = Get-Content $CsprojItem.FullName
    $sdkProject = $csprojContent.Project.Sdk;
    if ($null -ne $sdkProject) {
        return $true;
    }
    return $false;
}

function Invoke-Licensing($SearchPath = $RootPath) {
    Write-Step "Licensing"
    # Assign AxProtector.exe
    $AxProtectorNetCommand = (Get-Command "AxProtectorNet.exe" -ErrorAction SilentlyContinue);
    if ($null -eq $AxProtectorNetCommand)  {
        Write-Error "Unable to find AxProtectorNet.exe in your PATH. Download from https://www.wibu.com/support/developer/downloads-developer-software.html"
        exit 1;
    }
    $axProtectorDll = "$($env:AXPROTECTOR_SDK)\bin\dotnet_nc\AxProtector.dll"

    # Look for csproj in this directory
    $csprojItems = Get-ChildItem $SearchPath -Recurse -Include "*.csproj"
    if ($csprojItems.Length -eq 0) {
        Write-Host-Warning "No project to license found!"
        return;
    }

    $licenseCreationDate = Get-Date -Format "yyyy-MM-dd"
    ForEach($csprojItem in $csprojItems ) { 
        $projectName = ([System.IO.Path]::GetFileNameWithoutExtension($csprojItem.Name));
        if (IsLicensedProject $csprojItem){
            # Check if any assembly is available for licensing
            Write-Step "Trying to create licensed packages for $projectName..."
            $assemblyArtifactPath = [System.IO.Path]::Combine($BuildArtifacts, $projectName, "bin");
            $assemlbies = Get-ChildItem $assemblyArtifactPath -Recurse -Include "$projectName.dll" | ForEach-Object { if (!($_ -Match "\\ref\\" -or $_ -Match "/ref/")) { $_}}
            if ($assemlbies.Length -eq 0) {
                Write-Host-Warning "No assemblies found for licensing. Make sure the projects are build."
                exit 1;
            }
            
            # .NET 8
            $licensingConfig = [System.IO.Path]::Combine($csprojItem.DirectoryName, "protect.WibuCpsConf");
            if(Test-Path $licensingConfig) {
                Invoke-ProtectDotNet8 -csprojItem $csprojItem -licenseCreationDate $licenseCreationDate -projectName $projectName -assemlbies $assemlbies
            } else {
	            # Pre .NET 8 (MORYX 6)
                $projectName = ([System.IO.Path]::GetFileNameWithoutExtension($CsprojItem.Name));
                $licensingConfig = [System.IO.Path]::Combine($CsprojItem.DirectoryName, "AxProtector_$projectName.xml");
	            if(Test-Path $licensingConfig) {
	                Invoke-ProtectPreDotNet8 -csprojItem $csprojItem -licenseCreationDate $licenseCreationDate -projectName $projectName -assemlbies $assemlbies
	            }     
                else {
                    Write-Host-Error "No configuration found to protect assemblies."
                    exit 1;
                }
			}
        } else {
            Write-Host-Warning "Skipping $projectName"
        }
    }
}

function Invoke-ProtectDotNet8($csprojItem, $licenseCreationDate, $projectName, $assemlbies){
    # Update license config to include release date
    Write-Host "Updating release date to $licenseCreationDate for $projectName assemblies..."
    $licensingConfig = [System.IO.Path]::Combine($csprojItem.DirectoryName, "protect.WibuCpsConf");
    if(Test-Path $licensingConfig) {
        $content = (Get-Content -Path $licensingConfig) -replace "<RELEASE_DATE>", $licenseCreationDate
        Set-Content -Path $licensingConfig -Value $content
    }

    # Create a licensed assembly for each assembly available 
    Write-Host "Creating licensed assembly for $projectName..."
    ForEach($assembly in $assemlbies) {
        
        $assemblyTarget = GetTargetFrameworkDir $assembly
        $licensedAssemblyPath = [System.IO.Path]::Combine($LicensingArtifacts, $projectName, "bin", $env:MORYX_BUILD_CONFIG, $assemblyTarget)
        $licensedAssembly = [System.IO.Path]::Combine($licensedAssemblyPath, "$($projectName).dll");

        & dotnet "$($axProtectorDll)" $licensingConfig $assembly $licensedAssemblyPath

        if (-not (Test-Path $licensedAssembly)) {
            Write-Host-Error "Failed to create licensed assembly."
            exit 1;
        }
        else {
            Write-Host-Success "Licensed Assembly created successfully."
        }
    }
}

function Invoke-ProtectPreDotNet8($csprojItem, $licenseCreationDate, $projectName, $assemblies){
    $axProtectorNetCoreCli = "$($env:AXPROTECTOR_SDK)\bin\netstandard2.0\AxProtectorNet.exe";

    Write-Host "Updating release date to $licenseCreationDate for $projectName assemblies..."
    $licensingConfig = [System.IO.Path]::Combine($csprojItem.DirectoryName, "AxProtector_$projectName.xml");
    [xml]$licenseConfigContent = Get-Content $licensingConfig
    $licenseConfigContent.AxProtectorNet.CommandLine.ChildNodes | 
                            Where-Object{$_.InnerText -Match "-rd:"} | 
                            ForEach-Object{$_.InnerText="-rd:$licenseCreationDate,00:00:00"}
    Set-Content $licensingConfig $licenseConfigContent.OuterXml

    # Create a licensed assembly for each assembly available 
    Write-Host "Creating licensed assembly for $projectName..."
    ForEach($assembly in $assemlbies) {
        $assemblyTarget = GetTargetFrameworkDir $assembly
        $licensedAssembly = [System.IO.Path]::Combine($LicensingArtifacts, $projectName, "bin", $env:MORYX_BUILD_CONFIG, $assemblyTarget, "$projectName.dll");
        
        Write-Host "... licensing $assembly for $assemblyTarget"
        & $axProtectorNetCoreCli "@$licensingConfig" -o:$licensedAssembly $assembly
    }
}

function GetTargetFrameworkDir([string]$Assembly){
    $assemblyTargetFramework = Split-Path (Split-Path $assembly -Parent) -Leaf
    if ($assemblyTargetFramework -eq $env:MORYX_BUILD_CONFIG) {
        return ""
    }
    else {
        return $assemblyTargetFramework
    }
}

function Invoke-PackSdkProject($CsprojItem, [bool]$IncludeSymbols = $False) {
    if (-not (ShouldCreatePackage $CsprojItem)) { return; }

    $projectName = ([System.IO.Path]::GetFileNameWithoutExtension($CsprojItem.Name));
    Write-Host "Try to pack .NET SDK project: $($projectName) ...";
 
    # Restore build artifacts to project
    Write-Host "Copy build of $CsprojItem from artifacts..." 
    $artifacts = $BuildArtifacts;
    $buildPath = [System.IO.Path]::Combine($CsprojItem.DirectoryName, "bin", $env:MORYX_BUILD_CONFIG);
    $projectBinArtifacts = [System.IO.Path]::Combine($artifacts, $projectName, "bin", $env:MORYX_BUILD_CONFIG);
    CopyAndReplaceFolder $projectBinArtifacts $buildPath;
    $objPath = [System.IO.Path]::Combine($CsprojItem.DirectoryName, "obj");
    $projectObjArtifacts = [System.IO.Path]::Combine($artifacts, $projectName, "obj");
    CopyAndReplaceFolder $projectObjArtifacts $objPath;   


    if (IsLicensedProject $CsprojItem) {
        # Replace assemblies with licensed assemblies
        $licensedAssemblyRoot = [System.IO.Path]::Combine($LicensingArtifacts, $projectName)
        Write-Host "Replace assemblies of $projectName with licensed assemblies..." 
        if (-not (Test-Path $licensedAssemblyRoot)){
            Write-Host-Error "No licensed *.dll found! Make sure the assembly was licensed."
            Invoke-ExitCodeCheck "1";
        }

        $licensedAssemblyRootPattern = [System.IO.Path]::Combine($licensedAssemblyRoot, "*")

        $assemblyFiles = Get-ChildItem -Path $licensedAssemblyRootPattern -Recurse -Filter "*.dll" -Exclude "*wupi.net.dll" | 
           Where-Object{-not ($_ -match "WibuCmNet")}

        $assemblyFiles |
           ForEach-Object{CopyAssemblyVersion -Assembly $_ -DestinationRoot $buildPath}

        $assemblyFiles |
            ForEach-Object{CopyAssemblyVersion -Assembly $_ -DestinationRoot $commercialPath}
    }
    
    #Pack
    $packargs = "--output", $NugetPackageArtifacts;
    $packargs += "--configuration", "$env:MORYX_BUILD_CONFIG";
    $packargs += "-p:PackageVersion=$env:MORYX_PACKAGE_VERSION";
    $packargs += "--verbosity", "$env:MORYX_NUGET_VERBOSITY";
    $packargs += "--no-build";

    if ($IncludeSymbols) {
        $packargs += "--include-symbols";
        $packargs += "--include-source";
    }

    $csprojFullName = $CsprojItem.FullName;
    $output =  dotnet pack "$csprojFullName" @packargs 
    
    # Check dotent pack output
    $output
    If ($output -match "is building"){
        # This condition is left for documentation purposes

        # This was previously handled as an error. But having this output seems to 
        # not affect the commercial build. 
        # If `pack --no-build` would initiate a new build, that should already be 
        # recognized by the build tool itself and lead to a `Build FAILED`, having
        # the error code `NETSDK1085`. This is handled below.

        Write-Host-Success "$projectName sucessfully packed."
    }
    elseif (($output -match "NETSDK1085")) {
        Write-Host-Error "`dotnet` started an unintended build process while packaging. Abort packaging to not override licensed assemblies..."
        Invoke-ExitCodeCheck "1";
    }
    elseif (($output -match "Build FAILED.")) {
        Write-Host-Error "`dotnet` failed packaging... Abort Packaging..."
        Invoke-ExitCodeCheck "1";
    }
    else {
        Write-Host-Success "$projectName sucessfully packed."
    }
}

function Invoke-PackFrameworkProject($CsprojItem, [bool]$IsTool = $False, [bool]$IncludeSymbols = $False, [string]$ArtifactsDir = $NugetPackageArtifacts) {
    Write-Host "Try to pack .NET Framework project: $CsprojItem.Name ...";

    # Check if there is a matching nuspec for the proj
    $csprojFullName = $CsprojItem.FullName;
    $nuspecPath = [IO.Path]::ChangeExtension($csprojFullName, "nuspec")
    if(-not (Test-Path $nuspecPath)) {
        Write-Host-Warning "Nuspec for project not found: $CsprojItem.Name";
        return;
    }

    $packargs = "-o", "$ArtifactsDir";
    # $packargs += "-includereferencedprojects";
    $packargs += "-p:PackageVersion=$($env:MORYX_PACKAGE_VERSION)";
    $packargs += "-c", $env:MORYX_BUILD_CONFIG;
    $packargs += "--verbosity", "$env:MORYX_NUGET_VERBOSITY";
    $packargs += "--no-build";

    if ($IncludeSymbols) {
        $packargs += "--include-symbols";
    }

    ## use <PackAsTool>true</PackAsTool> in .csproj
    # if ($IsTool) {
    #     $packargs += "-Tool";
    # }

    # Call nuget with default arguments plus optional
    & dotnet pack "$csprojFullName" @packargs
    Invoke-ExitCodeCheck $LastExitCode;
}

function Invoke-Pack($ProjectItem, [bool]$IsTool = $False, [bool]$IncludeSymbols = $False) {
    CreateFolderIfNotExists $NugetPackageArtifacts;

    if (Get-CsprojIsSdkProject($ProjectItem)) {
        Invoke-PackSdkProject $ProjectItem $IncludeSymbols;
    }
    else {
        Invoke-PackFrameworkProject $ProjectItem $IsTool $IncludeSymbols;
    }
}

function Invoke-PackAll([switch]$Symbols = $False) {
    Write-Host "Looking for .csproj files..."
    # Look for csproj in this directory
    foreach ($csprojItem in Get-ChildItem $RootPath -Recurse -Filter *.csproj) {
        Invoke-Pack -ProjectItem $csprojItem -IncludeSymbols $Symbols
    }
}

function CopyAssemblyVersion([string]$Assembly, [string]$DestinationRoot){
    $frameworkDir = GetTargetFrameworkDir $Assembly
    $destination = [System.IO.Path]::Combine($destinationRoot, $frameworkDir)
    Copy-Item -Path $assembly -Destination $destination -Force
    Write-Host "Replaced [$destination] with [$assembly]" -ForegroundColor Green
}

function Invoke-Publish([string]$NugetApiKey, [string]$PackageTarget, [string]$SymbolTarget) {
    $artifactsDir = $NugetPackageArtifacts;
    Write-Host "Pushing packages from $ArtifactsDir to $PackageTarget"
    
    $packages = Get-ChildItem $artifactsDir -Recurse -Include *.nupkg
    if ($packages.Length -gt 0 -and [string]::IsNullOrEmpty($PackageTarget)) {
        Write-Host-Error "There is no package target given. Set the environment varialble PackageTarget to publish packages.";
        Invoke-ExitCodeCheck 1;
    }

    foreach ($package in $packages) {
        Write-Host "Pushing package $package"
        nuget push $package -ApiKey $NugetApiKey -NoSymbols -SkipDuplicate -Source $PackageTarget
        Invoke-ExitCodeCheck $LastExitCode;
    }

    $symbolPackages = Get-ChildItem $artifactsDir -Recurse -Include *.snupkg
    if ($symbolPackages.Length -gt 0 -and [string]::IsNullOrEmpty($SymbolTarget)) {
        Write-Host-Error "There is no package (v3) target given. Set the environment varialble MORYX_PACKAGE_TARGET_V3 to publish snupkg symbol packages.";
        Invoke-ExitCodeCheck 1;
    }

    foreach ($symbolPackage in $symbolPackages) {
        Write-Host "Pushing symbol (snupkg) $symbolPackage"
        nuget push $symbolPackage -ApiKey $NugetApiKey -SkipDuplicate -Source $SymbolTarget
        Invoke-ExitCodeCheck $LastExitCode;
    }
}

function ShouldCreatePackage($csprojItem){
    $csprojFullName = $csprojItem.FullName;
    [xml]$csprojContent = Get-Content $csprojFullName
    $createPackage = $csprojContent.Project.PropertyGroup | Where-Object {-not ($null -eq $_.IsPackable)} | ForEach-Object{$_.IsPackable}
    if ($null -eq $createPackage -or "false" -eq $createPackage) {
        Write-Host-Warning "Skipping $csprojItem..."
        return $False;
    }
    return $True;
}

function IsLicensedProject($CsprojItem){
    $licensingConfig = [System.IO.Path]::Combine($CsprojItem.DirectoryName, "protect.WibuCpsConf");

    # Fallback for MORYX 6 most configs were stored as `AxProtector_<project>.xml`
    $projectName = ([System.IO.Path]::GetFileNameWithoutExtension($CsprojItem.Name));
    $axProtectorFile = [System.IO.Path]::Combine($CsprojItem.DirectoryName, "AxProtector_$projectName.xml");

    return (Test-Path $licensingConfig) -or (Test-Path $axProtectorFile)
}

function CreateFolderIfNotExists([string]$Folder) {
    if (-not (Test-Path $Folder)) {
        Write-Host "Creating missing directory '$Folder'"
        New-Item $Folder -Type Directory | Out-Null
    }
}

function CopyAndReplaceFolder([string]$SourceDir, [string]$TargetDir) {
    # Remove old folder if exists
    if (Test-Path $TargetDir) {
        Write-Host "Target path already exists, replacing ..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $TargetDir
    }

    # Copy to target path
    Copy-Item -Path $SourceDir -Recurse -Destination $TargetDir -Container
}
