#!/bin/bash

# Maintainer: Sibren Vasse <arch@sibrenvasse.nl>
# Contributor: Ilya Gulya <ilyagulya@gmail.com>
pkgname="deezer"
pkgver=4.32.40
distfile="https://www.deezer.com/desktop/download/artifact/win32/x86/$pkgver"
checksum="325f4dc58bed0c85a16d6920b72e0c11b6b062b2ba4b52ffa3a98f34182c2eb9"
builddir="$PWD/builddir"
patchesdir="$PWD/patches"
filesdir="$PWD/files"
dir_electronrebuild="$PWD/builddir/electron-rebuild"
_electronversion="6.1.12"

# ----------------------- "METHODS"
install_node_module() {
    printf "\nChecking if module %s is installed... " "$1"

    if [ "$(npm list -g | grep "$1" -c)" -gt 0 ]; then
        printf "OK."
    else
        printf "NO.\nNode is installing %s... " "$1"

        if [ "$1" == "asar" ]; then
            sudo npm install --silent -g --engine-strict "$1" && printf "OK." || exit 1
        else
            sudo npm install --silent -g "$1" && printf "OK." || exit 1
        fi
    fi
}

check_xbps_package() {
    if [ "$(xbps-query "$1" | wc -l)" -gt 0 ]; then
        true
    else
        false
    fi
}

# ----------------------- MAIN FUNCTIONS/STEPS

pre_extract() {
    # Dependency check steps
    printf "Checking system dependencies...\n"

    printf "p7zip... "
    check_xbps_package p7zip || sudo xbps-install -y p7zip > /dev/null
    printf "OK.\nwget... "
    check_xbps_package wget || sudo xbps-install -y wget > /dev/null
    printf "OK.\nImageMagick... "
    check_xbps_package ImageMagick || sudo xbps-install -y ImageMagick > /dev/null
    printf "OK."
    
    if ( ! check_xbps_package nodejs-lts ) && ( ! check_xbps_package nodejs-lts-10 ) && ( ! check_xbps_package nodejs ); then
        sudo xbps-install -y nodejs-lts
    fi

    # Check Electron 6 and set/detect the Electron 6 alias
    printf "\n\nChecking if Electron 6 is installed... "

	# we will install Electron 6 on a local folder as it is really old version, and it's the one Deezer is asking...
    # check if it's already here
	if [ -d "$HOME/electron6/node_modules/electron" ]; then
		printf "OK.\nChecking for Electron 6 updates... "
        cd "$HOME/electron6" && npm update electron@^6 && printf "OK.\n"
	else
		printf "NO.\nNode is installing Electron 6-1-x... "

        # create static folder, use Electron as static library
        mkdir -p "$HOME/electron6" && cd "$HOME/electron6" || exit 1
        npm i --silent --prefix ./ --no-package-lock --unsafe-perm electron@^6

        printf "OK.\n"
	fi

    # Check and install global node modules, if needed
    install_node_module asar
    install_node_module prettier

    sudo npm install -g node-gyp

    # Workdir
    printf "\nCreating (and cleaning) working directory... "
    rm -rf "$builddir" || true
    mkdir -p "$builddir"
    printf "OK."
    # Download packages, check SHA256 etc
    printf "\nDownloading Deezer win32 package... "
    cd "$builddir" || exit 1
    wget --quiet $distfile -O "setup.exe" >/dev/null && printf "OK.\nValidating SHA256 checksum... "
    [ "$(sha256sum setup.exe | grep "$checksum" -c)" -gt 0 ] && printf "OK." || exit 1
}

do_extract() {
    cd "$builddir" || exit 1

    printf "\n\nExtracting package... "
    7z x -so setup.exe "\$PLUGINSDIR/app-32.7z" > app-32.7z
    7z x -y -bsp0 -bso0 app-32.7z
    rm app-32.7z
    printf "OK."
}

pre_patch() {
    cd "$builddir" || exit 1
    # Mainly @SibrenVasse instructions, but additional steps seem to be required...

    # Extract png from ico container
    printf "\n\nExtracting icons... "
    convert resources/win/app.ico resources/win/deezer.png
    printf "OK."
    cd resources/ || exit 1

    printf "\nExtracing app bundle... "
    (rm -rf app "$builddir/npm_temp" || true) > /dev/null
    asar extract app.asar app &> /dev/null
    printf "OK."

    # Installing electron-rebuild locally
    printf "\nInstalling electron-rebuild (builddep-only)... "
    mkdir -p "$dir_electronrebuild"
    cd "$dir_electronrebuild" || exit 1
    npm i --silent -D --no-package-lock electron-rebuild
    electronrebuild="$PWD/node_modules/.bin/electron-rebuild"
    printf "OK."

    printf "\nMaking some adjustements on bundle... "
    cd "$builddir/resources" || exit 1
    mkdir -p app/resources/linux/
    cp win/systray.png app/resources/linux/systray.png
    # Remove NodeRT from package (-205.72 MiB)
    rm -r app/node_modules/@nodert
    printf "OK.\nDoing crazy stuff with some node.js modules... "

    # Install extra node modules for mpris-service
    mkdir "$builddir/npm_temp"
    cd "$builddir/npm_temp" || exit 1
    npm install --silent --prefix ./ mpris-service &> /dev/null

    for d in node_modules/*; do
        if [ ! -d "$builddir/resources/app/node_modules/$(basename $d)" ]
        then
            # come on, we need to rebuild those modules for Electron...
            cd "$d" || exit 1
            HOME=~/.electron-gyp node-gyp rebuild --target=$_electronversion --arch=x64 --dist-url=https://electronjs.org/headers &> /dev/null
            cd "$builddir/npm_temp" || exit 1

            mv "$d" "$builddir/resources/app/node_modules/"
        fi
    done

    printf "OK.\n\n"
}

do_patch() {
    cd "$builddir/resources/app" || exit 1
    echo "Patching..."
    $electronrebuild --version $_electronversion --module-dir . || exit 1
    prettier --write "build/*.js"

    # Disable menu bar
    patch -p1 < "$patchesdir/menu-bar.patch"
    patch -p1 < "$patchesdir/quit.patch"
    # Monkeypatch MPRIS D-Bus interface
    patch -p1 < "$patchesdir/0001-MPRIS-interface.patch"

    return
}

installation() {
    printf "\n\nPackaging app bundle again... "

    cd "$builddir/resources" || exit 1
    asar pack app app.asar
    printf "OK.\nInstalling Deezer system-wide... "

    cd "$builddir" || exit 1

    sudo mkdir -p /usr/share/deezer
    sudo mkdir -p /usr/share/applications
    sudo mkdir -p /usr/bin

    for size in 16 32 48 64 128 256 512; do
        sudo mkdir -p /usr/share/icons/hicolor/${size}x${size}/apps/
    done

    sudo install -Dm644 resources/app.asar /usr/share/deezer/
    sudo install -Dm644 resources/win/deezer-0.png /usr/share/icons/hicolor/16x16/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-1.png /usr/share/icons/hicolor/32x32/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-2.png /usr/share/icons/hicolor/48x48/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-3.png /usr/share/icons/hicolor/64x64/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-4.png /usr/share/icons/hicolor/128x128/apps/deezer.png
    sudo install -Dm644 resources/win/deezer-5.png /usr/share/icons/hicolor/256x256/apps/deezer.png
    sudo install -Dm644 "$filesdir/deezer.desktop" /usr/share/applications/
    sudo install -Dm755 "$filesdir/deezer" /usr/bin/

    # Make sure the deezer:// protocol handler is immediately registered as it's needed for login 
    sudo update-desktop-database --quiet

    printf "OK.\n\n"
}

pre_extract && do_extract && pre_patch && do_patch && installation
echo "Successfully installed Deezer Desktop!"