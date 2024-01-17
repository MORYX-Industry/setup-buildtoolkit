param (
  [Parameter()]
  [string]$SearchFilter = "*.Tests.csproj"
)

# Load Toolkit
. ".build\BuildToolkit.ps1"

# Initialize Toolkit
Invoke-Initialize;

Write-Host "unit testing starts here"
Invoke-CoverTests -SearchFilter $SearchFilter 

Write-Host "Success!"
