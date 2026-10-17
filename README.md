# Sane defaults (sdef) WIP

A command line interface (CLI) utility for setting your default apps on linux.

Mainly targeted for window maonager users who do not have a simple way to set their default apps.

Written in [zig](https://ziglang.org/) 0.16.

## Features
* **List all apps of a specific category (browsers, video players etc...)**
* **Run your current default in a single command that can be used attached to a keybind**
* **Writes default to MIME so that your system uses them to open files and links** 
* **A single small executable**
* **Only one (temporary) dependency (gio)**
* **<1000 lines of pure zig**


## Installation
### currently only building from source is supported...
Make sure you have [zig](https://ziglang.org/) 0.16 and git installed.
run the following commands:
```bash
git clone https://github.com/boyair/defaults.git
cd defaults
zig build -Doptimize=ReleaseFast
```
Then grub the executable generated in zig-out/bin and paste it somewhere in your $PATH

(You can run ```echo $PATH``` to check where you can place the executeable)


## Usage
* ```defaualts -h``` to see available commands
* Set a shortcut to run your default app. For example:
```
"Mod+B" = "defaults -r browser"
```
Will run your default browser when pressing modifier+B (sytax of course depends on your window manager).

## Why I created this?
I tend to change the software I use a lot. I also am a window manager user.

When trying to change my default browser I was always annoyed that i have to go open my window manager config, search where is the bind to launch the browser is and modify it. Also, when I opened a link, it opened on the old browser and I didnt know how to change this. I couldnt find any software that solve this one specific problem so I desided to create it myself.

The only shell that has a solution is [DMS](https://danklinux.com/) to my knowledge.
