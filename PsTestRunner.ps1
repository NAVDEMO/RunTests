Param(
    [Parameter(Mandatory=$true)]
    [string] $clientDllPath = (Join-Path $PSScriptRoot "Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"),
    [Parameter(Mandatory=$true)]
    [string] $newtonSoftDllPath,
    [string] $clientContextScriptPath = (Join-Path $PSScriptRoot "ClientContext.ps1"),
    [Parameter(Mandatory=$true)]
    [string] $serviceUrl,
    [ValidateSet('Windows','NavUserPassword','AAD')]
    [string] $auth='NavUserPassword',
    [Parameter(Mandatory=$false)]
    [pscredential] $credential,
    [timespan] $tcpKeepAlive = [timespan]::FromMinutes(2),
    [timespan] $transactionTimeout = [timespan]::FromMinutes(10),
    [switch] $disableSslVerification,
    [string] $culture = "en-US",
    [int] $testPage = 61266,
    [string] $testSuite = "DEFAULT",
    [switch] $detailed,
    [string] $XUnitResultFileName = "",
    [ValidateSet('no','error','warning')]
    [string] $AzureDevOps = 'no'
)

function Run-Tests
{
    Param(
        [ClientContext] $clientContext,
        [int] $testPage = 61266,
        [string] $testSuite = "DEFAULT",
        [switch] $detailed,
        [string] $XUnitResultFileName = "",
        [ValidateSet('no','error','warning')]
        [string] $AzureDevOps = 'no'
    )

    $form = $clientContext.OpenForm($testPage)
    if (!($form)) {
        throw "Cannot open page $testPage. You might need to import the page object here: http://aka.ms/pstesttoolfob"
    }
    $suiteControl = $clientContext.GetControlByName($form, "CurrentSuiteName")
    $clientContext.SaveValue($suiteControl, $testSuite)
    $repeater = $clientContext.GetControlByType($form, [ClientRepeaterControl])
    $index = 0

    if ($XUnitResultFileName) {
        [xml]$XUnitDoc = New-Object System.Xml.XmlDocument
        $XUnitDoc.AppendChild($XUnitDoc.CreateXmlDeclaration("1.0","UTF-8",$null)) | Out-Null
        $XUnitAssemblies = $XUnitDoc.CreateElement("assemblies")
        $XUnitDoc.AppendChild($XUnitAssemblies) | Out-Null
    }
    
    while ($true)
    {
        if ($index -ge ($repeater.Offset + $repeater.DefaultViewport.Count))
        {
            $clientContext.ScrollRepeater($repeater, 1)
        }
        $rowIndex = $index - $repeater.Offset
        if ($rowIndex -ge $repeater.DefaultViewport.Count)
        {
            break 
        }
        $row = $repeater.DefaultViewport[$rowIndex]
    
        $lineTypeControl = $clientContext.GetControlByName($row, "LineType")
        $lineType = $lineTypeControl.StringValue
        $name = $clientContext.GetControlByName($row, "Name").StringValue
        $codeUnitId = $clientContext.GetControlByName($row, "TestCodeunit").StringValue

        switch ($linetype) {
            "1" {
                $clientContext.ActivateControl($lineTypeControl)
                Write-Host "  Codeunit $codeunitId $name " -NoNewline

                $startTime = get-date
                $clientContext.InvokeAction($clientContext.GetActionByName($form, "RunSelected"))
                $finishTime = get-date
                $duration = $finishTime.Subtract($startTime)

                $row = $repeater.DefaultViewport[$rowIndex]
                $result = $clientContext.GetControlByName($row, "Result").StringValue
                if ($result -eq "2") {
                    Write-Host -ForegroundColor Green "Success ($([Math]::Round($duration.TotalSeconds,3)) seconds)"
                }
                else {
                    Write-Host -ForegroundColor Red "Failure ($([Math]::Round($duration.TotalSeconds,3)) seconds)"
                }

                if ($XUnitResultFileName) {
                    $XUnitAssembly = $XUnitDoc.CreateElement("assembly")
                    $XUnitAssemblies.AppendChild($XUnitAssembly) | Out-Null
                    $XUnitAssembly.SetAttribute("name",$Name)
                    $XUnitAssembly.SetAttribute("test-framework", "PS Test Runner")
                    $XUnitAssembly.SetAttribute("run-date", $startTime.ToString("yyyy-MM-dd"))
                    $XUnitAssembly.SetAttribute("run-time", $startTime.ToString("HH:mm:ss"))
                    $XUnitAssembly.SetAttribute("total",0)
                    $XUnitAssembly.SetAttribute("passed",0)
                    $XUnitAssembly.SetAttribute("failed",0)
                    $XUnitAssembly.SetAttribute("time", ([Math]::Round($duration.TotalSeconds,3)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                    $XUnitCollection = $XUnitDoc.CreateElement("collection")
                    $XUnitAssembly.AppendChild($XUnitCollection) | Out-Null
                    $XUnitCollection.SetAttribute("name",$Name)
                    $XUnitCollection.SetAttribute("total",0)
                    $XUnitCollection.SetAttribute("passed",0)
                    $XUnitCollection.SetAttribute("failed",0)
                    $XUnitCollection.SetAttribute("skipped",0)
                    $XUnitCollection.SetAttribute("time", ([Math]::Round($duration.TotalSeconds,3)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                }
            }
            "2" {
                $result = $clientContext.GetControlByName($row, "Result").StringValue
                $startTime = $clientContext.GetControlByName($row, "Start Time").ObjectValue
                $finishTime = $clientContext.GetControlByName($row, "Finish Time").ObjectValue
                $duration = $finishTime.Subtract($startTime)
                if ($XUnitResultFileName) {
                    $XUnitAssembly.SetAttribute("total",([int]$XUnitAssembly.GetAttribute("total")+1))
                    $XUnitCollection.SetAttribute("total",([int]$XUnitCollection.GetAttribute("total")+1))
                    $XUnitTest = $XUnitDoc.CreateElement("test")
                    $XUnitCollection.AppendChild($XUnitTest) | Out-Null
                    $XUnitTest.SetAttribute("name", $XUnitAssembly.GetAttribute("name"))
                    $XUnitTest.SetAttribute("method", $Name)
                    $XUnitTest.SetAttribute("time", ([Math]::Round($duration.TotalSeconds,3)).ToString([System.Globalization.CultureInfo]::InvariantCulture))
                }
                if ($result -eq "2") {
                    if ($detailed) {
                        Write-Host -ForegroundColor Green "    Testfunction $name Success ($([Math]::Round($duration.TotalSeconds,3)) seconds)"
                    }
                    if ($XUnitResultFileName) {
                        $XUnitAssembly.SetAttribute("passed",([int]$XUnitAssembly.GetAttribute("passed")+1))
                        $XUnitCollection.SetAttribute("passed",([int]$XUnitCollection.GetAttribute("passed")+1))
                        $XUnitTest.SetAttribute("result", "Pass")
                    }
                }
                elseif ($result -eq "1") {
                    $firstError = $clientContext.GetControlByName($row, "First Error").StringValue
                    if ($AzureDevOps -ne 'no') {
                        Write-Host "##vso[task.logissue type=$AzureDevOps;sourcepath=$name;]$firstError"
                    }
                    Write-Host -ForegroundColor Red "    Testfunction $name Failure ($([Math]::Round($duration.TotalSeconds,3)) seconds)"
                    $callStack = $clientContext.GetControlByName($row, "Call Stack").StringValue
                    if ($callStack.EndsWith("\")) { $callStack = $callStack.Substring(0,$callStack.Length-1) }
                    if ($XUnitResultFileName) {
                        $XUnitAssembly.SetAttribute("failed",([int]$XUnitAssembly.GetAttribute("failed")+1))
                        $XUnitCollection.SetAttribute("failed",([int]$XUnitCollection.GetAttribute("failed")+1))
                        $XUnitTest.SetAttribute("result", "Fail")
                        $XUnitFailure = $XUnitDoc.CreateElement("failure")
                        $XUnitMessage = $XUnitDoc.CreateElement("message")
                        $XUnitMessage.InnerText = $firstError
                        $XUnitFailure.AppendChild($XUnitMessage) | Out-Null
                        $XUnitStacktrace = $XUnitDoc.CreateElement("stack-trace")
                        $XUnitStacktrace.InnerText = $Callstack.Replace("\","`n")
                        $XUnitFailure.AppendChild($XUnitStacktrace) | Out-Null
                        $XUnitTest.AppendChild($XUnitFailure) | Out-Null
                    }
                }
                else {
                    if ($XUnitResultFileName) {
                        $XUnitCollection.SetAttribute("skipped",([int]$XUnitCollection.GetAttribute("skipped")+1))
                    }
                }
                if ($result -eq "1" -and $detailed) {
                    Write-Host -ForegroundColor Red "      Error:"
                    Write-Host -ForegroundColor Red "        $firstError"
                    Write-Host -ForegroundColor Red "      Call Stack:"
                    Write-Host -ForegroundColor Red "        $($callStack.Replace('\',"`n        "))"
                }
                if ($XUnitResultFileName) {
                    $XUnitCollection.SetAttribute("time", $XUnitAssembly.GetAttribute("time"))
                    $XUnitCollection.SetAttribute("total", $XUnitAssembly.GetAttribute("total"))
                    $XUnitCollection.SetAttribute("passed", $XUnitAssembly.GetAttribute("passed"))
                    $XUnitCollection.SetAttribute("failed", $XUnitAssembly.GetAttribute("failed"))
                }
            }
            else {
                Write-Host "Group $name" 
            }
        }
        $index++
    }
    if ($XUnitResultFileName) {
        $XUnitDoc.Save($XUnitResultFileName)
    }    
    $clientContext.CloseForm($form)
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

$ErrorActionPreference = "Stop"

# Load DLL's
Add-type -Path $clientDllPath
Add-type -Path $newtonSoftDllPath

. (Join-Path $PSScriptRoot "ClientContext.ps1")

# Set Keep-Alive on Tcp Level to 1 minute to avoid Azure closing our connection
[System.Net.ServicePointManager]::SetTcpKeepAlive($true, [int]$tcpKeepAlive.TotalMilliseconds, [int]$tcpKeepAlive.TotalMilliseconds)

# Allow all self signed certificates
if ($disableSslVerification) {
    Disable-SslVerification
}

if ($auth -eq "Windows") {
    $clientContext = [ClientContext]::new($serviceUrl, $credential, $transactionTimeout, $culture)
} elseif ($auth -eq "NavUserPassword") {
    if ($Credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
        throw "You need to specify credentials if using NavUserPassword authentication"
    }
    $clientContext = [ClientContext]::new($serviceUrl, $credential, $transactionTimeout, $culture)
} else {
    throw "Unsupported authentication setting"
}

try {
    Run-Tests -clientContext $clientContext -testSuite $testSuite -testPage $testPage -AzureDevOps $AzureDevOps -Detailed:$detailed -XUnitResultFileName $XUnitResultFileName
} finally {
    if ($disableSslVerification) {
        Enable-SslVerification
    }
    $clientContext.Dispose()
}
