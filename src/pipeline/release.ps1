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
function Publish-Assignment {

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
        [ValidateSet("group1", "group2")]
        [string]$Group,

        [Parameter(Mandatory = $false)]
        [ValidateSet("policy1", "policy2", "policy3")]
        [string]$Policy
    )

    begin {
        Write-Debug -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
    }

    process {
        Write-Debug -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        # Load metadata
        Write-Verbose -Message "- Load metadata"
        $script:metadata = Get-Content -Path "./src/pipeline/metadata.json" | ConvertFrom-Json -AsHashtable
        
        # Generate scope
        Write-Verbose -Message "- Generate scope value"
        switch ($PSCmdlet.ParameterSetName) {
            "ManagementGroup" {
                $script:scope = ("/providers/Microsoft.Management/managementGroups/" + $managementGroup)
            }
            "Subscription" {
                $script:scope = ("/subscriptions/" + (Get-AzSubscription -SubscriptionName $subscription).Id)
            }
        }

        # Generate params
        Write-Verbose -Message "- Generate params value"
        switch ($type) {
            "Initiative" {
                # [BUG] Management Group / Subscription selector
                # $script:definition = Get-AzPolicySetDefinition -Custom | Where-Object -FilterScript { $_.Properties.metadata.category -eq "" }
                # $params = @{ 
                #     Name                = ""
                #     DisplayName         = ""
                #     Description         = ""
                #     PolicySetDefinition = $script:definition
                #     Metadata            = ""
                #     Scope               = $script:scope
                # } 
            }
            "Policy" {
                $script:assignmentName = $script:metadata["$group"]["$policy"].assignmentName
                $script:definitionDisplayName = $script:metadata["$group"]["$policy"].displayName
                switch ($PSCmdlet.ParameterSetName) {
                    "ManagementGroup" {
                        $script:definition = Get-AzPolicyDefinition -ManagementGroupName $managementGroup -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
                    }
                    "Subscription" {
                        $script:definition = Get-AzPolicyDefinition -SubscriptionId $subscription -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
                    }
                }

                switch ($script:metadata["$group"]["$policy"].effect) {
                    "deployIfNotExists" {
                        $params = @{
                            Name             = $script:assignmentName
                            DisplayName      = $script:definitionDisplayName
                            PolicyDefinition = $script:definition
                            Metadata         = $script:category
                            Scope            = $script:scope
                            AssignIdentity   = $true
                            Location         = 'uksouth'
                        }
                    }
                }
            }
        }

        switch ($type) {
            "Initiative" {
                # $script:assignment = Get-AzPolicyAssignment | Where-Object -FilterScript { $_.Properties.metadata.category -eq "Resiliency" }
                # if ($null -ne $script:assignment) {
                #     Write-Verbose -Message " - Remove initiative assignment"
                #     Remove-AzPolicyAssignment -Name $script:assignment.Name -Scope $script:scope
                # }

                # Write-Verbose -Message " - Create initiative assignment"
                # New-AzPolicyAssignment @params
            }
            "Policy" {
                Write-Verbose -Message "- Retrieve policy assignment"
                $script:assignment = Get-AzPolicyAssignment | Where-Object -FilterScript { $_.Properties.metadata.category -eq "Resiliency" }
                if ($null -ne $script:assignment) {
                    Write-Verbose -Message "- Remove policy assignment"
                    Remove-AzPolicyAssignment -Name $script:assignment.Name -Scope $script:scope
                }
                
                Write-Verbose -Message "- Create policy assignment"
                New-AzPolicyAssignment @params
            }
        }
        
    }

    end {
        Write-Debug -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}