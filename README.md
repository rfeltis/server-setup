# server-setup

Ansible setup for my Debian home server (`s`, 192.168.1.2).

## Fresh install or repair

Install Debian, log in as your normal user, and run:

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rfeltis/server-setup/main/bootstrap.sh)"
```

This works from bash or fish. It installs git and Ansible, clones this repo to `~/code/server-setup`, runs the playbook, and then logs in to GitHub and adds the server's SSH key so you can push changes. Set `SKIP_GITHUB=1` to skip the GitHub step.

If you set a root password in the Debian installer, sudo isn't installed. As root, run `apt-get install -y sudo && usermod -aG sudo <user>`, then log out and back in.

## Applying changes

Edit `playbook.yml`, then run:

```
~/code/server-setup/apply.sh
```

Extra arguments go to `ansible-playbook`. For example, `./apply.sh --check --diff` previews changes, `./apply.sh --tags docker` runs only the Docker tasks, and `./apply.sh --tags updates` runs only the automatic update tasks.

## What it sets up

- Command-line tools: fish, tmux, eza, btop, bat, fzf, zoxide, fastfetch, micro, ncdu, ffmpeg, mkvtoolnix, gocryptfs, and others
- ZFS from Debian backports. If the `tank` pool isn't imported, the playbook imports it with `zpool import -f`. After an OS reinstall, the new system has a different host ID, so ZFS needs `-f` to take over the pool.
- ZED alerts to Gotify (see below)
- Docker from Docker's apt repository, with your user in the `docker` group. Docker only starts when the ZFS pool is mounted (see below).
- Nightly container updates (see below)
- Unattended upgrades for Debian, Debian security, and Docker packages. apt refreshes the package lists at 00:30 and installs upgrades at 01:00, and the server reboots at 06:00 when an update needs one. Kopia backs up every 12 hours, at 00:00 and 12:00 UTC, and the reboot time is set after the 12:00 UTC run (04:00 local in winter, 05:00 in summer). If you change Kopia's snapshot interval, check the reboot time still clears it. Change the times with `apt_update_time`, `apt_upgrade_time`, and `apt_reboot_time`.
- fish as your login shell, linked to `fish/config.fish` in this repo
- fzf key bindings in bash, and mouse support in tmux

## Docker and the ZFS pool

The containers keep their data under `/mnt/data` on the ZFS pool. If the pool isn't mounted, Docker refuses to start, so containers never start on empty folders on the root disk and set themselves up from scratch. The pool might not be mounted after a reboot if, for example, ZFS didn't build for a new kernel. Once `mountpoint /mnt/data` says it's a mountpoint again, run:

```
sudo systemctl reset-failed docker
sudo systemctl start docker
```

## Editing the compose file

The nightly update runs the projects in `compose_projects` with root access. The `music` container and the `stryke` SMB share could otherwise write anywhere in `/mnt/data` as your user, so `/mnt/data`, `/mnt/data/home`, and the main compose file are owned by root, and only the `docker` group can edit the compose file. Edit it in place on the server, for example with micro or nano. You can't edit it over SMB.

To add a folder directly in `/mnt/data` or `/mnt/data/home`, create it with `sudo mkdir`, then give it to the right user with `sudo chown`. Don't delete `/mnt/data/.music-unlink-recovery`, because music can't recreate it there.

## Compose secrets

Passwords, tokens, and keys don't go in the compose file. Each app that needs them has an env file in `/mnt/data/secrets`, for example `secrets/vaultwarden.env`, and the compose file loads it:

```yaml
    env_file:
      - path: ./secrets/vaultwarden.env
        format: raw
```

With `format: raw`, each line is `NAME=value` and the value is used exactly as written, with no quoting and no `$` handling. Blank lines and lines starting with `#` are skipped, but spaces at the end of a line become part of the value. Only root and the `docker` group can open `/mnt/data/secrets`, so the `music` container and SMB users can't read or change the files.

Create and edit the files as your own user, not with sudo. Every compose command reads all of a project's env files, so a file you can't read breaks the nightly update for the whole project. After editing one, recreate the app from `/mnt/data` with `docker compose up -d <service>`.

## Container updates

At 02:17 every night, cron runs `~/.local/bin/update-containers`. For each project in `compose_projects`, it:

1. Pulls new images with `docker compose pull`. An image refused with `toomanyrequests` is pulled again after 15 seconds, a minute, and 3 minutes, because lscr.io has a rate limit shared by all its users.
2. On Saturdays, rebuilds the services with a `build:` section (Caddy and music) with fresh base images. Change the day with `container_rebuild_weekday`. Before rebuilding, it keeps the current images as `<name>:previous`, so a bad rebuild can be rolled back. For Caddy, run `docker tag caddy-duckdns:previous caddy-duckdns:local && docker compose up -d --no-deps caddy` from `/mnt/data`.
3. Recreates only the running containers whose image changed, then checks that they're running, and healthy if they have a health check. Containers you stopped stay stopped. Edits to the compose file only reach containers that get recreated for an image update, so after editing it, run `docker compose up -d <service>` for the services you changed.
4. Restarts the containers in `container_restart_after_update` when the container they connect to was updated, and checks that they reconnect. Home Assistant needs this after a Z-Wave JS update.

Afterwards it removes old images and build cache older than a week, and checks for containers left with Compose's temporary names. Change the time with `container_update_hour` and `container_update_minute`. Keep it after the apt upgrade at 01:00 and before the 06:00 reboot, because an upgrade of Docker or containerd breaks a `docker compose` run that's in progress.

It sends a Gotify message listing the updated and restarted containers. If anything goes wrong, it sends a high-priority message instead. If nothing changed, it stays quiet. The messages go to Gotify on this host (`gotify_local_url`), not through the reverse proxy, so you still hear about a proxy update that breaks the proxy. To see the logs, run:

```
journalctl -t update-containers
```

To run it by hand, run `~/.local/bin/update-containers`. Add `--rebuild` to rebuild the local images on another day. Add `--dry-run` to list the containers whose new image is already on the server (pulled or built, but not yet in use), without pulling, building, or changing anything. To hold a container at a version, pin its image tag in the compose file.

## Gotify token

The Gotify token isn't stored in this public repo. The playbook reads it from `/mnt/data/bootstrap/secrets.yml` on the ZFS pool, which survives an OS reinstall:

```yaml
gotify_url: https://gotify.example.com
gotify_token: <app token>
```

The file must be owned by your user, because the playbook reads it without sudo. Keep it private with `chmod 600`. If it's missing, the playbook skips the Gotify alert script, the container update script runs without notifications, and the playbook shows a warning.
