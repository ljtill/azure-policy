#Requires -Modules Az.Accounts, Az.Resources

function Connect-ServicePrincipal {

    [CmdletBinding()]
    param (
        [Parameter()]
        $TenantId,

        [Parameter()]
        $SubscriptionId,

        [Parameter()]
        $ApplicationId,

        [Parameter()]
        $ClientSecret
    )

    begin {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")

        $clientSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $applicationId, $clientSecret
    }

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        try {
            Connect-AzAccount -TenantId $tenantId -SubscriptionId $SubscriptionId -Credential $credential -ServicePrincipal -ErrorAction Stop
        }
        catch {
            Write-Error -Message $_.Exception.Message
        }
    }

    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}
function Publish-Definition {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ManagementGroup')]
        [String]$ManagementGroup,

        [Parameter(Mandatory = $true, ParameterSetName = 'Subscription')]
        [String]$Subscription,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Initiative", "Policy")]
        [string]$Type,

        [Parameter(Mandatory = $false)]
        [ValidateSet("group1")]
        [string]$Group,

        [Parameter(Mandatory = $false)]
        [ValidateSet("policy1", "policy2", "policy3")]
        [string]$Policy
    )

    begin {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")

        $script:category = '{"category":"Resiliency"}'
        $script:metadata = Get-Content -Path "./src/pipeline/metadata.json" | ConvertFrom-Json -AsHashtable
        switch ($PSCmdlet.ParameterSetName) {
            "ManagementGroup" {
                $script:scope = ("/providers/Microsoft.Management/managementGroups/" + $managementGroup)
            }
            "Subscription" {
                $script:scope = ("/subscriptions/" + (Get-AzSubscription -SubscriptionName $subscription).Id)
            }
        }

        switch ($type) {
            "Initiative" {
                $script:definitions = Get-AzPolicyDefinition -Custom | Where-Object -FilterScript { $_.Properties.metadata.category -eq "Resiliency" }
                $script:policies = @()
                $script:definitions | ForEach-Object {
                    $script:definitionId = $_ | Select-Object -ExpandProperty "PolicyDefinitionId"
                    $script:policies += New-Object PSObject –Property @{ policyDefinitionId = $script:definitionId }
                }
                switch ($PSCmdlet.ParameterSetName) {
                    "ManagementGroup" {
                        $params = @{ 
                            Name             = (New-Guid).Guid
                            DisplayName      = "CET Resiliency - Compute"
                            Description      = "-"
                            ManagementGroup  = $managementGroup
                            PolicyDefinition = ($script:policies | ConvertTo-Json -AsArray)
                            Metadata         = $script:category 
                        }
                    }
                    "Subscription" {
                        $params = @{ 
                            Name             = (New-Guid).Guid
                            DisplayName      = "CET Resiliency - Compute"
                            Description      = "-"
                            PolicyDefinition = ($script:policies | ConvertTo-Json -AsArray)
                            Metadata         = $script:category 
                        }
                    }
                }

                
            }
            "Policy" {
                $script:assignmentName = $script:metadata["$group"]["$policy"].assignmentName
                $script:definitionDisplayName = $script:metadata["$group"]["$policy"].displayName
                $script:definitionPath = $script:metadata["$group"]["$policy"].definitionPath
                $script:parameterPath = $script:metadata["$group"]["$policy"].parameterPath
                switch ($PSCmdlet.ParameterSetName) {
                    "ManagementGroup" {
                        $params = @{
                            Name            = (New-Guid).Guid
                            DisplayName     = $script:definitionDisplayName
                            ManagementGroup = $managementGroup
                            Metadata        = $script:category
                            Policy          = $script:definitionPath
                            Parameter       = $script:parameterPath
                        }
                    }
                    "Subscription" {
                        $params = @{
                            Name        = (New-Guid).Guid
                            DisplayName = $script:definitionDisplayName
                            Metadata    = $script:category
                            Policy      = $script:definitionPath
                            Parameter   = $script:parameterPath
                        }
                    }
                }
            }
        }

    }

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        switch ($type) {
            "Initiative" {
                Write-Verbose -Message "- Retrieve initiative assignment"
                $script:assignment = Get-AzPolicyAssignment | Where-Object -FilterScript { $_.Properties.metadata.category -eq "Resiliency" }
                if ($null -ne $script:assignment) {
                    Write-Verbose -Message "- Remove initiative assignment"
                    Remove-AzPolicyAssignment -Name $script:assignment.Name -Scope $script:scope
                }

                Write-Verbose -Message "- Retrieve initiative definition"
                $script:definition = Get-AzPolicySetDefinition -Custom | Where-Object -FilterScript { $_.Properties.metadata.category -eq "Resiliency" }
                if ($null -eq $script:definition) {
                    Write-Verbose -Message "- New initiative definition"
                    New-AzPolicySetDefinition @params
                }
                else {
                    Write-Verbose -Message "- Update initiative definition"
                    switch ($PSCmdlet.ParameterSetName) {
                        "ManagementGroup" {
                            Set-AzPolicySetDefinition -Name $script:definition.Name -ManagementGroupName $managementGroup -PolicyDefinition ($script:policies | ConvertTo-Json -AsArray)
                        }
                        "Subscription" {
                            Set-AzPolicySetDefinition -Name $script:definition.Name -PolicyDefinition ($script:policies | ConvertTo-Json -AsArray)
                        }
                    }
                }
            }
            "Policy" {
                Write-Verbose -Message "- Retrieve policy assignment"
                $script:assignment = Get-AzPolicyAssignment | Where-Object -FilterScript { $_.Properties.metadata.category -eq "Resiliency" }
                if ($null -ne $script:assignment) {
                    Write-Verbose -Message "- Remove policy assignment"
                    Remove-AzPolicyAssignment -Name $script:assignmentName -Scope $script:scope
                }

                Write-Verbose -Message "- Retrieve policy definition"
                $script:definition = Get-AzPolicyDefinition -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
                if ($null -eq $script:definition) {
                    Write-Verbose -Message "- Create policy definition"
                    New-AzPolicyDefinition @params
                }
                else {
                    Write-Verbose -Message "- Update policy definition"
                    switch ($PSCmdlet.ParameterSetName) {
                        "ManagementGroup" {
                            Set-AzPolicyDefinition -Name $script:definition.Name -ManagementGroupName $managementGroup -Policy $script:definitionPath -Parameter $script:parameterPath
                        }
                        "Subscription" {
                            Set-AzPolicyDefinition -Name $script:definition.Name -Policy $script:definitionPath -Parameter $script:parameterPath
                        }
                    }
                }
            }
        }

    }

    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}