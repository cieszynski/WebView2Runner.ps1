<#
    WebView2Runner.ps1

    Copyright (C) 2024 Stephan Cieszynski

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>

param(
    [String] $Url = "https://assets/index.html"
)

Set-ExecutionPolicy -ExecutionPolicy bypass -Scope Process

Add-Type -AssemblyName System.Windows.Forms

# Make sure you distribute following files
Add-Type -Path "$PSScriptRoot\Microsoft.Web.WebView2.WinForms.dll"
Add-Type -Path "$PSScriptRoot\Microsoft.Web.WebView2.Core.dll"



$script = @"
const runner = window.chrome.webview;   

window.onbeforeclose = (event) => {
alert(event)
}
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
        #quit
    })

    # CoreWebView2HostResourceAccessKind.Allow    1
    # CoreWebView2HostResourceAccessKind.Deny     0
    # CoreWebView2HostResourceAccessKind.DenyCors 2
    $webview.CoreWebView2.SetVirtualHostNameToFolderMapping('assets', "$PSScriptRoot\assets", 1)
    $webview.CoreWebView2.Add_WindowCloseRequested({
        Write-Host "closing2"
        quit
    })

    $webview.CoreWebView2.OpenDevToolsWindow()
    $webview.CoreWebView2.Settings.AreDefaultContextMenusEnabled = $false

    $webview.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync($script) 
 
})


$webview.Size = $window.Size
$webview.Dock = "Fill"
    $webview.Source = $Url
$window.Controls.Add($webview)

$window.ShowDialog() | Out-Null

quit