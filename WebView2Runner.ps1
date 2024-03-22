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
    [String] $Url = "https://assets/index.html",
    [String] $UserDataFolder = "$($env:APPDATA)\WebView2",
    [String] $IconPath = "",
    [String] $BackgroundImagePath = "",
    [Switch] $ContextMenu = $false,
    [Switch] $TopMost = $false,
    [Switch] $DevTools = $false,
    # https://learn.microsoft.com/de-de/windows/win32/inputdev/virtual-key-codes
    # VK_LWIN 	    0x5B
    # VK_RWIN 	    0x5C
    # VK_F12        0x7B    OpenDevToolsWindow
    # VK_LCONTROL   0xA2
    # VK_RCONTROL   0xA3
    [Int[]] $KeyTraps = @(),
    [ArgumentCompleter({
        Add-Type -AssemblyName System.Windows.Forms
        [enum]::GetNames([System.Windows.Forms.FormBorderStyle])
    })]
    [ValidateScript({
        Add-Type -AssemblyName System.Windows.Forms
        $null -ne [System.Windows.Forms.FormBorderStyle] $_
    })]
    $BorderStyle = 'Sizable',
    [ArgumentCompleter({
        Add-Type -AssemblyName System.Windows.Forms
        [enum]::GetNames([System.Windows.Forms.FormWindowState])
    })]
    [ValidateScript({
        Add-Type -AssemblyName System.Windows.Forms
        $null -ne [System.Windows.Forms.FormWindowState] $_
    })]
    $WindowState = 'Normal'
)

Set-ExecutionPolicy -ExecutionPolicy bypass -Scope Process

Add-Type -AssemblyName System.Windows.Forms

# Make sure you distribute following files
Add-Type -Path "$PSScriptRoot\Microsoft.Web.WebView2.WinForms.dll"
Add-Type -Path "$PSScriptRoot\Microsoft.Web.WebView2.Core.dll"

Add-Type -ReferencedAssemblies System.Windows.Forms -Language CSharp -TypeDefinition @'
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class Window : Form {

    private delegate int HookProc(int code, IntPtr wParam, IntPtr lParam);
    private HookProc LowLevelKeyboardHookProcedure;
    static IntPtr hHook = (IntPtr)0;

    [System.Runtime.InteropServices.DllImport("user32.dll", EntryPoint = "SetWindowsHookEx", SetLastError = true)]
    static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool UnhookWindowsHookEx(IntPtr idHook);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    static extern int CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    
    public const int WM_SYSCOMMAND = 0x0112;
    public const int SC_CLOSE = 0xF060;
    public const int WH_KEYBOARD_LL = 13;

    public bool ClosedByWindow { get; set; }

    public Int32[] KeyTraps = {};

    public int LowLevelKeyboardHook(int nCode, IntPtr wParam, IntPtr lParam)
    {
        Int32 intValue = Marshal.ReadInt32(lParam);
        
        if(Array.IndexOf(KeyTraps, intValue) > -1) {
            return 1;
        }

        return CallNextHookEx(hHook, nCode, wParam, lParam); 
    }

    protected override void OnActivated (EventArgs e) {
        base.OnActivated(e);
        ClosedByWindow = false;
        LowLevelKeyboardHookProcedure = new HookProc(LowLevelKeyboardHook);
        hHook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardHookProcedure, (IntPtr)0, 0);
    }

    protected override void OnClosed (EventArgs e) {
        base.OnClosed(e);

        UnhookWindowsHookEx(hHook);
    }
    
    protected override void WndProc(ref Message m) {

        if (m.Msg == WM_SYSCOMMAND && m.WParam.ToInt32() == SC_CLOSE) {
            ClosedByWindow = true;
        }

        base.WndProc(ref m);
    }
}
'@

$script = @"
const runner = Object.defineProperties(window.chrome.webview, {
    user: {
        value: {upn: '$(WHOAMI /upn)'}
    },
    closing: {
        value: function(e) {
            if(window.confirm("Beenden?")) {
                window.close();
            }
        }
    }
});   

addEventListener('closing', runner.closing);

// index.html:
// removeEventListener('closing', runner.closing);
// addEventListener('closing', (e) => { /* do what you want */ });
"@

$window = New-Object -TypeName Window -Property @{
    KeyTraps = $KeyTraps
    WindowState = $WindowState
    FormBorderStyle = $BorderStyle
    TopMost = $TopMost
    BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Center
    BackgroundImage = if($BackgroundImagePath) {
        [System.Drawing.Image]::FromFile($BackgroundImagePath)
    } else {$null}
    Icon = if($IconPath) {
        [System.Drawing.Icon]::new($IconPath)
    } else {$null}
}

$webview = New-Object 'Microsoft.Web.WebView2.WinForms.WebView2' -Property @{
    DefaultBackgroundColor = [System.Drawing.Color]::Transparent
}

$webview.CreationProperties = New-Object 'Microsoft.Web.WebView2.WinForms.CoreWebView2CreationProperties'
$webview.CreationProperties.UserDataFolder = $UserDataFolder;

function quit {
    $webview.Dispose()
    $window.Dispose()
}

$webview.Add_CoreWebView2InitializationCompleted({

    $window.Add_FormClosing({
        param($h, $e)
        
        if($window.ClosedByWindow) {
            $e.cancel = $true
            $webview.CoreWebView2.ExecuteScriptAsync('window.dispatchEvent(new Event("closing"));')
        } 
    })
    
    # CoreWebView2HostResourceAccessKind.Allow    1
    # CoreWebView2HostResourceAccessKind.Deny     0
    # CoreWebView2HostResourceAccessKind.DenyCors 2
    $webview.CoreWebView2.SetVirtualHostNameToFolderMapping('assets', "$PSScriptRoot\assets", 1)
    $webview.CoreWebView2.Add_WindowCloseRequested({
        $window.ClosedByWindow = $false
        quit
    })

    $webview.CoreWebView2.Add_DocumentTitleChanged({
        param($h, $e)
        $window.text = $h.get_DocumentTitle()
    })

    if($DevTools) {$webview.CoreWebView2.OpenDevToolsWindow()}
    $webview.CoreWebView2.Settings.AreDefaultContextMenusEnabled = $ContextMenu

    $webview.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync($script) 
 
})


$webview.Size = $window.Size
$webview.Dock = "Fill"
$webview.Source = $Url

$window.Controls.Add($webview)
$window.Activate()

$window.ShowDialog() | Out-Null

quit
