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

Extra arguments go to `ansible-playbook`. For example, `./apply.sh --check --diff` previews changes, and `./apply.sh --tags docker` runs only the Docker tasks.

## What it sets up

- Command-line tools: fish, tmux, eza, btop, bat, fzf, zoxide, fastfetch, micro, ncdu, ffmpeg, mkvtoolnix, gocryptfs, and others
- ZFS from Debian backports. If the `tank` pool isn't imported, the playbook imports it with `zpool import -f`. After an OS reinstall, the new system has a different host ID, so ZFS needs `-f` to take over the pool.
- ZED alerts to Gotify (see below)
- Docker from Docker's apt repository, with your user in the `docker` group
- Unattended upgrades for Debian, Debian security, and Docker packages, with an automatic reboot at 04:00 when an update needs one
- fish as your login shell, linked to `fish/config.fish` in this repo
- fzf key bindings in bash, and mouse support in tmux

## Secrets

The Gotify token isn't stored in this public repo. The playbook reads it from `/mnt/data/bootstrap/secrets.yml` on the ZFS pool, which survives an OS reinstall:

```yaml
gotify_url: https://gotify.example.com
gotify_token: <app token>
```

The file must be owned by your user, because the playbook reads it without sudo. Keep it private with `chmod 600`. If it's missing, the playbook skips the Gotify alert script and shows a warning.
