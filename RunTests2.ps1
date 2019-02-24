$clientDllPath = (Join-Path $PSScriptRoot "Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll")
$newtonSoftDllPath = (Join-Path $PSScriptRoot "Test Assemblies\NewtonSoft.json.dll")

$serviceUrl = "http://fkdev/NAV/cs"
$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)

$XUnitResultFileName = "c:\temp\results.xml"
    
. (Join-Path $PSScriptRoot "PsTestRunner.ps1") -newtonSoftDllPath $newtonSoftDllPath `
                                               -clientDllPath $clientDllPath `
                                               -serviceUrl $serviceUrl `
                                               -credential $credential `                                               -detailed `                                               -AzureDevOps error `                                               -XUnitResultFileName $XUnitResultFileName

& notepad.exe $XUnitResultFileName
