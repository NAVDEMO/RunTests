using Microsoft.Dynamics.Framework.UI.Client;

namespace RunTests
{
    public class AuthenticationSetting
    {
        public AuthenticationScheme AuthenticationScheme { get; set; }
        public string Authority { get; set; }
        public string Resource { get; set; }
        public string ClientId { get; set; }
        public string ClientSecret { get; set; }
        public string ServiceUrl { get; set; }
        public string Username { get; set; }
        public string Password { get; set; }
    }
}
