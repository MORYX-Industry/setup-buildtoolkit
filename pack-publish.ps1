param (
    [Parameter()]
    [string]$NugetApiKey = "",

    [Parameter()]
    [string]$PackageTarget = "",

    [Parameter()]
    [string]$SymbolTarget = ""
)

# Load Toolkit
. ".build\BuildToolkit.ps1"

# Initialize Toolkit
Invoke-Initialize;

Invoke-PackAll
Invoke-Publish -NugetApiKey $NugetApiKey -PackageTarget $PackageTarget -SymbolTarget $SymbolTarget

Write-Host "Success!"
