"""Remove the background bookmark that dmgbuild adds to a disk image's .DS_Store.

dmgbuild stores the window background twice: as a classic alias in the icon
view settings and as a `pBBk` bookmark. Finder on macOS 26 tries the bookmark
first, fails to resolve it on the user's Mac and then shows no background at
all. Without the bookmark it falls back to the alias, which resolves correctly.

Usage: python remove-background-bookmark.py <mounted-volume>
"""
import sys

from ds_store import DSStore

with DSStore.open(f"{sys.argv[1]}/.DS_Store", "r+") as store:
    store.delete(".", b"pBBk")
    remaining = {entry.code for entry in store if entry.filename == "."}

if b"pBBk" in remaining or b"icvp" not in remaining:
    sys.exit("background bookmark was not removed cleanly")
