param (
    [Parameter()]
    [string]$PackageSource = ""
)

# Load Toolkit
. ".build\BuildToolkit.ps1"

# Initialize Toolkit
Invoke-Initialize;

Invoke-Build -Source $PackageSource

Write-Host "Success!"
