# Daily wallpaper (multi-source, GNOME)

This setup picks a **wallpaper source** from a **shuffled deck**, tries sources in order until one image downloads, sets the **GNOME** desktop background (light and dark), and prunes old files. After a **successful** run, that source is **removed** from the deck; when the deck is **empty**, all configured sources are **shuffled again** so each one is used **once per full cycle**, in a **random order** that changes each cycle.

Within a single run, if the first source fails (network, no image, etc.), the script **tries the next** source in the current deck.

---

## Sources

| Id | Description | API key |
|----|-------------|---------|
| `bing` | Bing daily spotlight (max resolution: UHD → 1080p → 720p) | None |
| `apod` | NASA Astronomy Picture of the Day | **NASA API key** (not `DEMO_KEY`) |
| `met` | The Met collection search (`q=`); subject via **`MET_SEARCH_QUERY`** (default: `cars and engines`) | None |
| `nasa_images` | NASA Image Library search ([images-api.nasa.gov](https://images-api.nasa.gov/)) | None |
| `unsplash` | Random landscape photo; subject via **`UNSPLASH_QUERY`** (default: `cars and engines`) | **Unsplash Access Key** |

Bing’s feed is widely used but **not** a documented stable public API.

---

## Register and generate API keys

Use your **own** keys; the script **rejects NASA `DEMO_KEY`** for `apod` so you are not tied to the low demo rate limits.

| Service | Sign up / dashboard |
|--------|----------------------|
| **NASA** (APOD and other `api.nasa.gov` endpoints) | [https://api.nasa.gov/](https://api.nasa.gov/) — fill the form, then use the generated **API Key** as `NASA_API_KEY`. |
| **Unsplash** (only if you add `unsplash` to `DAILY_WALLPAPER_SOURCES`) | [https://unsplash.com/oauth/applications](https://unsplash.com/oauth/applications) — create an app, then copy the **Access Key** as `UNSPLASH_ACCESS_KEY`. Follow [Unsplash API guidelines](https://unsplash.com/documentation#guidelines--sdks) (attribution, etc.). |

The **Met** and **NASA Image Library** sources use public APIs that do **not** require keys for the calls this script makes.

---

## Requirements

- **GNOME** with `gsettings`.
- **`bash`**, **`curl`**, **`jq`**, and **`shuf`** (usually present on Ubuntu; without `shuf`, a simple `awk` shuffle is used).

---

## Files and locations

| Piece | Path |
|--------|------|
| Script | `~/.local/bin/daily-wallpaper.sh` |
| Configuration | `~/.config/daily-wallpaper.env` |
| Template | `~/.config/daily-wallpaper.env.example` |
| Saved images | `~/Pictures/daily-wallpapers/` |
| Deck state (shuffled queue) | `~/.local/state/daily-wallpaper/queue.json` (or `$XDG_STATE_HOME/daily-wallpaper/queue.json`) |
| Systemd user service / timer | `~/.config/systemd/user/daily-wallpaper.service`, `daily-wallpaper.timer` |
| Shortcuts | `~/.local/share/applications/daily-wallpaper.desktop`, `~/Desktop/daily-wallpaper.desktop` |
| This doc | `~/daily-wallpaper/README.md` |

Saved files use the prefix **`wp-<source>-`**. Legacy **`bing-*`** files are included in retention cleanup.

---

## Quick start

1. Copy the template and set at least **`NASA_API_KEY`** if you keep **`apod`** in `DAILY_WALLPAPER_SOURCES`:

   ```bash
   cp ~/.config/daily-wallpaper.env.example ~/.config/daily-wallpaper.env
   ```

2. Edit `~/.config/daily-wallpaper.env` with your keys from the links above.

3. Run once:

   ```bash
   chmod +x ~/.local/bin/daily-wallpaper.sh
   ~/.local/bin/daily-wallpaper.sh
   ```

4. Daily timer (user session):

   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now daily-wallpaper.timer
   ```

---

## Configuration

### `DAILY_WALLPAPER_SOURCES`

Comma-separated list of source ids, for example:

`bing,apod,met,nasa_images`

- If **`apod`** is listed but **`NASA_API_KEY`** is missing or set to **`DEMO_KEY`**, `apod` is **skipped** (message on stderr).
- If **`unsplash`** is listed but **`UNSPLASH_ACCESS_KEY`** is unset, `unsplash` is skipped.

### `NASA_API_KEY`

Required for **`apod`**. Must **not** be `DEMO_KEY`. Get a key at [api.nasa.gov](https://api.nasa.gov/).

### `UNSPLASH_ACCESS_KEY`

Required only if **`unsplash`** is in `DAILY_WALLPAPER_SOURCES`. Register at [unsplash.com/oauth/applications](https://unsplash.com/oauth/applications).

### `MET_SEARCH_QUERY`

Free-text search string for the Met [`/search`](https://metmuseum.github.io/) call (`q=`). URL-encoded automatically. **Default:** `cars and engines`.

### `UNSPLASH_QUERY`

Keyword string passed to Unsplash [`GET /photos/random`](https://unsplash.com/documentation#get-a-random-photo) as `query=`. **Default:** `cars and engines`.

### Bing / NASA Images / retention

Same variables as before: **`BING_MKT`**, **`BING_IDX`**, **`BING_IMAGE_COUNT`**, **`NASA_WALLPAPER_*`**, **`DAILY_WALLPAPER_KEEP_DAYS`**. See `~/.config/daily-wallpaper.env.example`.

---

## How the deck works

1. On startup, the script reads **`queue.json`** field **`remaining`** (JSON array of source ids).
2. If **`remaining`** is empty, it builds the **eligible** list from `DAILY_WALLPAPER_SOURCES` (minus skipped ids), **shuffles** it, and saves it as **`remaining`**.
3. It tries **`remaining[0]`**, then **`remaining[1]`**, … until one source returns an image URL.
4. On success, it applies the wallpaper and **removes only the winning entry** from **`remaining`** (by index).
5. When **`remaining`** becomes `[]`, the next run performs a **full reshuffle** again.

To **reset** the cycle (e.g. after changing `DAILY_WALLPAPER_SOURCES`), delete `queue.json` or empty the `remaining` array.

---

## Scheduling and logs

```bash
systemctl --user start daily-wallpaper.service
journalctl --user -u daily-wallpaper.service -n 30 --no-pager
```

---

## Troubleshooting

| Issue | What to do |
|--------|------------|
| `skipping source "apod"` | Set a real **`NASA_API_KEY`** from [api.nasa.gov](https://api.nasa.gov/) (not `DEMO_KEY`), or remove `apod` from **`DAILY_WALLPAPER_SOURCES`**. |
| `skipping source "unsplash"` | Set **`UNSPLASH_ACCESS_KEY`** or remove `unsplash` from the list. |
| `all sources in current deck failed` | Network outage or upstream errors; fix connectivity and retry. |
| `gsettings` fails | Run under your graphical GNOME session (systemd user timer after login is fine). |

---

## Terms

Respect each provider’s terms: **Microsoft** (Bing), **NASA**, **The Metropolitan Museum of Art**, **Unsplash**, etc.
