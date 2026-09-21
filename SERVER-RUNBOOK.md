# Home NAS / media server runbook

This document is the recovery guide for the home NAS described by this
repository. Its goal is to make a rebuild possible without relying on memory.

## Scope and evidence

The configuration in this repository describes a Docker-based media, download,
photo, and sync server. It uses `/volume1`, which strongly suggests a Synology
NAS, but the host model, DSM version, disk/RAID layout, network configuration,
and currently running container versions have **not** been inspected from this
workspace.

Facts labelled **VERIFY** must be captured on the NAS and kept with the backup.
Do not treat an unverified value in this guide as a recovery fact.

Useful source files in this repository:

- `docker-compose.yaml` — current service definition; it must be committed or
  backed up separately before it can be relied upon for recovery.
- `setup-server-folders.sh` — creates the baseline host directory layout.
- `fix.md` — NZBDav, Sonarr, and Radarr integration notes.
- `architecture-diagram.xml` — editable architecture diagram.
- `report-nzbdav-storage.sh` — measures virtual NZBDav media and its local
  cache on the NAS.

## First: make the configuration recoverable

The following are prerequisites, not optional housekeeping:

1. Put the Compose file, this runbook, and non-secret scripts under version
   control. At present the working copy's Compose file is not tracked by Git.
2. Never commit `.env`, database password files, rclone configuration, API
   keys, cookies, or application databases to a public repository. Store an
   encrypted copy in the backup instead.
3. Rotate the Homarr encryption key and the Sonarr API key currently present
   in local configuration/scripts, then remove literal secret values from
   tracked files. A lost Homarr encryption key may make its encrypted settings
   unreadable.
4. Write the host facts in the next section and test a restore at least once.

## Host identity — fill this in on the NAS

| Item | Value |
| --- | --- |
| NAS model / serial | **VERIFY** |
| DSM version | **VERIFY** |
| Docker/Container Manager and Compose version | **VERIFY** |
| CPU architecture (`x86_64`/`aarch64`) | **VERIFY** |
| LAN IP, hostname, and DNS name | **VERIFY** |
| Time zone | `Europe/Berlin` in most containers |
| Primary application user | UID `1027`, GID `100` in most containers; **VERIFY user name** |
| Plex user | UID/GID `297536`; **VERIFY whether this must be retained** |
| Data volume | `/volume1`; **VERIFY filesystem, disks, RAID/SHR layout, encryption, and mount options** |
| Secondary Docker volume | `/volume2` is optional in the folder script; **VERIFY whether used** |
| Router/NAT/TLS/reverse proxy | **VERIFY** — none are defined by the current Compose file |

Capture the following output after any material change and save it with the
encrypted backup (it contains host metadata but should still be kept private):

```sh
date -Is
uname -a
cat /etc.defaults/VERSION 2>/dev/null || cat /etc/os-release
docker version
docker compose version || docker-compose version
docker compose ps --all
docker image ls
df -hT
mount
id 1027
getent group 100
```

Also record the DSM Storage Manager screenshot/export showing each disk, pool,
volume, filesystem, and any volume-encryption key location. A Compose backup
cannot recreate that storage layout.

## Architecture

```text
Requesters / indexers
          |
      Overseerr
          |
       Prowlarr ------------------------------+
          |                                   |
  Sonarr / Anime Sonarr / Radarr / Lidarr / Bookshelf
          |                                   |
       SABnzbd (regular downloads)            |
          |                                   |
 /volume1/data/usenet/{incomplete,complete}   |
                                              |
 NZBDav <-- rclone FUSE mount `nzb-dav:` ------+
    |            (shared mount propagation)
    +--> `*-nzbdav` symlink libraries

Plex reads local media and NZBDav libraries
Immich stores photo data in UPLOAD_LOCATION and metadata in its PostgreSQL DB
Syncthing syncs the Obsidian backup folder
```

There are two distinct media paths:

- Regular downloads are written to the `usenet/complete` folders and imported
  into persistent media directories.
- NZBDav media is exposed through a FUSE/rclone mount. The library entries are
  normally symlinks, so the full visible media size is not normally stored on
  the NAS. Local storage is mainly link metadata plus the rclone VFS cache.

The rclone service is configured with a maximum VFS cache of 20 GiB and a
24-hour maximum cache age. The `report-nzbdav-storage.sh` script reports the
logical media total, actual link-directory use, and current cache use. Do not
size a replacement disk from the logical total unless the replacement will
download and retain those files locally.

## Services and LAN ports

All images except the pinned Immich database/Valkey references use mutable tags
such as `latest` or `release`. They are convenient but not reproducible. Record
the image digest of each working deployment before a rebuild; ideally pin each
image to that digest after testing an update.

| Service | Purpose | Host port | Persistent state |
| --- | --- | --- | --- |
| `rclone` | FUSE mount of `nzb-dav:` for NZBDav | none | rclone config and `/volume1/docker/rclone-cache` |
| `nzbdav` | Turns SABnzbd history into symlink imports | 3000 | `/volume1/docker/appdata/nzbdav` |
| `sabnzbd` | Usenet downloader | 8080 | app config and `data/usenet` |
| `prowlarr` | Indexer management | 9696 | app config |
| `sonarr` | TV automation | 8990 | config and `sonarr-db` PostgreSQL |
| `sonarr-db` | Sonarr PostgreSQL 16 | 7001 | DB data and password-file directory |
| `anime-sonarr` | Anime TV automation | 8995 | config and `anime-sonarr-db` PostgreSQL |
| `anime-sonarr-db` | Anime Sonarr PostgreSQL 17 | 7003 | DB data and password-file directory |
| `radarr` | Movie automation | 8310 | config and `radarr-db` PostgreSQL |
| `radarr-db` | Radarr PostgreSQL 17 | 7002 | DB data and password-file directory |
| `plex` | Media streaming | host network | `/volume1/docker/appdata/plex` and media folders |
| `overseerr` | Media requests | 8078 | `/volume1/docker/appdata/Overseer` |
| `tautulli` | Plex statistics | 8181 | Tautulli config |
| `homarr` | Dashboard | 4755 | Homarr app data and encryption key |
| `dashdot` | Host dashboard | 3001 | no application data; reads host filesystem |
| `bookshelf` | Books/Readarr-like management | 8787 | Bookshelf config and book folders |
| `lidarr` | Music automation | 8686 | Lidarr config and music folders |
| `syncthing` | Obsidian sync/backup | 8384 | Syncthing config and `/volume1/backups/syncthing/obsidian` |
| `immich-server` | Photo/video application | 2283 | `UPLOAD_LOCATION` plus Immich database |
| `immich-machine-learning` | Immich ML worker | none | named `model-cache` volume; rebuildable |
| `redis` | Immich queue/cache (Valkey) | none | no explicit host bind mount |
| `database` | Immich PostgreSQL | none | `DB_DATA_LOCATION` |

Plex uses `network_mode: host`; its other standard ports are therefore exposed
according to Plex's own runtime behavior and are not listed as Compose port
mappings. Verify firewall/router rules independently.

The database ports are published to the LAN in the current configuration.
Unless remote database administration is required, restrict them with the NAS
firewall or remove the mappings after confirming applications do not need them.

## Persistent data map

Back up bind mounts and data by purpose, not merely the Compose file.

### Tier 1 — irreplaceable or expensive to recreate

- Photo/video originals at `UPLOAD_LOCATION` (**VERIFY its `.env` value**).
- Immich PostgreSQL data at `DB_DATA_LOCATION` (**VERIFY its `.env` value**)
  plus a logical database dump.
- `/volume1/gallery/{library,upload,backups}` if still in use; these paths are
  created by the bootstrapper but are not mounted by the current Compose file.
  **VERIFY whether they are legacy data or active backups.**
- `/volume1/backups/syncthing/obsidian` if it is the only copy of that data.
- Any media deliberately kept locally under `/volume1/data/media`.

### Tier 2 — required to reproduce application behavior

- `/volume1/docker/appdata/{rclone,nzbdav,sabnzbd,prowlarr,sonarr,anime-sonarr,radarr,plex,Overseer,tautulli,homarr,bookshelf,lidarr,syncthing}`.
- The three Arr PostgreSQL directories and password-file directories:
  `sonarr-db`, `sonarr-db-secrets`, `anime-sonarr-db`,
  `anime-sonarr-db-secrets`, `radarr-db`, and `radarr-db-secrets`.
- The Compose file and Immich `.env` (encrypted/private), including
  `UPLOAD_LOCATION`, `DB_DATA_LOCATION`, `DB_PASSWORD`, `DB_USERNAME`, and
  `DB_DATABASE_NAME`.
- rclone remote configuration and any NZBDav, SABnzbd, indexer, Plex, or
  application tokens. Treat all of these as secrets.

### Tier 3 — useful but rebuildable

- `/volume1/data/usenet/complete` until imports have completed.
- `/volume1/data/media/{movies,tv,tv-anime,music,books}` if rebuilding the
  local library would be inconvenient.
- `/volume1/docker/rclone-cache` — rclone VFS cache. It is intentionally
  limited to 20 GiB and can be discarded for recovery.
- Immich's named `model-cache` volume — automatically regenerated.

### Tier 4 — disposable/temporary

- `/volume1/data/usenet/incomplete` and `/volume1/data/nzbdav/nzbdav-mnt`.
  Do not rely on either as the only copy of media or configuration.

For PostgreSQL, prefer logical dumps to copying a live database data directory.
Take a filesystem-level database copy only while its database container is
stopped, and restore it only to the same major PostgreSQL version.

## Backup procedure

Use an encrypted destination outside the NAS. A practical target is one local
backup plus one off-site copy; test that both can be read. The following is a
procedure, not an unattended backup system — automate it only after performing
and testing it manually.

1. Record the host inventory above and save `docker compose config --quiet`
   output only as a validation result. Do not save rendered Compose output in
   an unencrypted location because it may contain secrets.
2. Create timestamped SQL dumps while the database containers are running:

   ```sh
   backup_dir=/volume1/backups/manual/$(date +%F)
   mkdir -p "$backup_dir"

   docker compose exec -T sonarr-db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
     > "$backup_dir/sonarr.sql"
   docker compose exec -T anime-sonarr-db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
     > "$backup_dir/anime-sonarr.sql"
   docker compose exec -T radarr-db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
     > "$backup_dir/radarr.sql"
   docker compose exec -T database sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
     > "$backup_dir/immich.sql"
   ```

   Run these commands from the directory containing the Compose file. Check
   that each output file is non-empty and can be listed/read from the backup
   destination. The commands do not include passwords in shell history.
3. Stop containers before copying their app-data directories, or use a backup
   mechanism with application-consistent snapshots. This avoids half-written
   SQLite/config/database files:

   ```sh
   docker compose stop
   # Copy Tier 1 and Tier 2 data to the encrypted backup destination here.
   docker compose start
   ```

4. Copy the encrypted backup off the NAS. Include a manifest with creation
   date, source host identity, file sizes, checksums, and image digests.
5. Restore a sample database dump into a throwaway database or test host at
   least annually. A backup has not succeeded until a restore is verified.

## Host directory layout

`setup-server-folders.sh` creates the baseline directories. It defaults to
application data on `/volume1`; `--docker-volume2` moves only application data
to `/volume2`. Media, NZBDav, gallery, scripts, and backup paths remain on
`/volume1`.

The current Compose file additionally expects these paths, which the bootstrap
script does not explicitly create:

```text
/volume1/data/media/movies-nzbdav
/volume1/data/media/tv-nzbdav
/volume1/data/media/tv-anime-nzbdav
/volume1/docker/rclone-cache
/volume1/docker/appdata/anime-sonarr-db
/volume1/docker/appdata/anime-sonarr-db-secrets
/volume1/docker/appdata/syncthing
```

Create them before starting containers so ownership is deliberate. The folder
bootstrapper currently applies `chmod 777` to new directories. That is simple
for initial setup but too broad for a long-lived host; set ownership and the
least permissive mode that works for the service users, then document the
result here.

## NZBDav / rclone details

This is the fragile part of the stack and should be tested first after a
rebuild.

- rclone mounts remote `nzb-dav:` at
  `/volume1/data/nzbdav/nzbdav-mnt` using FUSE.
- The rclone mount is shared with containers via `:rshared` on the host data
  bind mount and `:slave` where media applications consume it. A replacement
  host must support FUSE and Docker bind-mount propagation.
- rclone runs as UID `1027`, GID `100`, uses `--links`, and records its log in
  `/volume1/docker/appdata/rclone/rclone.log`.
- Its VFS cache is `/volume1/docker/rclone-cache`, with `full` cache mode,
  20 GiB maximum size, and 24-hour maximum age.
- NZBDav listens on port 3000 and maps the same mount into its container at
  `/mnt/nzbdav`.

For Sonarr and Radarr, preserve the settings documented in `fix.md`:

- NZBDav download client host: `nzbdav`, port `3000`.
- Correct category per application (`tv`, `tv-anime`, or movies as configured).
- Completed Download Handling enabled.
- Remote Path Mapping uses the same `/mnt/nzbdav/completed-symlinks/...` path
  on both sides because the mount path is shared.
- Root folders must distinguish ordinary local media from NZBDav-sourced
  symlink libraries.

Before calling recovery complete, verify the rclone health check/mount, a new
NZBDav import, and Plex playback of an NZBDav item. Do not test this only with
the folder existing: it must be an accessible FUSE mount.

## Clean rebuild / disaster recovery order

Do not start an empty application stack until the saved configuration and
secrets are available. Empty app data can cause new database schemas, library
re-scans, or account setup that complicates restoration.

1. **Prepare the host.** Install the supported NAS operating system and Docker
   or Container Manager. Create/import the storage pool and volume, mount it
   at the documented paths, set timezone/NTP, firewall, and LAN addressing.
2. **Validate platform compatibility.** A Raspberry Pi is normally `aarch64`.
   Check each exact image/digest supports ARM64 before migration. The rclone
   FUSE mount and bind propagation are mandatory; do not assume they work on a
   Pi because they worked on DSM. Plex transcoding also requires a deliberate
   ARM performance/hardware-acceleration decision.
3. **Create identities and paths.** Recreate the service user/group or update
   every `PUID`/`PGID` and filesystem owner consistently. Create the baseline
   directory tree plus the four Compose-only paths listed above.
4. **Restore files while applications are stopped.** Restore Tier 1 and Tier 2
   bind mounts with owner/mode/timestamps intact. Restore the private `.env`,
   password files, rclone config, and Compose definition from the encrypted
   backup. Do not substitute placeholder database credentials.
5. **Validate the definition without exposing values.** In the Compose
   directory run:

   ```sh
   docker compose config --quiet
   docker compose pull
   ```

   On a recovery where the old images are available, prefer the saved digests
   to pulling mutable tags.
6. **Restore databases.** Start only the four database services (`sonarr-db`,
   `anime-sonarr-db`, `radarr-db`, and `database`). Restore the matching SQL
   dump to its matching database using `psql`; then stop them if further
   app-data copy is required. For an Immich restore, follow the Immich version
   matching the saved server version — schema compatibility is version-specific.
7. **Start the mount path first.** Bring up NZBDav and rclone, then prove the
   mount is live:

   ```sh
   docker compose up -d nzbdav rclone
   docker compose ps
   docker compose exec rclone sh -c 'ls -la /data/nzbdav-mnt | head'
   ```

8. **Start the remaining services.**

   ```sh
   docker compose up -d
   docker compose ps
   ```

9. **Verify in dependency order.** Check Prowlarr and SABnzbd, Arr databases
   and queues, NZBDav import handling, Plex libraries/playback, Immich login
   and originals, Syncthing folder health, then dashboard/statistics services.

If a service will not start, collect `docker compose logs --tail=200 SERVICE`
and confirm its bind mount exists with the expected UID/GID before changing
configuration.

## Routine operations

Run from the directory containing `docker-compose.yaml`:

```sh
docker compose ps
docker compose logs --tail=100 rclone nzbdav
docker compose config --quiet
docker compose pull                 # review image changes before applying
docker compose up -d
```

Before updating a mutable image tag, take the Tier 1/2 backup and record the
current image digest. Update one group at a time and check the relevant health
path. In particular, test Immich database migrations and NZBDav/rclone mount
behavior before considering an update successful.

`delete_empty_movie_folders.sh` permanently deletes empty directories under
the local movies directory. Review its target with `find ... -empty -print`
before running it on a recovery or new host.

`sonarr_bulk_import.sh` calls the Sonarr API and must not contain a live API
key in version control. Keep its key in a private environment variable or
secret store and rotate the historical key before use.

## Recovery acceptance checklist

- [ ] Storage pool/volume, encryption, mounts, and permissions match the host
      record.
- [ ] Encrypted off-NAS backup and decryption instructions are available.
- [ ] Compose definition, `.env`, secret files, and rclone configuration are
      restored from the same backup date.
- [ ] Every database dump restored successfully and application data is
      visible.
- [ ] `rclone` is healthy and the NZBDav mount is accessible inside dependent
      containers.
- [ ] SABnzbd can write its incomplete and complete folders.
- [ ] Sonarr, Anime Sonarr, and Radarr show their libraries and queues without
      recreating or losing existing records.
- [ ] Plex finds both local and NZBDav libraries and plays a representative
      item.
- [ ] Immich shows expected users, albums, metadata, and an original file.
- [ ] Syncthing reports healthy folder synchronization.
- [ ] Router/firewall/reverse-proxy exposure matches the intended LAN-only or
      remote-access design.
- [ ] A dated recovery test result is stored with the backup.

## Open items to complete

1. Fill in the host identity table and save a disk/RAID/export record.
2. Decide which current media, gallery, and game folders are actually
   irreplaceable versus re-downloadable.
3. Confirm the values and backup location for Immich's `.env` variables.
4. Confirm where the encrypted backup, its key, and its recovery instructions
   are stored. The key must not live only on this NAS.
5. Inventory router, DNS, reverse proxy, TLS certificates, and external access
   rules; these are absent from the Compose file.
6. Pin known-good image digests and record which services have been tested on
   the replacement architecture before choosing a Raspberry Pi.
