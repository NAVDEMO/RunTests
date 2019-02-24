$fobfile = Join-Path $env:TEMP "PSTestTool.fob"
Download-File -sourceUrl "https://aka.ms/pstesttoolfob" -destinationFile $fobfile
Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $credential


. (Join-Path $PSScriptRoot "PsTestRunner.ps1") -XUnitResultFileName "c:\temp\results.xml"

& notepad.exe "c:\temp\results.xml"
