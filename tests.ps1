$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)

Get-TestsFromNavContainer -containerName fkdev -credential $credential -testSuite "BUILTIN"

Run-TestsInNavContainer -containerName fkdev -credential $credential

Run-TestsInNavContainer -containerName fkdev -credential $credential -testSuite "HELLOWORLD"

Run-TestsInNavContainer -containerName fkdev -credential $credential -testSuite "DEFAULT" -testFunction "WorkingTest"

Run-TestsInNavContainer -containerName fkdev -credential $credential -testSuite "DEFAULT" -testGroup "kurt" -detailed

Run-TestsInNavContainer -containerName fkdev -credential $credential -testSuite "BUILTIN" -detailed

Run-TestsInNavContainer -containerName fkdev -credential $credential -testSuite "DEFAULT" -detailed -XUnitResultFileName "c:\programdata\navcontainerhelper\result.xml"
& notepad "c:\programdata\navcontainerhelper\result.xml"
