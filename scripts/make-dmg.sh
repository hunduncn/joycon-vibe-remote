#!/bin/zsh
set -euo pipefail

# Builds the app and wraps it in a drag-to-Applications disk image.
script_dir="${0:A:h}"
project_dir="${script_dir:h}"
app_name="Joy-Con Vibe Remote"
bundle="${project_dir}/.build/app/${app_name}.app"
version="$(plutil -extract CFBundleShortVersionString raw "${project_dir}/Resources/Info.plist")"
dmg_dir="${project_dir}/.build/dmg"
dmg="${dmg_dir}/Joy-Con-Vibe-Remote-${version}.dmg"
staging="${dmg_dir}/staging"

/bin/zsh "${script_dir}/build-app.sh"

if [[ "${staging}" != "${project_dir}/.build/dmg/"* ]]; then
    print -u2 "Refusing to stage outside the project build directory."
    exit 1
fi
rm -rf "${staging}" "${dmg}"
mkdir -p "${staging}"
ditto "${bundle}" "${staging}/${app_name}.app"
ln -s /Applications "${staging}/Applications"

hdiutil create \
    -volname "${app_name}" \
    -srcfolder "${staging}" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${dmg}" >/dev/null
rm -rf "${staging}"
hdiutil verify "${dmg}" >/dev/null
print "${dmg}"
