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
- Docker from Docker's apt repository, with your user in the `docker` group
- Nightly container updates (see below)
- Unattended upgrades for Debian, Debian security, and Docker packages. apt refreshes the package lists at 00:30 and installs upgrades at 01:00, and the server reboots at 04:00 when an update needs one. Change the times with `apt_update_time`, `apt_upgrade_time`, and `apt_reboot_time`.
- fish as your login shell, linked to `fish/config.fish` in this repo
- fzf key bindings in bash, and mouse support in tmux

## Container updates

At 02:00 every night, cron runs `~/.local/bin/update-containers`. For each project in `compose_projects`, it runs `docker compose pull`, then `docker compose up -d`, which recreates only the containers whose image changed. Services with a `build:` section are skipped. Afterwards it removes old images. Change the time with `container_update_hour`. Keep it after the apt upgrade at 01:00 and before the 04:00 reboot, because an upgrade of Docker or containerd breaks a `docker compose` run that's in progress.

It sends a Gotify message listing the updated containers. If a pull or `up` fails, it sends a high-priority message instead. If nothing changed, it stays quiet. To see the logs, run:

```
journalctl -t update-containers
```

To run it by hand, run `~/.local/bin/update-containers`. To hold a container at a version, pin its image tag in the compose file.

## Secrets

The Gotify token isn't stored in this public repo. The playbook reads it from `/mnt/data/bootstrap/secrets.yml` on the ZFS pool, which survives an OS reinstall:

```yaml
gotify_url: https://gotify.example.com
gotify_token: <app token>
```

The file must be owned by your user, because the playbook reads it without sudo. Keep it private with `chmod 600`. If it's missing, the playbook skips the Gotify alert script, the container update script runs without notifications, and the playbook shows a warning.
