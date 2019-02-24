#requires -Version 5.0
using namespace Microsoft.Dynamics.Framework.UI.Client
using namespace Microsoft.Dynamics.Framework.UI.Client.Interactions

$ErrorActionPreference = "Stop"
$events = @()
$clientSession = $null
$culture = ""

function New-ClientSessionUserNamePasswordAuthentication
{
    Param(
        [string] $serviceUrl,
        [pscredential] $credential,
        [timespan] $interactionTimeout = ([timespan]::FromMinutes(10)),
        [string] $culture = "en-US"
    )
    Remove-ClientSession
    $addressUri = New-Object System.Uri -ArgumentList $serviceUrl
    $addressUri = [ServiceAddressProvider]::ServiceAddress($addressUri)
    $jsonClient = New-Object JsonHttpClient -ArgumentList $addressUri, (New-Object System.Net.NetworkCredential -ArgumentList $credential.UserName, $credential.Password), ([AuthenticationScheme]::UserNamePassword)
    $httpClient = ($jsonClient.GetType().GetField("httpClient", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)).GetValue($jsonClient)
    $httpClient.Timeout = $interactionTimeout
    $script:clientSession = New-Object ClientSession -ArgumentList $jsonClient, (New-Object NonDispatcher), (New-Object 'TimerFactory[TaskTimer]')
    $script:culture = $culture
    Open-ClientSession
}

function New-ClientSessionWindowsAuthentication
{
    Param(
        [string] $serviceUrl,
        [timespan] $interactionTimeout = ([timespan]::FromMinutes(10)),
        [string] $culture = "en-US"
    )
    Remove-ClientSession
    $addressUri = New-Object System.Uri -ArgumentList $serviceUrl
    $addressUri = [ServiceAddressProvider]::ServiceAddress($addressUri)
    $jsonClient = New-Object JsonHttpClient -ArgumentList $addressUri, $null, ([AuthenticationScheme]::UserNamePassword)
    $httpClient = ($jsonClient.GetType().GetField("httpClient", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)).GetValue($jsonClient)
    $httpClient.Timeout = $interactionTimeout
    $script:clientSession = New-Object ClientSession -ArgumentList $jsonClient, (New-Object NonDispatcher), (New-Object 'TimerFactory[TaskTimer]')
    $script:culture = $culture
    Open-ClientSession
}

function Open-ClientSession
{
    $script:clientSessionParameters = New-Object ClientSessionParameters
    $script:clientSessionParameters.CultureId = $script:culture
    $script:clientSessionParameters.UICultureId = $script:culture
    $script:clientSessionParameters.AdditionalSettings.Add("IncludeControlIdentifier", $true)

    $events += @(Register-ObjectEvent -InputObject $script:clientSession -EventName MessageToShow -Action {
        Write-Host -ForegroundColor Yellow "Message : $($EventArgs.Message)"
    })
    $events += @(Register-ObjectEvent -InputObject $script:clientSession -EventName CommunicationError -Action {
        Write-Host -ForegroundColor Red "CommunicationError : $($EventArgs.Exception.Message)"
        Remove-ClientSession
    })
    $events += @(Register-ObjectEvent -InputObject $script:clientSession -EventName UnhandledException -Action {
        Write-Host -ForegroundColor Red "UnhandledException : $($EventArgs.Exception.Message)"
        Remove-ClientSession
    })
    $events += @(Register-ObjectEvent -InputObject $script:clientSession -EventName InvalidCredentialsError -Action {
        Write-Host -ForegroundColor Red "InvalidCredentialsError"
        Remove-ClientSession
    })
    $events += @(Register-ObjectEvent -InputObject $script:clientSession -EventName UriToShow -Action {
        Write-Host -ForegroundColor Yellow "UriToShow : $($EventArgs.UriToShow)"
    })
    $events += @(Register-ObjectEvent -InputObject $script:clientSession -EventName DialogToShow -Action {
        $form = $EventArgs.DialogToShow
        if ( $form.ControlIdentifier -eq "00000000-0000-0000-0800-0000836bd2d2" ) {
            $errorText = (Get-ControlByType -control $form -type ([ClientStaticStringControl])).StringValue
            Write-Host -ForegroundColor Red "ERROR: $errorText"
        }
    })

    $script:clientSession.OpenSessionAsync($script:clientSessionParameters)
    Await-state -state Ready
}

function Remove-ClientSession
{
    $events | % { Unregister-Event $_.Name }
    $events = @()

    try {
        if ($script:clientSession -and ($script:clientSession.State -ne ([ClientSessionState]::Closed))) {
            $script:clientSession.CloseSessionAsync()
            Await-State -State Closed
        }
    }
    catch {
    }
}

function Await-State
{
    Param(
        [ClientSessionState] $state = ([ClientSessionState]::Ready)
    )
    
    While ($script:clientSession.State -ne $state) {
        Start-Sleep -Milliseconds 100
        if ($script:clientSession.State -eq [ClientSessionState]::InError) {
            throw "ClientSession in Error"
        }
        if ($script:clientSession.State -eq [ClientSessionState]::TimedOut) {
            throw "ClientSession timed out"
        }
        if ($script:clientSession.State -eq [ClientSessionState]::Uninitialized) {
            throw "ClientSession is Uninitialized"
        }
    }
}

function Invoke-Interaction
{
    Param(
        [ClientInteraction] $interaction,
        [ScriptBlock] $catchForm,
        [ScriptBlock] $catchDialog,
        [ClientSessionState] $state = ([ClientSessionState]::Ready)
    )
    if ($catchForm) {
        $formToShowEvent = Register-ObjectEvent -InputObject $script:clientSession -EventName FormToShow -Action $catchForm
    }
    if ($catchDialog) {
        $dialogToShowEvent = Register-ObjectEvent -InputObject $script:clientSession -EventName DialogToShow -Action $catchDialog
    } else {
        $dialogToShowEvent = Register-ObjectEvent -InputObject $script:clientSession -EventName DialogToShow -Action {
            Write-Host -ForegroundColor Red "Unexpected dialog"
            ($eventArgs.DialogToShow) | Out-Host
        }
    }
    try {
        $script:clientSession.InvokeInteractionAsync($interaction)
        Await-State -state $state
    } finally {
        if ($catchForm) {
            Unregister-Event -SourceIdentifier $formToShowEvent.Name
        }      
        if ($catchDialog) {
            Unregister-Event -SourceIdentifier $dialogToShowEvent.Name
        }      
    }
}

function Invoke-InteractionAndCatchForm
{
    Param(
        [ClientInteraction] $interaction
    )
    $Global:caughtForm = $null
    Invoke-Interaction -interaction $interaction -CatchForm {
        $Global:caughtForm = $EventArgs.FormToShow
    }
    $Global:caughtForm
    Remove-Variable caughtForm -Scope Global
}

function Open-Form
{
    [OutputType([ClientLogicalForm])]
    Param(
        [int] $page
    )
    $interaction = New-Object OpenFormInteraction
    $interaction.Page = $page
    $form = Invoke-InteractionAndCatchForm -interaction $interaction
    $form
}

function Close-Form
{
    Param(
        [ClientLogicalControl] $form
    )
    Invoke-Interaction -interaction (New-Object CloseFormInteraction -ArgumentList $form)
}

function Get-AllForms
{
    $forms = @()
    $script:clientSession.OpenedForms.GetEnumerator() | % { $forms += $_ }
    $forms
}

function Get-ErrorForm
{
    $script:clientSession.OpenedForms.GetEnumerator() | % {
        if ( $_.ControlIdentifier -eq "00000000-0000-0000-0800-0000836bd2d2" ) {
            (Get-ControlByType -control $_ -type ([ClientStaticStringControl])).StringValue
        }
    }
}

function Dump-Form
{
    Param(
        [ClientLogicalForm] $form

    )

    function Dump-Control
    {
        Param(
            [ClientLogicalControl] $control,
            [int] $indent
        )

        Write-Host -ForegroundColor Gray "$(" "*$indent)$($control.Name) " -NoNewline

        if ($control.Visible) { $color = "White" } else { $color = "gray" }
        if ($control -is [ClientGroupControl]) {
            Write-Host -ForegroundColor $color "$($control.MappingHint)$($control.Caption)"
            $control.Children | % { Dump-Control -control $_ -indent ($indent+1) }
        } elseif ($control -is [ClientStaticStringControl]) {
            Write-Host -ForegroundColor $color "$($control.StringValue)"
        } elseif ($control -is [ClientInt32Control]) {
            Write-Host -ForegroundColor $color "$($control.StringValue)"
        } elseif ($control -is [ClientStringControl]) {
            Write-Host -ForegroundColor $color "'$($control.StringValue)'"
        } elseif ($control -is [ClientActionControl]) {
            Write-Host -ForegroundColor $color "$($control.Caption)"
        } else {
            Write-Host -ForegroundColor $color $control.GetType()
        }

    }

    $title = "$($form.Name) $($form.Caption)"
    Write-Host -ForegroundColor Yellow $title
    Write-Host ("-" * $title.Length)
    $form.Children | % { Dump-Control -control $_ -indent 1 }
}

function Close-AllForms
{
    Get-AllForms | % { Close-Form -form $_ }
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

function Get-ControlByName
{
    [OutputType([ClientLogicalControl])]
    Param(
        [ClientLogicalControl] $control,
        [string] $name
    )
    $control.ContainedControls | Where-Object { $_.Name -eq $name } | Select-Object -First 1
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
        [ClientLogicalControl] $control,
        [string] $newValue
    )
    Invoke-Interaction -interaction (New-Object SaveValueInteraction -ArgumentList $control, $newValue)
}

function Scroll-Repeater
{
    Param(
        [ClientRepeaterControl] $repeater,
        [int] $by
    )
    Invoke-Interaction -interaction (New-Object ScrollRepeaterInteraction -ArgumentList $repeater, $by)
}

function Activate-Control
{
    Param(
        [ClientLogicalControl] $control
    )
    Invoke-Interaction -interaction (New-Object ActivateControlInteraction -ArgumentList $lineTypeControl)
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

function Get-ActionByName
{
    [OutputType([ClientActionControl])]
    Param(
        [ClientLogicalControl] $control,
        [string] $name
    )
    $control.ContainedControls | Where-Object { ($_ -is [ClientActionControl]) -and ($_.Name -eq $name) } | Select-Object -First 1
}

function Invoke-Action
{
    Param(
        [ClientActionControl] $action
    )
    Invoke-Interaction -interaction (New-Object InvokeActionInteraction -ArgumentList $action)
}

function Invoke-ActionAndCatchForm
{
    Param(
        [ClientActionControl] $action
    )
    Invoke-InteractionAndCatchForm -interaction (New-Object InvokeActionInteraction -ArgumentList $action)
}

function Disable-SslVerification
{
    if (-not ([System.Management.Automation.PSTypeName]"SslVerification").Type)
    {
        Add-Type -TypeDefinition  @"
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class SslVerification
{
    private static bool ValidationCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors) { return true; }
    public static void Disable() { System.Net.ServicePointManager.ServerCertificateValidationCallback = ValidationCallback; }
    public static void Enable()  { System.Net.ServicePointManager.ServerCertificateValidationCallback = null; }
}
"@
    }
    [SslVerification]::Disable()
}

function Enable-SslVerification
{
    if (([System.Management.Automation.PSTypeName]"SslVerification").Type)
    {
        [SslVerification]::Enable()
    }
}

function Run-Tests
{
    Param(
        [int] $testPage = 61266,
        [string] $testSuite = "DEFAULT",
        [switch] $verbose
    )

    $form = Open-Form -page $testPage
    if (!($form)) {
        throw "Cannot open page $testPage. You might need to import the page object here: http://aka.ms/pstesttoolfob"
    }
    $suiteControl = Get-ControlByName -control $form -name "CurrentSuiteName"
    Save-Value -control $suiteControl -newValue $testSuite
    $repeater = Get-ControlByType -control $form -type ([ClientRepeaterControl])
    $index = 0
    
    while ($true)
    {
        if ($index -ge ($repeater.Offset + $repeater.DefaultViewport.Count))
        {
            Scroll-Repeater -repeater $repeater -by 1
        }
        $rowIndex = $index - $repeater.Offset
        if ($rowIndex -ge $repeater.DefaultViewport.Count)
        {
            break 
        }
        $row = $repeater.DefaultViewport[$rowIndex]
    
        $lineTypeControl = Get-ControlByName -control $row -name "LineType"
        $lineType = $lineTypeControl.StringValue
        $name = (Get-ControlByName -control $row -name "Name").StringValue
        $codeUnitId = (Get-ControlByName -control $row -name "TestCodeunit").StringValue

        if ($lineType -eq "1") 
        {
            Activate-Control -control $lineTypeControl
            Write-Host "  Codeunit $codeunitId $name " -NoNewline
    
            $runAction = Get-ActionByName -control $form -name "RunSelected"
            Invoke-Action -action $runAction
    
            $row = $repeater.DefaultViewport[$rowIndex]
            $result = (Get-ControlByName -control $row -name "Result").StringValue
            $startTime = (Get-ControlByName -control $row -name "Start Time").ObjectValue
            $finishTime = (Get-ControlByName -control $row -name "Finish Time").ObjectValue
            $duration = $finishTime.Subtract($startTime)
            if ($result -eq "2")
            {
                $color = "Green"
                $resultStr = "Success"
            }
            else
            {
                $color = "Red"
                $resultStr = "Failure"
            }
            Write-Host -ForegroundColor $color "$resultStr ($($duration.TotalSeconds) seconds)"
        }
        elseif ($lineType -eq "2")
        {
            $writeit = $verbose
            $result = (Get-ControlByName -control $row -name "Result").StringValue
            $startTime = (Get-ControlByName -control $row -name "Start Time").ObjectValue
            $finishTime = (Get-ControlByName -control $row -name "Finish Time").ObjectValue
            $duration = $finishTime.Subtract($startTime)
            if ($result -eq "2")
            {
                $color = "Green"
                $resultStr = "Success"
            }
            elseif ($result -eq "1") {
                $color = "Red"
                $firstError = (Get-ControlByName -control $row -name "First Error").StringValue
                $resultStr = "Error: $firstError"
                $writeit = $true
            }
            else {
                $color = "Yellow"
            }
            if ($writeit) 
            {
                Write-Host -ForegroundColor $color "    Testfunction $name $resultStr ($($duration.TotalMilliseconds) milliseconds)"
            }
            if ($result -eq "1" -and $verbose) {
                $callStack = (Get-ControlByName -control $row -name "Call Stack").StringValue
                if ($callStack.EndsWith("\")) { $callStack = $callStack.Substring(0,$callStack.Length-1) }
                Write-Host "      $($callStack.Replace('\','
      '))"
            }
        }
        else
        {
            Write-Host "Group $name" 
        }
        $index++
    }
    
    Close-Form -form $form
}

# Load DLL's
Add-type -Path (Join-Path $PSScriptRoot "Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll")
Add-type -Path (Join-Path $PSScriptRoot "Test Assemblies\NewtonSoft.json.dll")

# Set Keep-Alive on Tcp Level to 1 minute to avoid Azure closing our connection
[System.Net.ServicePointManager]::SetTcpKeepAlive($true, 120000, 120000)

# Allow all self signed certificates
#Disable-SslVerification

# Connect to Client Service
$serviceUrl = "http://fkdev/NAV/cs"
$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)

try {
    New-ClientSessionUserNamePasswordAuthentication -serviceUrl $serviceUrl -credential $credential -culture "en-US" -InteractionTimeout ([timespan]::FromMinutes(60))
    Run-Tests -testSuite "DEFAULT" -verbose
} finally {
    Remove-ClientSession
}
