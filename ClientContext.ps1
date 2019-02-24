#requires -Version 5.0
using namespace Microsoft.Dynamics.Framework.UI.Client
using namespace Microsoft.Dynamics.Framework.UI.Client.Interactions

class ClientContext {

    $events = @()
    $clientSession = $null
    $culture = ""
    $caughtForm = $null

    ClientContext([string] $serviceUrl, [pscredential] $credential, [timespan] $interactionTimeout = ([timespan]::FromMinutes(10)), [string] $culture = "en-US") {
        $addressUri = New-Object System.Uri -ArgumentList $serviceUrl
        $addressUri = [ServiceAddressProvider]::ServiceAddress($addressUri)
        $jsonClient = New-Object JsonHttpClient -ArgumentList $addressUri, (New-Object System.Net.NetworkCredential -ArgumentList $credential.UserName, $credential.Password), ([AuthenticationScheme]::UserNamePassword)
        $httpClient = ($jsonClient.GetType().GetField("httpClient", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)).GetValue($jsonClient)
        $httpClient.Timeout = $interactionTimeout
        $this.clientSession = New-Object ClientSession -ArgumentList $jsonClient, (New-Object NonDispatcher), (New-Object 'TimerFactory[TaskTimer]')
        $this.culture = $culture
        $this.OpenSession()
    }

    ClientContext([string] $serviceUrl, [pscredential] $credential) {
        $this.ClientContext($serviceUrl, $credential, ([timespan]::FromMinutes(10)), 'en-US')
    }

    #
    #function New-ClientSessionWindowsAuthentication
    #{
    #    Param(
    #        [string] $serviceUrl,
    #        [timespan] $interactionTimeout = ([timespan]::FromMinutes(10)),
    #        [string] $culture = "en-US"
    #    )
    #    Remove-ClientSession
    #    $addressUri = New-Object System.Uri -ArgumentList $serviceUrl
    #    $addressUri = [ServiceAddressProvider]::ServiceAddress($addressUri)
    #    $jsonClient = New-Object JsonHttpClient -ArgumentList $addressUri, $null, ([AuthenticationScheme]::UserNamePassword)
    #    $httpClient = ($jsonClient.GetType().GetField("httpClient", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)).GetValue($jsonClient)
    #    $httpClient.Timeout = $interactionTimeout
    #    $script:clientSession = New-Object ClientSession -ArgumentList $jsonClient, (New-Object NonDispatcher), (New-Object 'TimerFactory[TaskTimer]')
    #    $script:culture = $culture
    #    Open-ClientSession
    #}
    #
    
    OpenSession() {
        $clientSessionParameters = New-Object ClientSessionParameters
        $clientSessionParameters.CultureId = $this.culture
        $clientSessionParameters.UICultureId = $this.culture
        $clientSessionParameters.AdditionalSettings.Add("IncludeControlIdentifier", $true)
    
        $this.events += @(Register-ObjectEvent -InputObject $this.clientSession -EventName MessageToShow -Action {
            Write-Host -ForegroundColor Yellow "Message : $($EventArgs.Message)"
        })
        $this.events += @(Register-ObjectEvent -InputObject $this.clientSession -EventName CommunicationError -Action {
            Write-Host -ForegroundColor Red "CommunicationError : $($EventArgs.Exception.Message)"
            Remove-ClientSession
        })
        $this.events += @(Register-ObjectEvent -InputObject $this.clientSession -EventName UnhandledException -Action {
            Write-Host -ForegroundColor Red "UnhandledException : $($EventArgs.Exception.Message)"
            Remove-ClientSession
        })
        $this.events += @(Register-ObjectEvent -InputObject $this.clientSession -EventName InvalidCredentialsError -Action {
            Write-Host -ForegroundColor Red "InvalidCredentialsError"
            Remove-ClientSession
        })
        $this.events += @(Register-ObjectEvent -InputObject $this.clientSession -EventName UriToShow -Action {
            Write-Host -ForegroundColor Yellow "UriToShow : $($EventArgs.UriToShow)"
        })
        $this.events += @(Register-ObjectEvent -InputObject $this.clientSession -EventName DialogToShow -Action {
            $form = $EventArgs.DialogToShow
            if ( $form.ControlIdentifier -eq "00000000-0000-0000-0800-0000836bd2d2" ) {
                $errorText = (Get-ControlByType -control $form -type ([ClientStaticStringControl])).StringValue
                Write-Host -ForegroundColor Red "ERROR: $errorText"
            }
        })
    
        $this.clientSession.OpenSessionAsync($clientSessionParameters)
        $this.Awaitstate([ClientSessionState]::Ready)
    }
    #
    
    Dispose() {
        $this.events | % { Unregister-Event $_.Name }
        $this.events = @()
    
        try {
            if ($this.clientSession -and ($this.clientSession.State -ne ([ClientSessionState]::Closed))) {
                $this.clientSession.CloseSessionAsync()
                $this.AwaitState([ClientSessionState]::Closed)
            }
        }
        catch {
        }
    }
    
    AwaitState([ClientSessionState] $state) {
        While ($this.clientSession.State -ne $state) {
            Start-Sleep -Milliseconds 100
            if ($this.clientSession.State -eq [ClientSessionState]::InError) {
                throw "ClientSession in Error"
            }
            if ($this.clientSession.State -eq [ClientSessionState]::TimedOut) {
                throw "ClientSession timed out"
            }
            if ($this.clientSession.State -eq [ClientSessionState]::Uninitialized) {
                throw "ClientSession is Uninitialized"
            }
        }
    }
    
    InvokeInteraction([ClientInteraction] $interaction) {
        $this.clientSession.InvokeInteractionAsync($interaction)
        $this.AwaitState([ClientSessionState]::Ready)
    }
    
    [ClientLogicalForm] InvokeInteractionAndCatchForm([ClientInteraction] $interaction) {
        $Global:PsTestRunnerCaughtForm = $null
        $formToShowEvent = Register-ObjectEvent -InputObject $this.clientSession -EventName FormToShow -Action { $Global:PsTestRunnerCaughtForm = $EventArgs.FormToShow }
        try {
            $this.InvokeInteraction($interaction)
        } finally {
            Unregister-Event -SourceIdentifier $formToShowEvent.Name
        }
        $form = $Global:PsTestRunnerCaughtForm
        Remove-Variable PsTestRunnerCaughtForm -Scope Global
        return $form
    }
    
    [ClientLogicalForm] OpenForm([int] $page) {
        $interaction = New-Object OpenFormInteraction
        $interaction.Page = $page
        return $this.InvokeInteractionAndCatchForm($interaction)
    }
    
    CloseForm([ClientLogicalControl] $form) {
        $this.InvokeInteraction((New-Object CloseFormInteraction -ArgumentList $form))
    }
    
    [ClientLogicalForm[]]GetAllForms() {
        $forms = @()
        $this.clientSession.OpenedForms.GetEnumerator() | % { $forms += $_ }
        return $forms
    }
    
    [string]GetErrorFromErrorForm() {
        $this.clientSession.OpenedForms.GetEnumerator() | % {
            if ( $_.ControlIdentifier -eq "00000000-0000-0000-0800-0000836bd2d2" ) {
                return (Get-ControlByType -control $_ -type ([ClientStaticStringControl])).StringValue
            }
        }
        return ""
    }
    
    [Hashtable]GetFormInfo([ClientLogicalForm] $form) {
    
        function Dump-RowControl {
            Param(
                [ClientLogicalControl] $control
            )
            @{
                "$($control.Name)" = $control.ObjectValue
            }
        }
    
        function Dump-Control {
            Param(
                [ClientLogicalControl] $control,
                [int] $indent
            )
    
            $output = @{
                "name" = $control.Name
                "type" = $control.GetType().Name
            }
            if ($control -is [ClientGroupControl]) {
                $output += @{
                    "caption" = $control.Caption
                    "mappingHint" = $control.MappingHint
                }
            } elseif ($control -is [ClientStaticStringControl]) {
                $output += @{
                    "value" = $control.StringValue
                }
            } elseif ($control -is [ClientInt32Control]) {
                $output += @{
                    "value" = $control.ObjectValue
                }
            } elseif ($control -is [ClientStringControl]) {
                $output += @{
                    "value" = $control.stringValue
                }
            } elseif ($control -is [ClientActionControl]) {
                $output += @{
                    "caption" = $control.Caption
                }
            } elseif ($control -is [ClientFilterLogicalControl]) {
            } elseif ($control -is [ClientRepeaterControl]) {
                $output += @{
                    "$($control.name)" = @()
                }
                $index = 0
                while ($true) {
                    if ($index -ge ($control.Offset + $control.DefaultViewport.Count)) {
                        $this.ScrollRepeater($control, 1)
                    }
                    $rowIndex = $index - $control.Offset
                    if ($rowIndex -ge $control.DefaultViewport.Count) {
                        break 
                    }
                    $row = $control.DefaultViewport[$rowIndex]
                    $rowoutput = @{}
                    $row.Children | % { $rowoutput += Dump-RowControl -control $_ }
                    $output[$control.name] += $rowoutput
                    $index++
                }
            }
            else {
            }
            $output
        }
    
        return @{
            "title" = "$($form.Name) $($form.Caption)"
            "controls" = $form.Children | % { Dump-Control -output $output -control $_ -indent 1 }
        }
    }
    
    CloseAllForms() {
        $this.GetAllForms | % { $this.CloseForm($_) }
    }
    
    [ClientLogicalControl]GetControlByCaption([ClientLogicalControl] $control, [string] $caption) {
        return $control.ContainedControls | Where-Object { $_.Caption.Replace("&","") -eq $caption } | Select-Object -First 1
    }
    
    [ClientLogicalControl]GetControlByName([ClientLogicalControl] $control, [string] $name) {
        return $control.ContainedControls | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    }
    
    [ClientLogicalControl]GetControlByType([ClientLogicalControl] $control, [Type] $type) {
        return $control.ContainedControls | Where-Object { $_ -is $type } | Select-Object -First 1
    }
    
    SaveValue([ClientLogicalControl] $control, [string] $newValue) {
        $this.InvokeInteraction((New-Object SaveValueInteraction -ArgumentList $control, $newValue))
    }
    
    ScrollRepeater([ClientRepeaterControl] $repeater, [int] $by) {
        $this.InvokeInteraction((New-Object ScrollRepeaterInteraction -ArgumentList $repeater, $by))
    }
    
    ActivateControl([ClientLogicalControl] $control) {
        $this.InvokeInteraction((New-Object ActivateControlInteraction -ArgumentList $control))
    }
    
    [ClientActionControl]GetActionByCaption([ClientLogicalControl] $control, [string] $caption) {
        return $control.ContainedControls | Where-Object { ($_ -is [ClientActionControl]) -and ($_.Caption.Replace("&","") -eq $caption) } | Select-Object -First 1
    }
    
    [ClientActionControl]GetActionByName([ClientLogicalControl] $control, [string] $name) {
        return $control.ContainedControls | Where-Object { ($_ -is [ClientActionControl]) -and ($_.Name -eq $name) } | Select-Object -First 1
    }
    
    InvokeAction([ClientActionControl] $action) {
        $this.InvokeInteraction((New-Object InvokeActionInteraction -ArgumentList $action))
    }
    
    [ClientLogicalForm]InvokeActionAndCatchForm([ClientActionControl] $action) {
        return $this.InvokeInteractionAndCatchForm((New-Object InvokeActionInteraction -ArgumentList $action))
    }
}
