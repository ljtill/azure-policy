# pipeline/

## Usage

> _CmdletBinding_ is available on all functions (_-Verbose_)

### Scope _Management Groups_

```powershell
. ./src/pipelines/build.ps1
Publish-Definition -Type "Policy" -ManagementGroup "" -Name ""
Publish-Definition -Type "Initiative" -ManagementGroup ""
```

```powershell
. ./src/pipelines/release.ps1
Publish-Assignment -Type "Policy" -ManagementGroup "" -Name ""
Publish-Assignment -Type "Initiative" -ManagementGroup ""
```

### Scope _Subscription_

```powershell
. ./src/pipelines/build.ps1
Publish-Definition -Type "Policy" -Subscription "" -Name ""
Publish-Definition -Type "Initiative" -Subscription ""
```

```powershell
. ./src/pipelines/release.ps1
Publish-Assignment -Type "Policy" -Subscription "" -Name ""
Publish-Assignment -Type "Initiative" -Subscription ""
```

### Policies

| Category   | Name              | Description |
| :--------- | :---------------- | :---------- |
| Resiliency | Level1            |             |
| Resiliency | Level2            |             |
| Resiliency | Level3            |             |
| Undefined  | AvailabilitySets  |             |
| Undefined  | AvailabilityZones |             |
| Undefined  | ManagedDisks      |             |
| Undefined  | MixedDisks        |             |

> Define required policies within the _metadata.json_ file
