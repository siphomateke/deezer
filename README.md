# Deezer Ubuntu build script

Unofficial script to install Deezer desktop on Ubuntu. Based on [the AUR Script by SibrenVasse](https://aur.archlinux.org/packages/deezer/).

For Windows, Deezer distributes a version of the Electron run time (Windows binary) and the source code of their application itself. The build process of this package extracts the application source from the Windows installer.

This package applies several patches for:
- Compatability with newer Electron versions 
- Compatability with a Linux environment in general.
- Fixing bugs

## Building

To install on Ubuntu:

```bash
git clone https://github.com/siphomateke/deezer
cd deezer
chmod +x ./install.sh
npm install -g electron@^5 --unsafe-perm=true
npm install -g --engine-strict asar
npm install -g --engine-strict asar
sudo ./install.sh
```

The Deezer Windows installer will then be downloaded, extracted and patched to work for Linux.

## Debugging
Running the application from the commandline will show verbose logging.
```
deezer
```

To run the application with devtools by running
```
env DZ_DEVTOOLS=yes electron /usr/share/deezer/app.asar
```

To debug node, you can extract the source files to a directory and inspect the node process by attaching using the chromium debugging tools. (https://www.electronjs.org/docs/tutorial/debugging-main-process)
```
asar extract /usr/share/deezer/app.asar $dest
electron --inspect-brk=$port $dest
```
