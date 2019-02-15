using CommandLine;

namespace RunTests
{
    public class TestSettingsBase
    {
        [Option('t', "testsuite", Required = false, Default = "DEFAULT", HelpText = "Name of Test Suite to run (default is DEFAULT)")]
        public string TestSuite { get; set; }
        [Option('g', "testpage", Required = false, Default = "130401", HelpText = "Page ID of the Test Tool Page (default is 130401)")]
        public string TestPage { get; set; }
        [Option('v', "verbose", Required = false, HelpText = "Set output to verbose messages.")]
        public bool Verbose { get; set; }
    }

    [Verb("file", HelpText = "Use Service Connection File")]
    public class TestSettingsConnectionFile : TestSettingsBase
    {
        [Option('s', "serviceconnection", Required = true, HelpText = "Business Central Service Connection File")]
        public string ServiceConnectionFile { get; set; }
    }


    public class TestSettingsWithServiceUrl : TestSettingsBase
    {
        [Option('s', "serviceurl", Required = true, HelpText = "Business Central Client Service Url")]
        public string ServiceUrl { get; set; }
    }

    [Verb("windows", HelpText = "Use Windows Authentication")]
    public class WindowsAuthTestSettings : TestSettingsWithServiceUrl
    {

    }

    [Verb("usernamepassword", HelpText = "Use Username Password Authentication")]
    public class NavUserPasswordAuthTestSettings : TestSettingsWithServiceUrl
    {
        [Option('u', "username", Required = true, HelpText = "Business Central User Name")]
        public string Username { get; set; }
        [Option('p', "password", Required = true, HelpText = "Business Central User Password")]
        public string Password { get; set; }
    }

    [Verb("aad", HelpText = "Use Azure Active Directory Authentication")]
    public class AadAuthTestSettings : TestSettingsWithServiceUrl
    {
        [Option('u', "username", Required = true, HelpText = "Business Central User Name")]
        public string Username { get; set; }
        [Option('p', "password", Required = true, HelpText = "Business Central User Password")]
        public string Password { get; set; }
        [Option('a', "authority", Required = true, HelpText = "Authority endpoint (https://login.microsoftonline.com/{azuretenantId}/)")]
        public string Authority { get; set; }
        [Option('r', "resource", Required = true, HelpText = "Resource for which authentication is required")]
        public string Resource { get; set; }
        [Option('i', "clientid", Required = true, HelpText = "Client Id for the Aad App")]
        public string ClientId { get; set; }
        [Option('k', "clientsecret", Required = true, HelpText = "Client Secret Key for the Aad App")]
        public string ClientSecret { get; set; }

    }

}
