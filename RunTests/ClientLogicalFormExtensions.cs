using System.Linq;
using Microsoft.Dynamics.Framework.UI.Client;

namespace RunTests
{
    /// <summary>
    /// Extensions class which interact with specific components such as the CRONUS dialog.
    /// </summary>
    public static class ClientLogicalFormExtensions
    {

        public static ClientRepeaterControl Repeater(this ClientLogicalForm form)
        {
            return form.ContainedControls.OfType<ClientRepeaterControl>().First();
        }

        public static string FindMessage(this ClientLogicalForm form)
        {
            return form.ContainedControls.OfType<ClientStaticStringControl>().First().StringValue;
        }

        public static TType FindLogicalFormControl<TType>(this ClientLogicalForm form, string controlCaption = null)
        {
            return form.ContainedControls.OfType<TType>().First();
        }

        /// <summary>
        /// Determines whether [is cronus demo dialog] [the specified dialog].
        /// </summary>
        /// <param name="dialog">The dialog.</param>
        /// <returns>
        ///   <c>true</c> if [is cronus demo dialog] [the specified dialog]; otherwise, <c>false</c>.
        /// </returns>
        public static bool IsCronusDemoDialog(ClientLogicalForm dialog)
        {
            if (dialog.IsDialog)
            {
                ClientStaticStringControl staticStringControl = dialog.ContainedControls.OfType<ClientStaticStringControl>().FirstOrDefault();
                if (staticStringControl != null && staticStringControl.StringValue != null)
                {
                    return staticStringControl.StringValue.ToUpperInvariant().Contains("CRONUS");
                }
            }

            return false;
        }

      
    }
}