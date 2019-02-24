Param(
    [string] $containerName = "fkdev",
    [pscredential] $credential = (New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)),
    [string] $testSuite = "DEFAULT",
    [string] $XUnitResultFileName = "C:\ProgramData\NavContainerHelper\Results.xml",
    [ValidateSet('no','error','warning')]
    [string] $AzureDevOps = 'no'
)

$TestRunnerFolder = "C:\ProgramData\NavContainerHelper\PsTestTool"
If (!(Test-Path -Path $TestRunnerFolder -PathType Container)) { New-Item -Path $TestRunnerFolder -ItemType Directory | Out-Null }

$PsTestRunnerPath = Join-Path $TestRunnerFolder "PsTestRunner.ps1"
$ClientContextPath = Join-Path $TestRunnerFolder "ClientContext.ps1"
$fobfile = Join-Path $TestRunnerFolder "PSTestTool.fob"

if (!(Test-Path $PsTestRunnerPath)) {
    Download-File -sourceUrl "https://aka.ms/pstestrunnerps1" -destinationFile $PsTestRunnerPath
}
if (!(Test-Path $ClientContextPath)) {
    Download-File -sourceUrl "https://aka.ms/clientcontextps1" -destinationFile $ClientContextPath
}
if (!(Test-Path $fobfile)) {
    Download-File -sourceUrl "https://aka.ms/pstesttoolfob" -destinationFile $fobfile
}
Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $credential

Invoke-ScriptInNavContainer -containerName $containerName { Param([pscredential] $credential, [string] $testSuite, [string] $PsTestRunnerPath, [string] $XUnitResultFileName)

    $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
    $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
    $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
    [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
    $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
    $idx = $publicWebBaseUrl.IndexOf('//')
    $protocol = $publicWebBaseUrl.Substring(0, $idx+2)
    $disableSslVerification = ($protocol -eq "https://")

    . $PsTestRunnerPath -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -TestSuite $testSuite -XUnitResultFileName $XUnitResultFileName -serviceUrl "${protocol}localhost/NAV/cs" -credential $credential -disableSslVerification:$disableSslVerification

} -argumentList $credential, $testSuite, $PsTestRunnerPath, $XUnitResultFileName

& notepad.exe $XUnitResultFileName
