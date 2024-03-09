Set-ExecutionPolicy -ExecutionPolicy bypass -Scope Process


Add-Type -AssemblyName System.Windows.Forms

Add-Type -Path "$PSScriptRoot\Microsoft.Web.WebView2.WinForms.dll"
Add-Type -Path "$PSScriptRoot\Microsoft.Web.WebView2.Core.dll"

$script = @"
 const runner = window.chrome.webview;   
"@

$window = New-Object -TypeName System.Windows.Forms.Form -Property @{
   # WindowState = 'Maximized';
    #FormBorderStyle = 'None';
    TopMost = $true;
    TopLevel = $true;
}



$webview = New-Object 'Microsoft.Web.WebView2.WinForms.WebView2'
$webview.CreationProperties = New-Object 'Microsoft.Web.WebView2.WinForms.CoreWebView2CreationProperties'
$webview.CreationProperties.UserDataFolder = "$($env:APPDATA)\WebView2";

function quit {
    $webview.Dispose()
    $window.Dispose()
}

$webview.Add_CoreWebView2InitializationCompleted({
    $window.Add_FormClosing({
        param($sender, $event)
        $event.Cancel = $true
        $webview.CoreWebView2.ExecuteScriptAsync('window.close()')
        Write-Host "closing"
    })

    # CoreWebView2HostResourceAccessKind.Allow    1
    # CoreWebView2HostResourceAccessKind.Deny     0
    # CoreWebView2HostResourceAccessKind.DenyCors 2
    $webview.CoreWebView2.SetVirtualHostNameToFolderMapping('assets', "$PSScriptRoot\assets", 1)
   # $webview.CoreWebView2.Add_WindowCloseRequested({
    #    Write-Host "closing2"
    #    quit
   # })

    $webview.CoreWebView2.OpenDevToolsWindow()
    $webview.CoreWebView2.Settings.AreDefaultContextMenusEnabled = $false

    $webview.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync($script) 
 
})


$webview.Size = $window.Size
$webview.Dock = "Fill"
    $webview.Source = "https://assets/index.html"
$window.Controls.Add($webview)

$window.ShowDialog() | Out-Null

quit