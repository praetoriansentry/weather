# Installing the hourly systemd timer

The service runs `weather.sh` once an hour as user `john`, writing
`/var/lib/weather/weather.png` and `/var/lib/weather/weather.svg`.

## 1. Install dependencies

`weather.sh` shells out to `curl`, `xmllint`, `gnuplot`, `awk`, and
`paste`. On Debian/Ubuntu:

```
sudo apt install curl libxml2-utils gnuplot
```

(`awk` and `paste` ship with the base install via `mawk` and
`coreutils`.) `gnuplot` pulls in the `pngcairo` and `svg` terminals
that `meteogram.gp` uses. On Fedora/RHEL the equivalent is
`sudo dnf install curl libxml2 gnuplot`; on Arch,
`sudo pacman -S curl libxml2 gnuplot`.

## 2. Create the output directory

```
sudo install -d -o john -g john -m 0755 /var/lib/weather
```

## 3. Install the unit files

```
sudo cp weather.service weather.timer /etc/systemd/system/
sudo systemctl daemon-reload
```

## 4. Enable and start the timer

```
sudo systemctl enable --now weather.timer
```

`enable` makes it start at boot; `--now` also kicks it off immediately so the
next firing follows the hourly schedule.

## 5. Verify

```
systemctl list-timers weather.timer        # next/last trigger times
systemctl status weather.service           # last run result
journalctl -u weather.service -n 50        # recent log output
ls -la /var/lib/weather/                   # the generated files
```

Run the service manually once to sanity-check (doesn't wait for the timer):

```
sudo systemctl start weather.service
```

## Tweaks

- **Change the location:** edit `ExecStart` in `weather.service`, adding
  `--lat LAT --lon LON` flags. After editing:
  `sudo systemctl daemon-reload && sudo systemctl restart weather.timer`
- **Change the cadence:** edit `OnCalendar=` in `weather.timer`. Examples:
  `*:0/30` (every 30 min), `*-*-* *:15:00` (at :15 past every hour).
- **Change the output path:** edit the `--out` argument in `weather.service`
  and the `ReadWritePaths=` line to match.

## Uninstall

```
sudo systemctl disable --now weather.timer
sudo rm /etc/systemd/system/weather.service /etc/systemd/system/weather.timer
sudo systemctl daemon-reload
```
