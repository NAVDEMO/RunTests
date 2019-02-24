# RunTests

This is a Proof Of Concept prototype of a PowerShell based test runner for NAV / Business Central.

The Test Runner will execute a test suite with GUI Allowed set to True to allow you to run normal tests and also testpages.

It is NOT part of this POC how to create test suites or add tests to the test suite. The idea is that this should be done in the OnInstall trigger of the app you want to test, from a RapidStart package, an API, some PowerShell cmdlets or whats best.

## Files
- RunTests.ps1 is the "old" (a few days old) version, which does everything in one script. This was later split up into three files:
- ClientContext.ps1 is a PowerShell class for creating a Client Services connection. This class cannot be included before the right versions of NewtonSoft.dll and UI.Client.dll
- PsTestRunner.ps1 is a PowerShell script, which based on the parameters connect to your NAV/BC instance (as a faceless client), Open a page and use that page to run tests. The page used is ID=61266, which needs to be imported first. The page is available here: http://aka.ms/pstesttoolfob. The PsTestRunner uses control names instead of captions and doesn't need transalations.
- RunTests2.ps1 invokes PsTestRunner.ps1 on your machine with some parameters. The DLLs are grabbed from the Test Assemblies subfolder in the repository, which might or might not be the right version.
- Run-TestsInNavContainer is what will end up in NavContainerHelper. This will invoke tests from inside a Container - locating the DLLs inside the container. This function will also download the PsTestRunner and ClientContext scripts to the container. 

## Get Started
Create a container for testing. You can use a script like this:
```
$imageName = "mcr.microsoft.com/businesscentral/onprem:w1"
$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)
$containerName = "fkdev"
New-NavContainer -imageName $imageName -containerName $containerName -accept_eula -updateHosts -auth NavUserPassword -Credential $credential -includeCSide -enableSymbolLoading -includeTestToolkit
```
Import the PsTestTool page manually, or using a script like this:
```
$fobfile = Join-Path $env:TEMP "PSTestTool.fob"
Download-File -sourceUrl "https://aka.ms/pstesttoolfob" -destinationFile $fobfile
Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $credential
```
Open page 130401 in the Web Client (use the shortcut on the desktop called fkdev Test Tool) and import a number of tests to the DEFAULT test suite.

Run RunTests2.ps1 to invoke the test runner from the host.

Run Run-TestsInNavContainer.ps1 to invoke the test runner inside the container

## What next

- Run-TestsInNavContainer will become part of NavContainerHelper for use in CI/CD
- Currently the test runner page is hardcoded at ID=61266 - this will either be part of the Testtoolkit, become an AL App or find another way to not block an object ID.
- Tests, Tests, Tests
- Blog posts will be updated on running tests
- Describe mechanisms for apps to add their tests to testsuites on install (thanks Mike Glue for the PR/Idea)
- Project will move to microsoft based github repo
- This github repository will be deleted.