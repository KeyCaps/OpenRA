#!/bin/bash
# OpenRA master packaging script

if [ $# -ne "2" ]; then
    echo "Usage: `basename $0` version outputdir"
    exit 1
fi

# Resolve the absolute source path from the location of this script
SRCDIR=$(readlink -f $(dirname $0)/../)
BUILTDIR="${SRCDIR}/packaging/built"
TAG=$1
OUTPUTDIR=$(readlink -f $2)

# Build the code and push the files into a clean dir
cd "$SRCDIR"
mkdir packaging/built
mkdir packaging/built/mods
make package

# Remove the mdb files that are created during `make`
find . -path "*.mdb" -delete

test -e Changelog.md && rm Changelog.md
wget https://raw.githubusercontent.com/wiki/OpenRA/OpenRA/Changelog.md

wget http://daringfireball.net/projects/downloads/Markdown_1.0.1.zip
unzip Markdown_1.0.1.zip
rm -rf Markdown_1.0.1.zip
./Markdown_1.0.1/Markdown.pl Changelog.md > CHANGELOG.html
./Markdown_1.0.1/Markdown.pl README.md > README.html
./Markdown_1.0.1/Markdown.pl CONTRIBUTING.md > CONTRIBUTING.html
./Markdown_1.0.1/Markdown.pl DOCUMENTATION.md > DOCUMENTATION.html
./Markdown_1.0.1/Markdown.pl Lua-API.md > Lua-API.html
rm -rf Markdown_1.0.1

# List of files that are packaged on all platforms
FILES=('OpenRA.Game.exe' 'OpenRA.Editor.exe' 'OpenRA.Utility.exe' \
'OpenRA.Renderer.Sdl2.dll' 'OpenRA.Renderer.Null.dll' \
 'lua' 'glsl' 'mods/common' 'mods/ra' 'mods/cnc' 'mods/d2k' 'mods/modchooser' \
'AUTHORS' 'COPYING' 'README.html' 'CONTRIBUTING.html' 'DOCUMENTATION.html' 'CHANGELOG.html' \
'global mix database.dat' 'GeoLite2-Country.mmdb')

echo "Copying files..."
for i in "${FILES[@]}"; do
    cp -R "${i}" "packaging/built/${i}" || exit 3
done

# SharpZipLib for zip file support
cp thirdparty/ICSharpCode.SharpZipLib.dll packaging/built

# FuzzyLogicLibrary for improved AI
cp thirdparty/FuzzyLogicLibrary.dll packaging/built

# SharpFont for FreeType support
cp thirdparty/SharpFont* packaging/built

# SDL2-CS
cp thirdparty/SDL2-CS* packaging/built

# Mono.NAT for UPnP support
cp thirdparty/Mono.Nat.dll packaging/built

# Eluant (Lua integration)
cp thirdparty/Eluant* packaging/built

# GeoIP database access
cp thirdparty/MaxMind.Db.dll packaging/built
cp thirdparty/MaxMind.GeoIP2.dll packaging/built
cp thirdparty/Newtonsoft.Json.dll packaging/built
cp thirdparty/RestSharp.dll packaging/built

# Copy game icon for windows package
cp OpenRA.Game/OpenRA.ico packaging/built

# Copy the Windows crash monitor
cp OpenRA.exe packaging/built

cd packaging
echo "Creating packages..."

if [ -x /usr/bin/makensis ]; then
    pushd windows
    echo "Building Windows setup.exe"
    makensis -V2 -DSRCDIR="$BUILTDIR" -DDEPSDIR="${SRCDIR}/thirdparty/windows" OpenRA.nsi
    if [ $? -eq 0 ]; then
        mv OpenRA.Setup.exe "$OUTPUTDIR"/OpenRA-$TAG.exe
    else
        echo "Windows package build failed."
    fi
    popd
else
    echo "Skipping Windows setup.exe build due to missing NSIS"
fi

pushd osx
echo "Zipping OS X package"
bash buildpackage.sh "$TAG" "$BUILTDIR" "${SRCDIR}/thirdparty/osx" "$OUTPUTDIR"
if [ $? -ne 0 ]; then
    echo "OS X package build failed."
fi
popd

pushd linux
echo "Building Linux packages"
bash buildpackage.sh "$TAG" "$BUILTDIR" "$OUTPUTDIR"
if [ $? -ne 0 ]; then
    echo "Linux package build failed."
fi
popd

echo "Package build done."

rm -rf $BUILTDIR
