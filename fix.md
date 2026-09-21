---

docker-compose changes

Add :slave to the nzbdav mount volume in Sonarr's container, and mount a writable directory for the Sonarr library on the
nzbdav mount:

sonarr:
volumes: - /volume1/docker/appdata/sonarr:/config - /volume1/data/media/tv:/data/media/tv # real downloads - /volume1/data/nzbdav/nzbdav-mnt:/mnt/nzbdav:slave # rclone mount with :slave # add any other volumes you already have

---

nzbdav settings

Settings → SABnzbd:

- Rclone Mount Directory: /mnt/nzbdav (the path as Sonarr sees it inside its container)
- Categories: make sure tv (or tv-anime) is listed
- Import Strategy: Symlinks
- Always send full History: enabled

---

Sonarr settings

Settings → Download Clients:

- Host: nzbdav
- Port: 3000
- Category: tv
- Completed Download Handling: enabled ← critical

Settings → Download Clients → Remote Path Mappings:

- Host: nzbdav
- Remote Path: /mnt/nzbdav/completed-symlinks/tv/
- Local Path: /mnt/nzbdav/completed-symlinks/tv/

Settings → Media Management → Root Folders:

- /mnt/nzbdav for nzbdav-sourced TV shows

---

The two things that were broken for Radarr — and will be broken for Sonarr without fixing — are the :slave mount
propagation and Completed Download Handling being disabled.
