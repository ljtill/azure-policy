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
                $script:definition = Get-AzPolicySetDefinition -Custom | Where-Object -FilterScript { $_.Properties.metadata.category -eq "Resiliency" }
                $params = @{ 
                    Name                = "Resiliency"
                    DisplayName         = "CET Resiliency - Compute"
                    Description         = "TBD"
                    PolicySetDefinition = $script:definition
                    Metadata            = $script:category
                    Scope               = $script:scope
                } 
            }
            "Policy" {
                $script:assignmentName = $script:metadata["$group"]["$policy"].assignmentName
                $script:definitionDisplayName = $script:metadata["$group"]["$policy"].displayName
                $params = @{
                    Name             = $script:assignmentName
                    DisplayName      = ("CET " + $script:name)
                    PolicyDefinition = $script:definition
                    Metadata         = $script:category
                    Scope            = $script:scope
                }
            }
        }
    }

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        switch ($type) {
            "Initiative" {
                $script:assignment = Get-AzPolicyAssignment | Where-Object -FilterScript { $_.Properties.metadata.category -eq "Resiliency" }
                if ($null -ne $script:assignment) {
                    Write-Verbose -Message " - Remove initiative assignment"
                    Remove-AzPolicyAssignment -Name $script:assignment.Name -Scope $script:scope
                }

                Write-Verbose -Message " - Create initiative assignment"
                New-AzPolicyAssignment @params
            }
            "Policy" {
                Write-Verbose -Message " - Retrieve policy assignment"
                $script:assignment = Get-AzPolicyAssignment | Where-Object -FilterScript { $_.Properties.metadata.category -eq "Resiliency" }
                if ($null -ne $script:assignment) {
                    Write-Verbose -Message " - Remove policy assignment"
                    Remove-AzPolicyAssignment -Name $script:assignment.Name -Scope $script:scope
                }

                Write-Verbose -Message " - Retrieve policy definition"
                $script:definition = Get-AzPolicyDefinition -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
                
                Write-Verbose -Message " - Create policy assignment"
                New-AzPolicyAssignment @params
            }
        }
        
    }

    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}