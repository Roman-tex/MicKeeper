# dmgbuild settings for the MicKeeper disk image.
# Invoked by scripts/package-dmg.sh with -D app=<path> -D background=<path>.
import os.path

app = defines["app"]  # noqa: F821 (provided by dmgbuild)
app_name = os.path.basename(app)

# Built writable so package-dmg.sh can adjust .DS_Store before compressing it.
format = "UDRW"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}

background = defines["background"]  # noqa: F821
window_rect = ((200, 120), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 13
arrange_by = None
icon_locations = {
    app_name: (160, 190),
    "Applications": (480, 190),
}
hide_extension = [app_name]
