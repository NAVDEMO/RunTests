#requires -Version 5.0
using namespace Microsoft.Dynamics.Framework.UI.Client
using namespace Microsoft.Dynamics.Framework.UI.Client.Interactions

$ErrorActionPreference = "Stop"
$events = @()

function New-ClientSessionUserNamePasswordAuthentication
{
    [OutputType([ClientSession])]
    Param(
        [string] $serviceUrl,
        [pscredential] $credential,
        [timespan] $interactionTimeout = ([timespan]::FromMinutes(10)),
        [string] $culture = "en-US"
    )
    $addressUri = New-Object System.Uri -ArgumentList $serviceUrl
    $addressUri = [ServiceAddressProvider]::ServiceAddress($addressUri)
    $jsonClient = New-Object JsonHttpClient -ArgumentList $addressUri, (New-Object System.Net.NetworkCredential -ArgumentList $credential.UserName, $credential.Password), ([AuthenticationScheme]::UserNamePassword)
    $httpClient = ($jsonClient.GetType().GetField("httpClient", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)).GetValue($jsonClient)
    $httpClient.Timeout = $interactionTimeout
    $clientSession = New-Object ClientSession -ArgumentList $jsonClient, (New-Object NonDispatcher), (New-Object 'TimerFactory[TaskTimer]')
    Open-ClientSession -clientSession $clientSession -culture $culture
    $clientSession
}

function New-ClientSessionWindowsAuthentication
{
    [OutputType([ClientSession])]
    Param(
        [string] $serviceUrl,
        [timespan] $interactionTimeout = ([timespan]::FromMinutes(10)),
        [string] $culture = "en-US"
    )
    $addressUri = New-Object System.Uri -ArgumentList $serviceUrl
    $addressUri = [ServiceAddressProvider]::ServiceAddress($addressUri)
    $jsonClient = New-Object JsonHttpClient -ArgumentList $addressUri, $null, ([AuthenticationScheme]::UserNamePassword)
    $httpClient = ($jsonClient.GetType().GetField("httpClient", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)).GetValue($jsonClient)
    $httpClient.Timeout = $interactionTimeout
    $clientSession = New-Object ClientSession -ArgumentList $jsonClient, (New-Object NonDispatcher), (New-Object 'TimerFactory[TaskTimer]')
    Open-ClientSession -clientSession $clientSession -culture $culture
    $clientSession
}

function Open-ClientSession
{
    Param(
        [ClientSession] $clientSession,
        [string] $culture
    )
    $clientSessionParameters = New-Object ClientSessionParameters
    $clientSessionParameters.CultureId = $culture
    $clientSessionParameters.UICultureId = $culture
    $clientSessionParameters.AdditionalSettings.Add("IncludeControlIdentifier", $true)

    $events += @(Register-ObjectEvent -InputObject $clientSession -EventName MessageToShow -Action {
        Write-Host -ForegroundColor Yellow "Message : $($EventArgs.Message)"
    })
    $events += @(Register-ObjectEvent -InputObject $clientSession -EventName CommunicationError -Action {
        Write-Host -ForegroundColor Yellow "CommunicationError : $($EventArgs.Exception.Message)"
    })
    $events += @(Register-ObjectEvent -InputObject $clientSession -EventName UnhandledException -Action {
        Write-Host -ForegroundColor Yellow "UnhandledException : $($EventArgs.Exception.Message)"
    })
    $events += @(Register-ObjectEvent -InputObject $clientSession -EventName InvalidCredentialsError -Action {
        Write-Host -ForegroundColor Yellow "InvalidCredentialsError"
    })
    $events += @(Register-ObjectEvent -InputObject $clientSession -EventName UriToShow -Action {
        Write-Host -ForegroundColor Yellow "UriToShow : $($EventArgs.UriToShow)"
    })

    $clientSession.OpenSessionAsync($clientSessionParameters)
    Await-state -ClientSession $clientSession -state Ready
}

function Remove-ClientSession
{
    Param(
        [ClientSession] $clientSession
    )
    $events | % { Unregister-Event $_.Name }
    $events = @()

    if ($clientSession -and ($clientSession.State -ne ([ClientSessionState]::Closed))) {
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
        if ($clientSession.State -eq [ClientSessionState]::Uninitialized) {
            throw "ClientSession is Uninitialized"
        }
    }
}

function Invoke-Interaction
{
    Param(
        [ClientSession] $clientSession,
        [ClientInteraction] $interaction,
        [ClientSessionState] $state = ([ClientSessionState]::Ready)
    )
    $clientSession.InvokeInteractionAsync($interaction)
    Await-State -clientSession $clientSession -state $state
}

function Invoke-InteractionAndCatchForm
{
    Param(
        [ClientSession] $clientSession,
        [ClientInteraction] $interaction
    )
    $Global:caughtForm = $null
    $event = Register-ObjectEvent -InputObject $clientSession -EventName FormToShow -Action {
        $Global:caughtForm = $EventArgs.FormToShow
    }
    try {
        Invoke-Interaction -clientSession $clientSession -interaction $interaction
    } finally {
        Unregister-Event -SourceIdentifier $event.Name
    }
    $Global:caughtForm
    Remove-Variable caughtForm -Scope Global
}

function Open-Form
{
    [OutputType([ClientLogicalForm])]
    Param(
        [ClientSession] $clientSession,
        [int] $page
    )
    $interaction = New-Object OpenFormInteraction
    $interaction.Page = $page
    Invoke-InteractionAndCatchForm -clientSession $clientSession -interaction $interaction
}

function Close-Form
{
    Param(
        [ClientSession] $clientSession,
        [ClientLogicalControl] $form
    )
    Invoke-Interaction -clientSession $clientSession -interaction (New-Object CloseFormInteraction -ArgumentList $form)
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
    Invoke-Interaction -clientSession $clientSession -interaction (New-Object SaveValueInteraction -ArgumentList $control, $newValue)
}

function Scroll-Repeater
{
    Param(
        [ClientSession] $clientSession,
        [ClientRepeaterControl] $repeater,
        [int] $by
    )
    Invoke-Interaction -clientSession $clientSession -interaction (New-Object ScrollRepeaterInteraction -ArgumentList $repeater, $by)
}

function Activate-Control
{
    Param(
        [ClientSession] $clientSession,
        [ClientLogicalControl] $control
    )
    Invoke-Interaction -clientSession $clientSession -interaction (New-Object ActivateControlInteraction -ArgumentList $lineTypeControl)
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
    Invoke-Interaction -clientSession $clientSession -interaction (New-Object InvokeActionInteraction -ArgumentList $action)
}

function Run-Tests
{
    Param(
        [ClientSession] $clientSession,
        [int] $testPage = 130401,
        [string] $testSuite = "DEFAULT",
        [switch] $verbose
    )
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

try {
    $clientSession = New-ClientSessionUserNamePasswordAuthentication -serviceUrl $serviceUrl -credential $credential -InteractionTimeout ([timespan]::FromMinutes(60))
    Run-Tests -clientSession $clientSession -testSuite "DEFAULT"
} finally {
    Remove-ClientSession -clientSession $clientSession
}
