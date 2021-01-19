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
        [ValidateSet("Policy")]
        [string]$Type,

        [Parameter(Mandatory = $false)]
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

        # Generate scope
        Write-Verbose -Message "- Generate scope"
        switch ($PSCmdlet.ParameterSetName) {
            "ManagementGroup" {
                $script:scope = Get-AzManagementGroup | Where-Object -FilterScript { $_.DisplayName -eq $ManagementGroup } | Select-Object -ExpandProperty Id
            }
            "Subscription" {
                $script:scope = ("/subscriptions/" + (Get-AzSubscription -SubscriptionName $subscription).Id)
            }
        }

        # Generate params
        Write-Verbose -Message "- Generate params"
        switch ($type) {
            "Policy" {
                switch ($PSCmdlet.ParameterSetName) {
                    "ManagementGroup" {
                        $params = @{
                            Name            = $script:definitionName
                            DisplayName     = $script:definitionDisplayName
                            ManagementGroup = ($script:scope -split "/" | Select-Object -Index 4)
                            Policy          = $script:definitionPath
                            Parameter       = $script:definitionParametersPath
                        }
                    }
                    "Subscription" {
                        $params = @{
                            Name        = $script:definitionName
                            DisplayName = $script:definitionDisplayName
                            Policy      = $script:definitionPath
                            Parameter   = $script:definitionParametersPath
                        }
                    }
                }
            }
        }

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
                        $script:definition = Get-AzPolicyDefinition -ManagementGroupName $managementGroup -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
                    }
                    "Subscription" {
                        $script:definition = Get-AzPolicyDefinition  -SubscriptionId $subscription -Custom | Where-Object -FilterScript { $_.Properties.displayName -eq $script:definitionDisplayName }
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
                            Remove-AzPolicyDefinition -Name $script:definitionName -ManagementGroupName $managementGroup -Force
                        }
                        "Subscription" {
                            Remove-AzPolicyDefinition -Name $script:definitionName -SubscriptionId $subscription -Force
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