$clientDllPath = (Join-Path $PSScriptRoot "Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll")
$newtonSoftDllPath = (Join-Path $PSScriptRoot "Test Assemblies\NewtonSoft.json.dll")

$serviceUrl = "http://fkdev/NAV/cs"
$clientServicesCredentialType = "NavUserPassword"
$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)

$XUnitResultFileName = "c:\temp\results.xml"

$testSuite = "DEFAULT"
$testCodeunit = "*"
$testFunction = "FinanceChargeMemoAndApply"
$disableSslVerification = $false

. (Join-Path $PSScriptRoot "PsTestFunctions.ps1") -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -clientContextScriptPath $ClientContextPath

try {    if ($disableSslVerification) {        Disable-SslVerification    }        $clientContext = New-ClientContext -serviceUrl $serviceUrl `                                       -auth $clientServicesCredentialType `                                       -credential $credential
    $tests = Get-Tests -clientContext $clientContext | ConvertFrom-Json

   # Run-Tests -clientContext $clientContext `
   #           -TestSuite $testSuite `
   #           -TestCodeunit $testCodeunit `
   #           -TestFunction $testFunction `
   #           -XUnitResultFileName $XUnitResultFileName `
   #           -AzureDevOps $AzureDevOps `
   #           -detailed:$detailed
}
finally {
    if ($disableSslVerification) {        Enable-SslVerification    }    Remove-ClientContext -clientContext $clientContext
}

& notepad.exe $XUnitResultFileName
