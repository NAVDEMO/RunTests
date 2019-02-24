Param(
    [string] $containerName = "fkdev",
    [pscredential] $credential = (New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)),
    [string] $XUnitResultFileName = "C:\ProgramData\NavContainerHelper\Results.xml",
    [ValidateSet('no','error','warning')]
    [string] $AzureDevOps = 'no'
)

$TestRunnerFolder = "C:\ProgramData\NavContainerHelper\PsTestTool"
If (!(Test-Path -Path $TestRunnerFolder -PathType Container)) { New-Item -Path $TestRunnerFolder -ItemType Directory | Out-Null }

$PsTestRunnerPath = Join-Path $TestRunnerFolder "PsTestRunner.ps1"
$ClientContextPath = Join-Path $TestRunnerFolder "ClientContext.ps1"

$WebClient = New-Object System.Net.WebClient
if (!(Test-Path $PsTestRunnerPath)) {
    $WebClient.DownloadFile('https://aka.ms/pstestrunnerps1', $PsTestRunnerPath)
}
if (!(Test-Path $ClientContextPath)) {
    $WebClient.DownloadFile('https://aka.ms/clientcontextps1', $ClientContextPath)
}
$WebClient.Dispose()

Invoke-ScriptInNavContainer -containerName $containerName { Param([pscredential] $credential, [string] $PsTestRunnerPath, [string] $XUnitResultFileName)

    $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
    $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
    $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
    [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
    $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
    $idx = $publicWebBaseUrl.IndexOf('//')
    $protocol = $publicWebBaseUrl.Substring(0, $idx+2)
    $disableSslVerification = ($protocol -eq "https://")

    . $PsTestRunnerPath -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -XUnitResultFileName $XUnitResultFileName -serviceUrl "${protocol}localhost/NAV/cs" -credential $credential -disableSslVerification:$disableSslVerification

} -argumentList $credential, $PsTestRunnerPath, $XUnitResultFileName

& notepad.exe $XUnitResultFileName
