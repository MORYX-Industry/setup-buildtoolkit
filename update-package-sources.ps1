param (
    [Parameter()]
    [string]$MoryxNpmSource = ""
)

# Load Toolkit
. ".build\Output.ps1";

# Folder Pathes
$NugetConfig = ".\NuGet.Config"
$GithubNugetConfig = ".\NuGet-Github.Config"
$internalMoryxNpmSource = 'http://dockerregistry.europe.phoenixcontact.com/repository/pxc-npm-moryx-proxy'
$internalNpmSource = 'http://dockerregistry.europe.phoenixcontact.com/repository/pxc-npm-proxy'
$npmSource = 'https://registry.npmjs.org'

$internalMoryxNpmPackagePath = '@moryx/ngx-web-framework/-/ngx-web-framework'
$moryxNpmPackagePath = '@moryx/ngx-web-framework/-/@moryx/ngx-web-framework'

function Update-Nuget-Sources {
    if (Test-Path -Path $GithubNugetConfig) {
        Copy-Item -Path $GithubNugetConfig -Destination $NugetConfig -Force
    } else {
        Write-Output "NuGet-Github.Config does not exist keeping current content in Nuget.Config"
    }
}

function Update-Npm-Sources {
    # Get all .npmrc and package-lock.json files recursively
    $files = (Get-ChildItem -Path . -Recurse -Force -Include '.npmrc', 'package-lock.json') -notlike '*node_modules*'

    foreach ($file in $files) {
        # Read the content of the file
        $content = Get-Content -Path $file -Raw

        # Replace the old strings with the new strings
        $content = $content -replace [regex]::Escape($internalMoryxNpmPackagePath), $moryxNpmPackagePath
        $content = $content -replace [regex]::Escape($internalMoryxNpmSource), $MoryxNpmSource
        $content = $content -replace [regex]::Escape($internalNpmSource), $npmSource

        # Write the updated content back to the file
        Set-Content -Path $file -Value $content
    }

    return $files
}

function Get-Nuget-Package-Source() {
    # Load the XML content from the Nuget.config file
    [xml]$xmlContent = Get-Content -Path $NugetConfig

    # Retrieve the value for the key "nuget.org"
    $packageSourceValue = $xmlContent.configuration.packageSources.add | Where-Object { $_.key -eq "nuget.org" } | Select-Object -ExpandProperty value
    return $packageSourceValue
}

Write-Step "Update package sources to..."

Update-Nuget-Sources
$nugetOrgValue = Get-Nuget-Package-Source
$updatedFiles = Update-Npm-Sources

Write-Variable "NUGET_SOURCE" $nugetOrgValue;
Write-Variable "NPM_SOURCE" $npmSource;
Write-Variable "MORYX_NPM_SOURCE" $MoryxNpmSource;
Write-Output "Updated files..."
foreach ($updatedFile in $updatedFiles) {
    Write-Output $updatedFile
}