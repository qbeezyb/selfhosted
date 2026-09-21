#!/bin/sh
# Report the logical size represented by NZBDav media-library entries.
#
# Run on the NAS host (not on a Mac):
#   sh report-nzbdav-storage.sh
#
# This only reads directory metadata.  It does not copy or download media.

set -eu

if [ "$#" -gt 0 ]; then
  paths="$*"
else
  # Prefer the paths named in the request, then fall back to the paths used by
  # docker-compose.yaml.  One path is selected for each library, avoiding a
  # double-count if both layouts are aliases for the same data.
  paths=''
  for library in tv-nzbdav tv-anime-nzbdav movies-nzbdav; do
    for base in /volume1/data/media; do
      candidate="$base/$library"
      if [ -e "$candidate" ] || [ -L "$candidate" ]; then
        paths="$paths $candidate"
        break
      fi
    done
  done
fi

human_bytes() {
  awk -v bytes="$1" 'BEGIN {
    split("B KiB MiB GiB TiB PiB", unit, " ")
    i = 1
    while (bytes >= 1024 && i < 6) { bytes /= 1024; i++ }
    printf "%.2f %s", bytes, unit[i]
  }'
}

total_bytes=0
total_files=0
total_local_kib=0
found_paths=0

printf '%-42s %14s %14s %10s %10s\n' 'Library' 'Logical size' 'Local entries' 'Files' 'Symlinks'
printf '%-42s %14s %14s %10s %10s\n' '-------' '------------' '-------------' '-----' '--------'

for path in $paths; do
  [ -n "$path" ] || continue
  [ -e "$path" ] || [ -L "$path" ] || continue
  found_paths=$((found_paths + 1))

  # -L follows NZBDav's symlinks; stat's %s is the apparent file length, not
  # the storage blocks used by a FUSE mount.  This is the space required if
  # these visible media files were downloaded to a local disk.
  result=$(find -L "$path" -type f -exec stat -c '%s' '{}' + 2>/dev/null \
    | awk '{ bytes += $1; files += 1 } END { printf "%.0f %d", bytes, files }')
  bytes=${result% *}
  files=${result#* }
  links=$(find "$path" -type l -print 2>/dev/null | wc -l | tr -d ' ')
  # du without -L does not follow child symlinks.  For NZBDav's normal
  # symlink-library layout this is the small amount actually allocated for
  # directory entries and links on the NAS filesystem.
  local_kib=$(du -sk "$path" 2>/dev/null | awk 'NR == 1 { print $1 }')
  local_kib=${local_kib:-0}
  local_bytes=$((local_kib * 1024))

  printf '%-42s %14s %14s %10s %10s\n' "$path" "$(human_bytes "$bytes")" "$(human_bytes "$local_bytes")" "$files" "$links"
  total_bytes=$((total_bytes + bytes))
  total_files=$((total_files + files))
  total_local_kib=$((total_local_kib + local_kib))
done

if [ "$found_paths" -eq 0 ]; then
  echo 'No NZBDav library paths were found.' >&2
  echo 'Pass the paths explicitly, for example:' >&2
  echo '  sh report-nzbdav-storage.sh /volume1/media/tv-nzbdav /volume1/media/tv-anime-nzbdav /volume1/media/movies-nzbdav' >&2
  exit 1
fi

total_local_bytes=$((total_local_kib * 1024))
printf '%-42s %14s %14s %10s\n' 'TOTAL' "$(human_bytes "$total_bytes")" "$(human_bytes "$total_local_bytes")" "$total_files"
echo
echo 'Logical size is the media payload visible through NZBDav, including symlink targets.'
echo 'Local entries is the direct storage used by the library folders without following child symlinks.'

for cache in /volume1/docker/rclone-cache /volume1/data/nzbdav/cache; do
  if [ -d "$cache" ]; then
    cache_kib=$(du -sk "$cache" 2>/dev/null | awk 'NR == 1 { print $1 }')
    cache_bytes=$((cache_kib * 1024))
    printf 'Current local cache at %s: %s\n' "$cache" "$(human_bytes "$cache_bytes")"
  fi
done

echo 'For the configured rclone VFS cache, plan for up to another 20 GiB (its configured maximum).'
