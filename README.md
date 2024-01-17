# setup-buildtoolkit

Composite GitHub Action which deploys MORYX' *BuildToolkit* to the working 
directory

## Usage

Building a solution

```yml
  - name: 🧰 Setup BuildToolkit
    uses: moryx-industry/setup-buildtoolkit@main

  - name: 🔨 Build
      .\set-version.ps1 -RefName ${{ github.ref_name }} -IsTag ${{ github.ref_type == 'tag' && 1 || 0 }} -BuildNumber ${{ github.run_number }} -CommitHash ${{ github.sha }}
      .\build.ps1 -Build -PackageSource ${{ github.workspace }}/.nuget/packages
    shell: pwsh
```
Running tests

```yml
  - name: 🧰 Setup BuildToolkit
    uses: moryx-industry/setup-buildtoolkit@main

  - name: 🧪 Run tests 
    run: .\build.ps1 -UnitTests
    shell: pwsh
```