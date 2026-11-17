using System.Diagnostics;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace RunwaySlopes;

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new MainForm());
    }
}

// A window holding the page in WebView2 (the Edge engine built into Windows). The page is served from a made-up https host
// so its downloads from OurAirports and OpenStreetMap work exactly as on the website.
class MainForm : Form
{
    const string Host = "runway-slopes.local";
    readonly WebView2 web = new() { Dock = DockStyle.Fill };

    public MainForm()
    {
        Text = "Runway Slopes & Intersections (loading)";
        Size = new Size(1400, 900);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(0x0f, 0x14, 0x18);   // the page's background, so there's no white flash
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        Controls.Add(web);
        Load += async (_, _) => await StartAsync();
    }

    async Task StartAsync()
    {
        try
        {
            // saved settings and intersections (localStorage) live here, so they survive restarts
            var dataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RunwaySlopes");
            var env = await CoreWebView2Environment.CreateAsync(null, dataDir);
            await web.EnsureCoreWebView2Async(env);
        }
        catch (WebView2RuntimeNotFoundException)
        {
            MessageBox.Show("This app needs the Microsoft Edge WebView2 Runtime, which is missing on this PC.\n\nInstall it from Microsoft's WebView2 page, then start the app again.",
                "Runway Slopes", MessageBoxButtons.OK, MessageBoxIcon.Error);
            Close();
            return;
        }

        var core = web.CoreWebView2;
        core.SetVirtualHostNameToFolderMapping(Host, Path.Combine(AppContext.BaseDirectory, "web"), CoreWebView2HostResourceAccessKind.Allow);
        core.DocumentTitleChanged += (_, _) => Text = core.DocumentTitle;
        // links that open a new tab (OurAirports, OpenStreetMap copyright) go to the normal browser
        core.NewWindowRequested += (_, e) =>
        {
            e.Handled = true;
            OpenInBrowser(e.Uri);
        };
        core.NavigationStarting += (_, e) =>
        {
            if (!e.Uri.StartsWith($"https://{Host}/", StringComparison.OrdinalIgnoreCase)) { e.Cancel = true; OpenInBrowser(e.Uri); }
        };
        core.Navigate($"https://{Host}/index.html");
    }

    static void OpenInBrowser(string uri)
    {
        if (uri.StartsWith("https://", StringComparison.OrdinalIgnoreCase) || uri.StartsWith("http://", StringComparison.OrdinalIgnoreCase))
            Process.Start(new ProcessStartInfo(uri) { UseShellExecute = true });
    }
}
