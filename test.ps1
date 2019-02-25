# Load DLL's
Add-type -Path "C:\Users\freddyk\Documents\GitHub\NAVDEMO\RunTests\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"
Add-type -Path "C:\Users\freddyk\Documents\GitHub\NAVDEMO\RunTests\Test Assemblies\NewtonSoft.json.dll"
. "C:\ProgramData\NavContainerHelper\PsTestTool\ClientContext.ps1"

$clientcontext = [ClientContext]::new("http://fkdev/NAV/cs", ([timespan]::FromMinutes(10)), "en-US")


$form = $clientcontext.OpenForm(61266)
$clientcontext.GetFormInfo($form)

$windowsusername = "user manager\containeradministrator"
#New-NavContainerNavUser -containerName fkdev -WindowsAccount $windowsusername -PermissionSetId SUPER

Invoke-ScriptInNavContainer -containerName fkdev {
    $newtonSoftDllPath = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\NewtonSoft.json.dll").FullName
    $clientDllPath = "C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll"

    Add-type -Path $clientDllPath
    Add-type -Path $newtonSoftDllPath

    . "C:\ProgramData\NavContainerHelper\PsTestTool\ClientContext.ps1"

    $clientcontext = [ClientContext]::new("http://fkdev/NAV/cs", ([timespan]::FromMinutes(10)), "en-US")
    whoami

    $form = $clientcontext.OpenForm(61266)
    $clientcontext.GetFormInfo($form)
}