# apptaztic.com

The Apptaztic website: a home page listing the games, and for every game a page, a privacy
policy and terms of service (Google Play requires a privacy policy URL). Plain static HTML and
one stylesheet, no build step. `app-ads.txt` at the site root authorises our AdMob account for
every game.

```
public/                 what the server publishes (the web root)
  index.html            home page; game cards go between the games:start/end markers
  app-ads.txt           AdMob authorised sellers (shared by all games)
  assets/site.css       the one stylesheet (PIXEL CONGA colours, Fredoka headings)
  pixelconga/           one folder per game: index.html, privacy/, terms/, icon.png, feature.png
templates/game/         the pages every game gets ({{PLACEHOLDERS}})
tools/new_game.py       adds or regenerates a game's pages from the templates
site.env                publisher name and support email used in every page
deploy/install.sh       installs or updates the site on the server (safe to re-run)
deploy/nginx-site.conf  the nginx server block it installs
```

## Add a game

```sh
python3 tools/new_game.py mygame "MY GAME" com.apptaztic.mygame \
  --tagline "One short line." --description "Two or three sentences for the game page." \
  --icon path/to/play_icon_512.png --feature path/to/feature_graphic_1024x500.png
```

This writes `public/mygame/` (page, privacy policy, terms) and adds a card to the home page.
The game's links are then:

- `https://apptaztic.com/mygame/privacy/` (Play Console > App content > Privacy policy, and the app)
- `https://apptaztic.com/mygame/terms/`

The privacy template assumes Google AdMob ads, a Remove ads purchase, local-only progress and
no accounts. If a game collects anything else (sign-in, analytics, cloud saves), edit its pages
before publishing. Re-running the command for an existing slug regenerates its pages from the
templates, so template fixes reach every game.

## Publish to the server

On the server (Ubuntu, nginx), as your normal user:

```sh
curl -fsSL https://raw.githubusercontent.com/apptaztic-droid/apptaztic-site/main/deploy/install.sh -o ~/apptaztic-install.sh
bash ~/apptaztic-install.sh
```

The first run adds `/etc/nginx/sites-available/apptaztic.com.conf` and `/var/www/apptaztic`,
checks the nginx configuration (undoing its own change if the check fails, so other sites are
never affected) and gets a Let's Encrypt certificate with certbot, which renews automatically.
`www.apptaztic.com` is included once its DNS record points at the server. Later runs only
publish the latest pages (and add www if it has started resolving). The repository must be
public for the server to download it.
