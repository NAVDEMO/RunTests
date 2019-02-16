#requires -Version 5.0
using namespace Microsoft.Dynamics.Framework.UI.Client
using namespace Microsoft.Dynamics.Framework.UI.Client.Interactions

$ErrorActionPreference = "Stop"

function New-ClientSessionUserNamePasswordAuthentication
{
    [OutputType([ClientSession])]
    Param(
        [string] $serviceUrl,
        [pscredential] $credential
    )
    $addressUri = New-Object System.Uri -ArgumentList $serviceUrl
    $addressUri = [ServiceAddressProvider]::ServiceAddress($addressUri)
    $jsonClient = New-Object JsonHttpClient -ArgumentList $addressUri, (New-Object System.Net.NetworkCredential -ArgumentList $credential.UserName, $credential.Password), ([AuthenticationScheme]::UserNamePassword)
    New-Object ClientSession -ArgumentList $jsonClient, (New-Object NonDispatcher), (New-Object 'TimerFactory[TaskTimer]')
}

function New-ClientSessionWindowsAuthentication
{
    [OutputType([ClientSession])]
    Param(
        [string] $serviceUrl
    )
    $addressUri = New-Object System.Uri -ArgumentList $serviceUrl
    $addressUri = [ServiceAddressProvider]::ServiceAddress($addressUri)
    $jsonClient = New-Object JsonHttpClient -ArgumentList $addressUri, $null, ([AuthenticationScheme]::UserNamePassword)
    New-Object ClientSession -ArgumentList $jsonClient, (New-Object NonDispatcher), (New-Object 'TimerFactory[TaskTimer]')
}

function Open-ClientSession
{
    Param(
        [ClientSession] $clientSession,
        [string] $culture
    )
    $clientSessioParameters = New-Object ClientSessionParameters
    $clientSessioParameters.CultureId = $culture
    $clientSessioParameters.UICultureId = $culture
    $clientSessioParameters.AdditionalSettings.Add("IncludeControlIdentifier", $true)
    $clientSession.OpenSessionAsync($clientSessioParameters)
    Await-state -ClientSession $clientSession -state Ready
}

function Remove-ClientSession
{
    Param(
        [ClientSession] $clientSession
    )
    if ($clientSession.State -ne ([ClientSessionState]::Closed)) {
        $clientSession.CloseSessionAsync()
        Await-State -ClientSession $clientSession -State Closed
    }
}

function Await-State
{
    Param(
        [ClientSession] $clientSession,
        [ClientSessionState] $state = ([ClientSessionState]::Ready)
    )
    While ($clientSession.State -ne $state) {
        Start-Sleep -Milliseconds 100
        if ($clientSession.State -eq [ClientSessionState]::InError) {
            throw "ClientSession in Error"
        }
        if ($clientSession.State -eq [ClientSessionState]::TimedOut) {
            throw "ClientSession timed out"
        }
    }
}

function Open-Form
{
    [OutputType([ClientLogicalForm])]
    Param(
        [ClientSession] $clientSession,
        [int] $page
    )
    $Global:form = $null
    $event = Register-ObjectEvent -InputObject $clientSession -EventName FormToShow -Action {
        $Global:form = $EventArgs.FormToShow
    }
    try {
        $interaction = New-Object OpenFormInteraction
        $interaction.Page = $page
        $clientSession.InvokeInteractionAsync($interaction)
        Await-State -clientSession $clientSession -state Ready
    } finally {
        Unregister-Event -SourceIdentifier $event.Name
    }
    $Global:form
}

function Close-Form
{
    Param(
        [ClientSession] $clientSession,
        [ClientLogicalControl] $form
    )
    $interaction = New-Object CloseFormInteraction -ArgumentList $form
    $clientSession.InvokeInteractionAsync($interaction)
    Await-State -clientSession $clientSession -state Ready
}

function Close-AllForms
{
    Param(
        [ClientSession] $clientSession
    )
    $forms = @()
    $clientSession.OpenedForms.GetEnumerator() | % { $forms += $_ }
    $forms | % { Close-Form -clientSession $clientSession -form $_ }
}

function Get-ControlByCaption
{
    [OutputType([ClientLogicalControl])]
    Param(
        [ClientLogicalControl] $control,
        [string] $caption
    )
    $control.ContainedControls | Where-Object { $_.Caption.Replace("&","") -eq $caption } | Select-Object -First 1
}

function Get-ControlByType
{
    [OutputType([ClientLogicalControl])]
    Param(
        [ClientLogicalControl] $control,
        [Type] $type
    )
    $control.ContainedControls | Where-Object { $_ -is $type } | Select-Object -First 1
}

function Save-Value
{
    Param(
        [ClientSession] $clientSession,
        [ClientLogicalControl] $control,
        [string] $newValue
    )
    $interaction = New-Object SaveValueInteraction -ArgumentList $control, $newValue
    $clientSession.InvokeInteractionAsync($interaction)
    Await-State -clientSession $clientSession -state Ready
}

function Scroll-Repeater
{
    Param(
        [ClientSession] $clientSession,
        [ClientRepeaterControl] $repeater,
        [int] $by
    )
    $interaction = New-Object ScrollRepeaterInteraction -ArgumentList $repeater, $by
    $clientSession.InvokeInteractionAsync($interaction)
    Await-State -clientSession $clientSession -state Ready
}

function Activate-Control
{
    Param(
        [ClientSession] $clientSession,
        [ClientLogicalControl] $control
    )
    $interaction = New-Object ActivateControlInteraction -ArgumentList $lineTypeControl
    $clientSession.InvokeInteractionAsync($interaction)
    Await-State -clientSession $clientSession -state Ready
}

function Get-ActionByCaption
{
    [OutputType([ClientActionControl])]
    Param(
        [ClientLogicalControl] $control,
        [string] $caption
    )
    $control.ContainedControls | Where-Object { ($_ -is [ClientActionControl]) -and ($_.Caption.Replace("&","") -eq $caption) } | Select-Object -First 1
}

function Invoke-Action
{
    Param(
        [ClientSession] $clientSession,
        [ClientActionControl] $action
    )
    $interaction = New-Object InvokeActionInteraction -ArgumentList $action
    $clientSession.InvokeInteractionAsync($interaction)
    Await-State -clientSession $clientSession -state Ready
}

function Run-Tests
{
    Param(
        [ClientSession] $clientSession,
        [int] $testPage = 130401,
        [string] $testSuite = "DEFAULT",
        [switch] $verbose
    )

    Open-ClientSession -clientSession $clientSession -culture "en-US"
    
    $form = Open-Form -clientSession $clientSession -page $testPage
    $suiteControl = Get-ControlByCaption -control $form -caption "Suite Name"
    Save-Value -clientSession $clientSession -control $suiteControl -newValue $testSuite
    $repeater = Get-ControlByType -control $form -type ([ClientRepeaterControl])
    $index = 0
    
    while ($true)
    {
        if ($index -ge ($repeater.Offset + $repeater.DefaultViewport.Count))
        {
            Scroll-Repeater -clientSession $clientSession -repeater $repeater -by 1
        }
        $rowIndex = $index - $repeater.Offset
        if ($rowIndex -ge $repeater.DefaultViewport.Count)
        {
            break 
        }
        $row = $repeater.DefaultViewport[$rowIndex]
    
        $lineTypeControl = Get-ControlByType -control $row -type ([ClientSelectionControl])
        $lineType = $lineTypeControl.StringValue
        $name = (Get-ControlByCaption -control $row -caption "Name").StringValue
        $codeUnitId = (Get-ControlByCaption -control $row -caption "Codeunit ID").StringValue
    
        if ($lineType -eq "Codeunit") 
        {
            Activate-Control -clientSession $clientSession -control $lineTypeControl
            Write-Host "  $lineType $codeunitId $name " -NoNewline
    
            $runAction = Get-ActionByCaption -control $form -caption "Run Selected"
            Invoke-Action -clientSession $clientSession -action $runAction
    
            $row = $repeater.DefaultViewport[$rowIndex]
            $result = (Get-ControlByCaption -control $row -caption "Result").StringValue
            if ($result -eq "Success")
            {
                $color = "Green"
            }
            else
            {
                $color = "Red"
            }
            Write-Host -ForegroundColor $color "$result"
        }
        elseif ($lineType -eq "Function")
        {
            $writeit = $verbose
            $result = (Get-ControlByCaption -control $row -caption "Result").StringValue
            if ($result -eq "Success")
            {
                $color = "Green"
            }
            else
            {
                $color = "Red"
                $writeit = $true
            }
            if ($writeit) 
            {
                Write-Host -ForegroundColor $color "    $lineType $name $result"
            }
        }
        else
        {
            Write-Host "$lineType $name" 
        }
        $index++
    }
    
    Close-Form -clientSession $clientSession -form $form
}

# Load DLL's
Add-type -Path (Join-Path $PSScriptRoot "Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll")
Add-type -Path (Join-Path $PSScriptRoot "Test Assemblies\NewtonSoft.json.dll")

# Connect to Client Service
$serviceUrl = "http://fkdev/NAV/cs"
$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)
$clientSession = New-ClientSessionUserNamePasswordAuthentication -serviceUrl $serviceUrl -credential $credential

Run-Tests -clientSession $clientSession -verbose

Remove-ClientSession -clientSession $clientSession
