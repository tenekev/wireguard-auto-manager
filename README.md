# Wireguard Auto Manager

## What it does?

Ever wished for Wireguard to:
- auto-activate once you are away from your home network?
- auto-deactivate once you are home?

Now you can!

## Requirements

This project relies on Powershell and Windows Task Scheduler. Both are available on any modern windows machine. These are the minimum dependencies:

- [Wireguard's Client for Windows](https://www.wireguard.com/install/)
- A valid Wireguard Tunnel .conf file
- PS2EXE installed (If you want to build the binary yourself)

## Setup

1. Download the `wg_auto_manager.exe` [Or build it yourself](#build-it-yourself)
2. Move the `wg_auto_manager.exe` file in its final location
3. Move the `tunnel.conf` file in its final location
4. Issue the following command for an **initial run** to create a Scheduled Task:

```
path\to\wg_auto_manager.exe "Your Wi-Fi Network" "path\to\tunnel.conf" -RegisterTask:True
```

- `"Your Wi-Fi Network"` is a string containing one or more local Wi-Fi networks. 
  - Separate network names with a `|` character. 
  - Disconnecting from them will activate the tunnel and connecting to them will deactivate the tunnel.
- `"path\to\tunnel.conf"` is an absolute path to your tunnel config. 
  - Due to [how the WG CLI works](https://github.com/WireGuard/wireguard-windows/blob/master/docs/enterprise.md#tunnel-service), the config file is read every time. That's why it needs a static location. 
  - You can still have the same tunnel imported in the Wireguard Manager and if the names correspond, the status of the tunnel will be reflected in the GUI. If the names differ, the tunnel that is auto-activated will not be visible in the GUI.
- `-RegisterTask:True` is used to **create** or **update** the scheduled task. 
  - The task can be found in the root directory of the Task Scheduler. 
  - Triggers on `NetworkEvenId:10000` (Network re-connect)
  - Runs with highest elevation
  - Runs command `path\to\wg_auto_manager.exe "Your Wi-Fi Network" "path\to\tunnel.conf"`
  - Values for `path\to\wg_auto_manager.exe`, `Your Wi-Fi Network`, `path\to\tunnel.conf` are taken from the `.exe` location and the supplied arguments on its **initial run**. That's why it's import to have the `.exe` and `.conf` files in their final places.
  - If you have moved the `.exe`, `.conf` or need another update, run the above command again with the new value. **You will be asked to confirm the update!**

5. To update an existing task
```
new_path\to\wg_auto_manager.exe "Your New Wi-Fi Network" "new_path\to\tunnel.conf" -RegisterTask:True
```

## Why not just the PS1 script instead of a binary?
Calling a PS1 script creates a window that disrupts the experience. There is no way around it. Call me shallow, I don't like gimmicky windows popping up. 

You can call the script with the following command. The problem is that it will **always** create a window, even if it's just for a fraction of a second. It works fine, it's just ugly.

```powershell
powershell -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File "path\to\wg_auto_manager.ps1" "Your Wi-Fi Network" "path\to\tunnel.conf"
```

## Build it yourself
wg_auto_manager.exe is built with the [ps2exe module](https://github.com/MScholtes/PS2EXE). Here is a quick list of commands to set it up and build it yourself.

```powershell

Install-Module ps2exe

git clone https://github.com/tenekev/wireguard-auto-manager.git

cd ".\wireguard-auto-manager"

ps2exe .\wg_auto_manager.ps1 .\wg_auto_manager.exe -NoConsole -noOutput

.\wg_auto_manager.exe "Your Wi-Fi Network" "path\to\tunnel.conf" -RegisterTask:True

```

## Disclaimer

I'm not a PowerShell expert or a programmer for that matter. The code is written simply - do your due dilligence and read it before running it. 
I realize there are better ways to define the task and the logic. Contributions are greatly appreciated. 

### Sources


- [Wireguard for Windows CLI](https://github.com/WireGuard/wireguard-windows/blob/master/docs/enterprise.md)
- [PS2EXE](https://github.com/MScholtes/PS2EXE)
- [How to launch a command on network connection/disconnection?](https://superuser.com/a/262880/680010)
