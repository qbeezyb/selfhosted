#!/bin/bash
# NAS folder setup script
# Usage: ./setup-folders.sh [--docker-volume2]
#
# By default, docker appdata is created under /volume1/docker.
# Pass --docker-volume2 to place docker appdata on /volume2 instead
# (useful for multi-volume setups where volume2 is dedicated to docker).

DOCKER_VOLUME="volume1"

for arg in "$@"; do
  case $arg in
    --docker-volume2)
      DOCKER_VOLUME="volume2"
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--docker-volume2]"
      exit 1
      ;;
  esac
done

echo "Docker appdata volume: /$DOCKER_VOLUME"
echo "Data/media/scripts volume: /volume1"
echo ""

FOLDERS=(
  # Docker appdata
  "/$DOCKER_VOLUME/docker/appdata/prowlarr"
  "/$DOCKER_VOLUME/docker/appdata/Overseer"
  "/$DOCKER_VOLUME/docker/appdata/sabnzbd"
  "/$DOCKER_VOLUME/docker/appdata/plex"
  "/$DOCKER_VOLUME/docker/appdata/lidarr"
  "/$DOCKER_VOLUME/docker/appdata/anime-sonarr"
  "/$DOCKER_VOLUME/docker/appdata/readarr"
  "/$DOCKER_VOLUME/docker/appdata/tautulli"
  "/$DOCKER_VOLUME/docker/appdata/mealie"
  "/$DOCKER_VOLUME/docker/appdata/workoutwarrior"
  "/$DOCKER_VOLUME/docker/appdata/mylar3"
  "/$DOCKER_VOLUME/docker/appdata/kapowarr"
  "/$DOCKER_VOLUME/docker/appdata/calibre"
  "/$DOCKER_VOLUME/docker/appdata/watchlistarr"
  "/$DOCKER_VOLUME/docker/appdata/postgres"
  "/$DOCKER_VOLUME/docker/appdata/pgadmin"
  "/$DOCKER_VOLUME/docker/appdata/ombi"
  "/$DOCKER_VOLUME/docker/appdata/sonarr"
  "/$DOCKER_VOLUME/docker/appdata/radarr"
  "/$DOCKER_VOLUME/docker/appdata/nginx-proxy-manager"
  "/$DOCKER_VOLUME/docker/appdata/immich-app"
  "/$DOCKER_VOLUME/docker/appdata/nzbdav"
  "/$DOCKER_VOLUME/docker/appdata/rclone"
  "/$DOCKER_VOLUME/docker/appdata/home-assistant"
  "/$DOCKER_VOLUME/docker/appdata/homarr"
  "/$DOCKER_VOLUME/docker/appdata/bookshelf"
  "/$DOCKER_VOLUME/docker/appdata/radarr-db-secrets"
  "/$DOCKER_VOLUME/docker/appdata/radarr-db"
  "/$DOCKER_VOLUME/docker/appdata/sonarr-db-secrets"
  "/$DOCKER_VOLUME/docker/appdata/sonarr-db"
  "/$DOCKER_VOLUME/docker/dashdot"

  # Usenet data
  "/volume1/data/usenet/incomplete"
  "/volume1/data/usenet/complete"
  "/volume1/data/usenet/watch"
  "/volume1/data/usenet/scripts"

  # Media library
  "/volume1/data/media/movies"
  "/volume1/data/media/tv"
  "/volume1/data/media/tv-anime"
  "/volume1/data/media/music"
  "/volume1/data/media/4k-movies"
  "/volume1/data/media/xxx"
  "/volume1/data/media/books"
  "/volume1/data/media/img"
  "/volume1/data/media/files"
  "/volume1/data/media/games"

  # NZBDav
  "/volume1/data/nzbdav/nzbdav-mnt"
  "/volume1/data/nzbdav/cache"

  # Scripts
  "/volume1/scripts/logs"

  # Gallery
  "/volume1/gallery/library"
  "/volume1/gallery/upload"
  "/volume1/gallery/backups"

  # Backups
  "/volume1/backups/games"
)

CREATED=0
SKIPPED=0

for folder in "${FOLDERS[@]}"; do
  if [ -d "$folder" ]; then
    echo "  [skip]    $folder"
    ((SKIPPED++))
  else
    if mkdir -p "$folder"; then
      chmod 777 "$folder"
      echo "  [created] $folder"
      ((CREATED++))
    else
      echo "  [error]   $folder"
    fi
  fi
done

echo ""
echo "Done. Created: $CREATED, Skipped (already existed): $SKIPPED"


# to run, do `curl -fsSL https://raw.githubusercontent.com/quentinberry/selfhosted/main/setup-server-folders.sh | sudo bash`
