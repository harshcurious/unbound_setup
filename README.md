# `unbound_setup`

Self-contained helper scripts for running `unbound` locally on Linux with:

- a local DNS cache
- DNS-level blocking from HaGeZi RPZ lists
- a weekly refresh flow driven by your own cron job

This folder does **not** modify your system. It only gives you scripts, examples, and a manual setup path.

## Why this layout

For a laptop with low background overhead, `unbound` is a good fit because it is small and efficient. HaGeZi already publishes an `rpz` format that `unbound` understands, so the lightest path is:

1. fetch a published RPZ list
2. validate it
3. save a local zonefile and config snippet
4. point your own `unbound` config at those generated files
5. refresh it weekly with cron

The scripts here default to the `light` profile because it is the safest low-resource option.

## Files

- `scripts/fetch_hagezi_rpz.sh`: downloads a HaGeZi RPZ list or copies a local source file
- `scripts/validate_rpz.sh`: verifies that a file looks like a valid RPZ zone
- `scripts/update_blocklist.sh`: fetches, validates, and writes generated output files
- `examples/unbound-resolver.conf.example`: minimal local resolver example
- `examples/unbound-rpz.conf.example`: example RPZ config for `unbound`
- `examples/weekly-cron.example`: example weekly cron entry
- `state/`: default place for generated output if you run the updater locally in this folder

## Quick start

Run a local test update into this folder:

```sh
./scripts/update_blocklist.sh \
  --profile light \
  --zone-name hagezi.local \
  --output-dir ./state/generated \
  --state-dir ./state
```

That will create:

- `state/generated/hagezi-rpz.zone`
- `state/generated/hagezi-rpz.conf`
- `state/last-update.env`

## Supported profiles

- `light`
- `normal`
- `pro`
- `pro.mini`
- `pro.plus`
- `pro.plus.mini`
- `ultimate`
- `ultimate.mini`
- `tif`
- `tif.medium`
- `tif.mini`
- `fake`
- `popupads`

For a laptop, start with `light`. If you want stronger blocking without going too large, try `pro.mini` next.

## What the updater writes

`update_blocklist.sh` generates two files you can wire into `unbound` manually:

### `hagezi-rpz.zone`

This is the fetched RPZ zonefile.

### `hagezi-rpz.conf`

This is a ready-to-include snippet containing:

```conf
server:
    module-config: "respip validator iterator"

rpz:
    name: "hagezi.local"
    zonefile: "/your/output/dir/hagezi-rpz.zone"
    url: "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/light.txt"
    for-downstream: no
```

The `url:` line is kept intentionally because modern `unbound` supports RPZ downloads itself. If you want your weekly script to be the only refresh path, remove that line after your first successful sync.

If your existing `unbound` config already sets `module-config`, do not blindly overwrite it. Merge `respip` into the existing module chain instead.

## Manual implementation guide

These are the changes you would make yourself on a Linux system. This project does not apply them.

### 1. Install `unbound`

Examples:

```sh
sudo apt install unbound
sudo dnf install unbound
sudo pacman -S unbound
```

### 2. Generate the local RPZ files

Example:

```sh
/absolute/path/to/unbound_setup/scripts/update_blocklist.sh \
  --profile light \
  --zone-name hagezi.local \
  --output-dir /absolute/path/to/unbound_setup/state/generated \
  --state-dir /absolute/path/to/unbound_setup/state
```

### 3. Add a local resolver config to `unbound`

Create a small file such as `/etc/unbound/unbound.conf.d/local-resolver.conf` and base it on `examples/unbound-resolver.conf.example`.

Example:

```conf
server:
    interface: 127.0.0.1
    port: 53
    do-ip4: yes
    do-ip6: no
    access-control: 127.0.0.0/8 allow
    hide-identity: yes
    hide-version: yes
    prefetch: yes
    qname-minimisation: yes
    rrset-cache-size: 16m
    msg-cache-size: 8m
    cache-max-ttl: 86400
    cache-max-negative-ttl: 3600
```

### 4. Add the generated RPZ config to `unbound`

Option A: copy the generated config and zonefile into your normal `unbound` locations.

Option B: edit your `unbound` config to include the generated file from this project directly.

Example include line in your main config or a file under `unbound.conf.d`:

```conf
include: "/absolute/path/to/unbound_setup/state/generated/hagezi-rpz.conf"
```

If your distro runs `unbound` in a chroot or under a restricted service account, put the zonefile somewhere readable by `unbound` and update the `zonefile:` path accordingly.

### 5. Validate the final `unbound` config

Run:

```sh
sudo unbound-checkconf
```

If `unbound-checkconf` reports that the zonefile path is inaccessible, move the zonefile to a readable location such as `/var/lib/unbound/` and update the generated `hagezi-rpz.conf` path.

### 6. Start or restart the service manually

Typical commands:

```sh
sudo systemctl enable --now unbound
sudo systemctl restart unbound
sudo systemctl status unbound
```

This project does not run those commands for you.

### 7. Point your laptop at `127.0.0.1` for DNS

How you do this depends on your Linux stack.

If you use `systemd-resolved`, a temporary manual test looks like:

```sh
sudo resolvectl dns lo 127.0.0.1
sudo resolvectl domain lo '~.'
```

If you use NetworkManager, you would usually set the connection DNS server to `127.0.0.1` in the connection profile.

If your system manages `/etc/resolv.conf` directly, you would set:

```text
nameserver 127.0.0.1
```

Apply the method your distro already uses. Do not mix multiple DNS managers unless you know which one owns the final resolver state.

### 8. Verify that queries are going through `unbound`

Examples:

```sh
dig @127.0.0.1 example.com
dig @127.0.0.1 doubleclick.net
```

For a blocked domain from the RPZ, you should see an `NXDOMAIN`-style result or another RPZ action depending on the zone contents.

## Weekly updates with cron

Add a cron entry for your user with `crontab -e` and use `examples/weekly-cron.example` as a base.

Example:

```cron
17 3 * * 0 /absolute/path/to/unbound_setup/scripts/update_blocklist.sh --profile light --zone-name hagezi.local --output-dir /absolute/path/to/unbound_setup/state/generated --state-dir /absolute/path/to/unbound_setup/state
```

After the weekly job runs, reload `unbound` manually or add your own separate automation later. This project intentionally does not install a service or timer.

Common manual reload command:

```sh
sudo systemctl reload unbound
```

## Notes on resource usage

- `light` is the best starting point for low RAM and low CPU usage.
- `pro.mini` is a reasonable next step if you want more blocking.
- Full `tif` is much larger and is not a good first choice for a low-overhead laptop setup.
- `do-ip6: no` can simplify local-only setups if you do not care about IPv6 transport for DNS.

## Test the scripts

Run:

```sh
sh ./tests/test_unbound_setup.sh
```

## References used

- HaGeZi RPZ lists: `https://github.com/hagezi/dns-blocklists`
- Unbound RPZ support and `rpz:` configuration: NLnet Labs `unbound.conf(5)`
