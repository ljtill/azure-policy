# Pipeline

## Usage

> _CmdletBinding_ is available on all functions (_-Verbose_)

### Scope _Management Groups_

```powershell
. ./src/pipelines/build.ps1
Publish-Definition -Type "Policy" -ManagementGroup "" -Name ""
```

```powershell
. ./src/pipelines/release.ps1
Publish-Assignment -Type "Policy" -ManagementGroup "" -Name ""
```

### Scope _Subscription_

```powershell
. ./src/pipelines/build.ps1
Publish-Definition -Type "Policy" -Subscription "" -Name ""
```

```powershell
. ./src/pipelines/release.ps1
Publish-Assignment -Type "Policy" -Subscription "" -Name ""
```
