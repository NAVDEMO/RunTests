codeunit 50000 InstallApp
{
    Subtype=Install;

    trigger OnInstallAppPerCompany()
    var
        LoadTests: Codeunit LoadTests;
    begin
        LoadTests.LoadAllTests();        
    end;
}