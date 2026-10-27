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

# dmgbuild lays out the installer window (icon positions, volume icon)
# without scripting Finder. It lives in a project-local virtual environment.
tools="${project_dir}/.build/dmg-tools"
if [[ ! -x "${tools}/bin/dmgbuild" ]]; then
    /usr/bin/python3 -m venv "${tools}"
    "${tools}/bin/pip" install --quiet --disable-pip-version-check "dmgbuild==1.6.5"
fi
writable="${dmg_dir}/writable.dmg"
rm -f "${writable}"
"${tools}/bin/dmgbuild" \
    -s "${script_dir}/dmg-settings.py" \
    -D app="${staging}/${app_name}.app" \
    -D volume_icon="${project_dir}/Resources/AppIcon.icns" \
    "${app_name}" \
    "${writable}" >/dev/null
rm -rf "${staging}"

# Finder on macOS 26 only shows a background whose alias Finder wrote
# itself, and it cannot pick a dot file. Copy the image under a visible
# name, let Finder set it, then hide the file.
mount_point="$(mktemp -d /tmp/joycon-dmg.XXXXXX)"
hdiutil attach "${writable}" -mountpoint "${mount_point}" -noautoopen -quiet
trap 'hdiutil detach "${mount_point}" -quiet 2>/dev/null || true' EXIT
cp "${project_dir}/Resources/DMGBackground.tiff" "${mount_point}/background.tiff"
set_background() {
    osascript - "${mount_point}" <<'APPLESCRIPT' >/dev/null
on run argv
    set volumeFolder to (POSIX file (item 1 of argv)) as alias
    tell application "Finder"
        open volumeFolder
        set theWindow to container window of volumeFolder
        set current view of theWindow to icon view
        set toolbar visible of theWindow to false
        set statusbar visible of theWindow to false
        set bounds of theWindow to {200, 160, 840, 608}
        set background picture of icon view options of theWindow to file "background.tiff" of volumeFolder
        delay 1
        close theWindow
    end tell
end run
APPLESCRIPT
}
# Finder writes .DS_Store asynchronously and sometimes skips the first
# visit to a fresh volume, so retry until the store names the image.
saved=false
for attempt in 1 2 3; do
    set_background
    for _ in {1..20}; do
        if grep -q "background.tiff" "${mount_point}/.DS_Store" 2>/dev/null; then
            saved=true
            break 2
        fi
        sleep 0.5
    done
    print -u2 "Finder has not saved the background yet (attempt ${attempt})."
done
if [[ "${saved}" != true ]]; then
    print -u2 "Finder did not save the installer background."
    exit 1
fi
chflags hidden "${mount_point}/background.tiff"
sync
hdiutil detach "${mount_point}" -quiet
trap - EXIT
rmdir "${mount_point}" 2>/dev/null || true

hdiutil convert "${writable}" -format UDZO -imagekey zlib-level=9 -o "${dmg}" -quiet
rm -f "${writable}"
hdiutil verify "${dmg}" >/dev/null
print "${dmg}"
