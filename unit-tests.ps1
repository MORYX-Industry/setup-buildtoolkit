param (
)

# Load Toolkit
. ".build\BuildToolkit.ps1"

# Initialize Toolkit
Invoke-Initialize;

Write-Host "unit testing starts here"
Invoke-CoverTests -SearchFilter "*.Tests.csproj" 

Write-Host "Success!"
