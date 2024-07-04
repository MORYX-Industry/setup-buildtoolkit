param (
  [Parameter()]
  [string]$RefName = "",
  
  [Parameter()]
  [bool]$IsTag = $False,
  
  [Parameter()]
  [string]$BuildNumber = "0",

  [Parameter()]
  [string]$CommitHash = ""
)

# Load Toolkit
. ".build\Output.ps1";

function Read-VersionFromRef([string]$MajorMinorPatch, [string]$RefName = "", [bool]$IsTag = $False, [string]$BuildNumber = "0") {
  function preReleaseVersion ([string] $name)
  {
      $name = $name.Replace("/","-").ToLower();
      return "$MajorMinorPatch-$name.$BuildNumber";
  }

  $ref = "";
  if ($RefName -ne "") {
      $ref = $RefName; # The branch or tag name for which project is built

      if ($IsTag) { # The commit tag name. Present only when building tags.
          if ($RefName -like "v*") {
              # Its a version tag
              $version = $ref.substring(1) ;
          }
          else {
              # Just a tag
              $version = preReleaseVersion($ref);
          }
      }
      else {
          $version = preReleaseVersion($ref);
      }

  }
  else { # Local build
      Write-Host "Reading version from 'local'";
      $version = preReleaseVersion("local");
  }

  return $version;
}

function Set-Version ([string]$version, [string]$GitCommitHash) {
  $semVer2Regex = "^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-(?<prerelease>(0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$";

  Write-Host "Setting environment version to $version";

  # Match semVer2 regex
  $regexMatch = [regex]::Match($version, $semVer2Regex);
  if (-not $regexMatch.Success) {
      Write-Host "Could not parse version: $version";
      Invoke-ExitCodeCheck 1;
  }

  # Extract groups
  $matchgroups = $regexMatch.captures.groups;
  $majorGroup = $matchgroups[3];
  $minorGroup = $matchgroups[4];
  $patchGroup = $matchgroups[5];
  $preReleaseGroup = $matchgroups[6];
  $buildNumber = $matchgroups[2];

  # Compose Major.Minor.Patch
  $mmp = $majorGroup.Value + "." + $minorGroup.Value + "." + $patchGroup.Value;

  # Check if it is a pre release
  $env:MORYX_ASSEMBLY_VERSION = $majorGroup.Value + ".0.0.0" # 3.0.0.0

  if ($preReleaseGroup.Success) {
      $env:MORYX_FILE_VERSION = $mmp + "." + $buildNumber; # 3.1.2.42
      $env:MORYX_INFORMATIONAL_VERSION = $mmp + "-" + $preReleaseGroup.Value + "+" + $GitCommitHash; # 3.1.2-beta.1+d95a996ed5ba14a1421dafeb844a56ab08211ead
      $env:MORYX_PACKAGE_VERSION = $mmp + "-" + $preReleaseGroup.Value;
  } else {
      $env:MORYX_INFORMATIONAL_VERSION = $mmp + "+" + $GitCommitHash; # 3.1.2+d95a996ed5ba14a1421dafeb844a56ab08211ead
      $env:MORYX_PACKAGE_VERSION = $mmp;
      $env:MORYX_FILE_VERSION = $mmp + ".0";
  }
}


$Version = Read-VersionFromRef -MajorMinorPatch (Get-Content "VERSION") -RefName $RefName -IsTag $IsTag -BuildNumber $BuildNumber
Set-Version $Version $CommitHash;

Write-Step "Set versions to ..."
Write-Variable "MORYX_ASSEMBLY_VERSION" $env:MORYX_ASSEMBLY_VERSION;
Write-Variable "MORYX_FILE_VERSION" $env:MORYX_FILE_VERSION;
Write-Variable "MORYX_INFORMATIONAL_VERSION" $env:MORYX_INFORMATIONAL_VERSION;
Write-Variable "MORYX_PACKAGE_VERSION" $env:MORYX_PACKAGE_VERSION;