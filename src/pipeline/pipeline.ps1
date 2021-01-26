#Requires -Modules Az.Accounts, Az.PolicyInsights, Az.Resources

#
# Functions
#
function Publish-Definition {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Policy")]
        [string]$Type,

        [Parameter(Mandatory = $true, ParameterSetName = 'ManagementGroup')]
        [ValidateSet([ManagementGroups])]
        [String]$ManagementGroup,

        [Parameter(Mandatory = $true, ParameterSetName = 'Subscription')]
        [ValidateSet([Subscriptions])]
        [String]$Subscription,

        [Parameter(Mandatory = $false)]
        [ValidateSet([Names])]
        [string]$Name
    )

    begin {
        Write-Debug -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
    }

    process {
        Write-Debug -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        # Load metadata
        Write-Verbose -Message "- Load metadata"
        $script:metadata = Get-Content -Path "./src/pipeline/metadata.json" | ConvertFrom-Json

        # Parse metadata
        Write-Verbose -Message "- Parse metadata"
        $script:metadata = $script:metadata | Where-Object -FilterScript { $_.assignmentName -eq $Name }
        $script:definitionName = $script:metadata | Select-Object -ExpandProperty name
        $script:definitionDisplayName = $script:metadata | Select-Object -ExpandProperty displayName
        $script:definitionPath = $script:metadata | Select-Object -ExpandProperty definitionPath
        $script:definitionParametersPath = $script:metadata | Select-Object -ExpandProperty parameterPath
        $script:assignmentName = $script:metadata | Select-Object -ExpandProperty assignmentName

        switch ($PSCmdlet.ParameterSetName) {
            "ManagementGroup" {
                # Get management group
                Write-Verbose -Message "- Retrieve management group"
                $script:managementGroupId = Get-AzManagementGroup | Where-Object -FilterScript { $_.DisplayName -eq $ManagementGroup } | Select-Object -ExpandProperty Id
            }
            "Subscription" {
                # Get subscription
                Write-Verbose -Message "- Retrieve subscription"
                $script:subscriptionId = (Get-AzSubscription -SubscriptionName $subscription).Id
            }
        }

        # Generate scope
        Write-Verbose -Message "- Generate scope"
        switch ($PSCmdlet.ParameterSetName) {
            "ManagementGroup" {
                $script:scope = ("/providers/Microsoft.Management/managementGroups/" + $script:managementGroupId)
            }
            "Subscription" {
                $script:scope = ("/subscriptions/" + $script:subscriptionId)
            }
        }

        # Generate params
        Write-Verbose -Message "- Generate params"
        switch ($type) {
            "Policy" {
                switch ($PSCmdlet.ParameterSetName) {
                    "ManagementGroup" {
                        $params = @{
                            Name                = $script:definitionName
                            DisplayName         = $script:definitionDisplayName
                            Policy              = $script:definitionPath
                            Parameter           = $script:definitionParametersPath
                            ManagementGroupName = $script:managementGroupId
                        }
                    }
                    "Subscription" {
                        $params = @{
                            Name           = $script:definitionName
                            DisplayName    = $script:definitionDisplayName
                            Policy         = $script:definitionPath
                            Parameter      = $script:definitionParametersPath
                            SubscriptionId = $script:subscriptionId
                        }
                    }
                }
            }
        }

        # Apply definition
        switch ($type) {
            "Policy" {
                Write-Verbose -Message "- Retrieve assignment"
                $script:assignment = Get-AzPolicyAssignment -Scope $script:scope | Where-Object -FilterScript { $_.Name -eq $script:assignmentName }
                if ($null -ne $script:assignment) {
                    Write-Verbose -Message "- Remove assignment"
                    Remove-AzPolicyAssignment -Name $script:assignmentName -Scope $script:scope
                }

                Write-Verbose -Message "- Retrieve definition"
                switch ($PSCmdlet.ParameterSetName) {
                    "ManagementGroup" {
                        $script:definition = Get-AzPolicyDefinition -ManagementGroupName $script:managementGroupId -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
                    }
                    "Subscription" {
                        $script:definition = Get-AzPolicyDefinition  -SubscriptionId $script:subscriptionId -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
                    }
                }

                if ($null -eq $script:definition) {
                    Write-Verbose -Message "- Create definition"
                    New-AzPolicyDefinition @params
                }
                else {
                    Write-Verbose -Message "- Remove definition"
                    switch ($PSCmdlet.ParameterSetName) {
                        "ManagementGroup" {
                            Remove-AzPolicyDefinition -Name $script:definitionName -ManagementGroupName $script:managementGroupId -Force
                        }
                        "Subscription" {
                            Remove-AzPolicyDefinition -Name $script:definitionName -SubscriptionId $script:subscriptionId -Force
                        }
                    }

                    Write-Verbose -Message "- Create definition"
                    New-AzPolicyDefinition @params
                }
            }
        }
    }

    end {
        Write-Debug -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}

function Publish-Assignment {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Policy")]
        [string]$Type,

        [Parameter(Mandatory = $true, ParameterSetName = 'ManagementGroup')]
        [String]$ManagementGroup,

        [Parameter(Mandatory = $true, ParameterSetName = 'Subscription')]
        [String]$Subscription,

        [Parameter(Mandatory = $false)]
        [ValidateSet([Names])]
        [string]$Name
    )

    begin {
        Write-Debug -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
    }

    process {
        Write-Debug -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        # Load metadata
        Write-Verbose -Message "- Load metadata"
        $script:metadata = Get-Content -Path "./src/pipeline/metadata.json" | ConvertFrom-Json

        # Parse metadata
        Write-Verbose -Message "- Parse metadata"
        $script:metadata = $script:metadata | Where-Object -FilterScript { $_.assignmentName -eq $Name }
        $script:definitionDisplayName = $script:metadata | Select-Object -ExpandProperty displayName
        $script:assignmentName = $script:metadata | Select-Object -ExpandProperty assignmentName
        $script:assignmentInputsPath = $script:metadata | Select-Object -ExpandProperty inputPath

        # Generate scope
        Write-Verbose -Message "- Generate scope"
        switch ($PSCmdlet.ParameterSetName) {
            "ManagementGroup" {
                Write-Verbose -Message "- Retrieve management group"
                $script:managementGroupId = Get-AzManagementGroup | Where-Object -FilterScript { $_.DisplayName -eq $ManagementGroup } | Select-Object -ExpandProperty Id
                $script:scope = ("/providers/Microsoft.Management/managementGroups/" + $script:managementGroupId)
            }
            "Subscription" {
                # Get subscription
                Write-Verbose -Message "- Retrieve subscription"
                $script:subscriptionId = (Get-AzSubscription -SubscriptionName $subscription).Id
                $script:scope = ("/subscriptions/" + $script:subscriptionId)
            }
        }

        # Generate params
        Write-Verbose -Message "- Generate params"
        switch ($type) {
            "Policy" {
                Write-Verbose -Message "- Retrieve definition"
                switch ($PSCmdlet.ParameterSetName) {
                    "ManagementGroup" {
                        $script:definition = Get-AzPolicyDefinition -ManagementGroupName $script:managementGroupId -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
                        if ($null -eq $script:definition) {
                            Write-Error -Message "Unable to locate definition" -ErrorAction Stop
                        }
                    }
                    "Subscription" {
                        $script:definition = Get-AzPolicyDefinition -SubscriptionId $script:subscriptionId -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
                        if ($null -eq $script:definition) {
                            Write-Error -Message "Unable to locate definition" -ErrorAction Stop
                        }
                    }
                }

                switch ($script:metadata["$group"]["$policy"].effect) {
                    "deployIfNotExists" {
                        $params = @{
                            Name             = $script:assignmentName
                            DisplayName      = $script:definitionDisplayName
                            PolicyDefinition = $script:definition
                            PolicyParameter  = $script:assignmentInputsPath
                            Scope            = $script:scope
                            AssignIdentity   = $true
                            Location         = 'uksouth'
                        }
                    }
                }
            }
        }

        # Apply assignment
        switch ($type) {
            "Policy" {
                Write-Verbose -Message "- Retrieve assignment"
                $script:assignment = Get-AzPolicyAssignment -Scope $script:scope | Where-Object -FilterScript { $_.Name -eq $script:assignmentName }

                # Remove assignments
                if ($null -ne $script:assignment) {
                    Write-Verbose -Message "- Remove assignment"
                    Remove-AzPolicyAssignment -Name $script:assignment.Name -Scope $script:scope

                    $script:definitionId = ($script:definition.properties.policyRule.then.details.roleDefinitionIds -split "/")[4]
                    $script:objectId = ($script:assignment.Identity.principalId)

                    Write-Verbose -Message "- Remove assignment"
                    Remove-AzRoleAssignment -ObjectId "" -Scope $script:scope -RoleDefinitionId $script:definitionId
                }

                # New assignment
                Write-Verbose -Message "- Create assignment"
                New-AzPolicyAssignment @params -WarningAction SilentlyContinue

                # Get assignment
                Write-Verbose -Message "- Retrieve assignment"
                $script:assignment = Get-AzPolicyAssignment -Scope $script:scope | Where-Object -FilterScript { $_.Name -eq $script:assignmentName }
                $script:definitionIds = ($script:definition.properties.policyRule.then.details.roleDefinitionIds)
                $script:objectId = ($script:assignment.Identity.principalId)

                Write-Verbose -Message "- Start sleep"
                Start-Sleep -Seconds 15

                # New assignment
                Write-Verbose -Message "- Create assignment"
                $script:definitionIds | ForEach-Object {
                    $script:definitionId = ($_ -split "/")[4]
                    New-AzRoleAssignment -Scope $script:scope -ObjectId $script:objectId -RoleDefinitionId $script:definitionId
                }
            }
        }

        # Start scan
        Start-AzPolicyComplianceScan -AsJob | Select-Object -ExpandProperty Id
    }

    end {
        Write-Debug -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}

#
# Classes
#
class ManagementGroups : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        $managementGroups = (Get-AzManagementGroup).DisplayName
        return $managementGroups
    }
}
class Subscriptions : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        $subscriptions = (Get-AzSubscription).Name | Sort-Object
        return $subscriptions
    }
}
class Names : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        $names = (Get-Content -Path "./src/pipeline/metadata.json" | ConvertFrom-Json).assignmentName
        return $names
    }
}
