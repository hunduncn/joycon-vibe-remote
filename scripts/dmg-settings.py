# dmgbuild settings for the drag-to-install disk image. make-dmg.sh passes
# the app and resource paths with -D. The icon positions match the spots
# drawn on Resources/DMGBackground.svg. The background itself is set by
# make-dmg.sh through Finder: macOS 26 ignores the alias dmgbuild writes.
import os.path

app = defines["app"]
app_name = os.path.basename(app)

files = [app]
symlinks = {"Applications": "/Applications"}
icon = defines["volume_icon"]

# make-dmg.sh adds the background, then compresses the image.
format = "UDRW"
filesystem = "HFS+"

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
window_rect = ((200, 160), (640, 420))
default_view = "icon-view"
show_icon_preview = False
include_icon_view_settings = True
arrange_by = None
icon_size = 104
text_size = 13
label_pos = "bottom"
icon_locations = {
    app_name: (170, 205),
    "Applications": (470, 205),
}
