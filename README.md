# WebView2Runner.ps1 #

Sometimes you want to start a WebApp as a desktop application. Fortunately, Chromium/Edge is available as a browser engine for this - called WebView2. To keep the use as simple and universal as possible, here is this Powershell script and the necessary information.

Today you can start a WebApp as a BowserApp with a manifest file. With this script you are able to start your application in foreground and full screen mode and intercept certain key combinations. This enables you to start your WebApp in kiosk mode. 

At the moment this script is only useful for Windows. But if WebView2 is also available for other OS, it should not be a problem to transfer the implementation to other OS.

## Prerequisites ##
By default, files `Microsoft.Web.WebView2.Core.dll`, `Microsoft.Web.WebView2.WinForms.dll` and `WebView2Loader.dll` are required in the script's local folder. These are the interfaces so that you can access WebView2 with Powershell. You can find the files in the corresponding folder by executing the following command  `Install-Package Microsoft.Web.WebView2 -verbose -Force -Source https://www.nuget.org/api/v2 -Scope AllUsers -Destination $env:ALLUSERSPROFILE`.
Index.html is started in the assets folder if nothing else is passed as a parameter.

## Usage
Typically start the script with `powershell.exe -Command ".\WebViewRunner.ps1"`. With `-Command` we are also able to pass parameters as an array (see later).

A typical programme call looks like this:

`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -NonInteractive -Command .\WebViewRunner.ps1 -TopMost -WindowState Maximized -BorderStyle None -KeyTraps 91,162,163"`

## Parameters 
### -Url ###
By default the script looks at https://assets/index.html in the script's local assets folder to start your WebApp. This url is in a *secure context*, i.e. everything that requires __https__ can be implemented. You can also choose any other url you like.

### -UserDataFolder ###
Webview2 needs a location to store the browsing history, cookies, indexeddb, etc. By default, this data is stored under `$($env:APPDATA)\WebView2`. You can choose any other location where the current user can access it.

### -IconPath ###
If you like, you can set the icon in the window bar by specifying the path to an .ico file.

### -BackgroundImagePath ###
If your WebApp takes longer to load, you can display a background image until then. If your WebApp defines its own background, this background image will be overwritten after loading.

### -ContextMenu ###
If the typical context menu of the browser is to be displayed, this switch must be set (default: false).

### -TopMost ###
For applications in kiosk mode, it is necessary that this application is permanently superimposed on all others (default: false).

### -DevTools ###
If you are still developing the application, it can be helpful to start the developer mode of the browser (default: false). However, it is not enough to prevent developer mode later with a key combination (see later).

### -BorderStyle ###
Possible values:
* Fixed3D (default)
* FixedSingle
* None (required for kioskmode)
### -WindowState ###
Possible values:
* Normal (default)
* minimized
* Maximized (required for kioskmode)

### -KeyTraps ###
Sometimes it is important that keystrokes are intercepted. Keyboard entries that are not processed further can be defined here. For example, to prevent the start menu from being displayed, write:
`-KeyTraps 91, 92`, or `-KeyTraps 0x5B, 0x5C`. To prevent DevTools you can trap `0xA2, 0xA3`. __-keytraps__ take one or more keycodes as an array of decimal or hexcodes. More information about keycodes at https://learn.microsoft.com/de-de/windows/win32/inputdev/virtual-key-codes