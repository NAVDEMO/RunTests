using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RunTests
{
    class OAuthResult
    {
        public string Token_Type { get; set; }
        public string Scope { get; set; }
        public int Expires_In { get; set; }
        public int Ext_Expires_In { get; set; }
        public int Expires_On { get; set; }
        public int Not_Before { get; set; }
        public Uri Resource { get; set; }
        public string Access_Token { get; set; }
    }
}
