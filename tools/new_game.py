#!/usr/bin/env python3
"""Adds a game to the site: its page, privacy policy and terms, plus a card on the home page.

    python3 tools/new_game.py pixelconga "PIXEL CONGA" com.apptaztic.pixelconga \
        --tagline "Tap. Shoot. Reveal." --description "..." \
        --icon path/to/play_icon_512.png --feature path/to/feature_graphic_1024x500.png

Re-running it for the same slug regenerates that game's pages from templates/game (so fixes to
the templates reach every game) without adding a second home page card. Shared values (publisher,
email) come from site.env. The privacy policy template assumes AdMob ads and a "Remove ads"
purchase: edit the generated pages if a game differs.
"""
import argparse
import datetime
import html
import pathlib
import re
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBLIC = ROOT / "public"
TEMPLATES = ROOT / "templates" / "game"


def site_env() -> dict:
    env = {}
    for line in (ROOT / "site.env").read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip()
    return env


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("slug", help="URL folder, lower case, e.g. pixelconga")
    parser.add_argument("name", help='Display name, e.g. "PIXEL CONGA"')
    parser.add_argument("package", help="Android applicationId, e.g. com.apptaztic.pixelconga")
    parser.add_argument("--tagline", required=True)
    parser.add_argument("--description", required=True)
    parser.add_argument("--icon", required=True, help="512x512 PNG (the Play Store icon)")
    parser.add_argument("--feature", required=True, help="1024x500 PNG (the Play feature graphic)")
    parser.add_argument("--updated", help="date shown on the legal pages (default: today)")
    args = parser.parse_args()

    if not re.fullmatch(r"[a-z0-9-]+", args.slug):
        raise SystemExit("slug must be lower case letters, digits and dashes")
    env = site_env()
    updated = args.updated or datetime.date.today().strftime("%-d %B %Y")
    values = {
        "NAME": args.name,
        "SLUG": args.slug,
        "PACKAGE": args.package,
        "TAGLINE": args.tagline,
        "DESCRIPTION": args.description,
        "UPDATED": updated,
        "YEAR": str(datetime.date.today().year),
        "PUBLISHER": env["PUBLISHER"],
        "EMAIL": env["EMAIL"],
    }

    def fill(text: str) -> str:
        def sub(m: re.Match) -> str:
            key = m.group(1)
            if key not in values:
                raise SystemExit(f"unknown placeholder {{{{{key}}}}}")
            return html.escape(values[key], quote=True)

        return re.sub(r"\{\{([A-Z]+)\}\}", sub, text)

    out = PUBLIC / args.slug
    for src in TEMPLATES.rglob("*.html"):
        dst = out / src.relative_to(TEMPLATES)
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(fill(src.read_text()))
    shutil.copyfile(args.icon, out / "icon.png")
    shutil.copyfile(args.feature, out / "feature.png")

    # Home page card, once per game.
    index = PUBLIC / "index.html"
    page = index.read_text()
    marker = f'data-game="{args.slug}"'
    if marker not in page:
        e = {k: html.escape(v, quote=True) for k, v in values.items()}
        card = (
            f'        <article class="card game-card" {marker}>\n'
            f'          <a href="/{e["SLUG"]}/"><img src="/{e["SLUG"]}/icon.png" alt="{e["NAME"]} icon" width="112" height="112"></a>\n'
            f'          <h3><a href="/{e["SLUG"]}/" style="color:inherit;text-decoration:none">{e["NAME"]}</a></h3>\n'
            f'          <p>{e["TAGLINE"]}</p>\n'
            f'          <a class="badge" href="https://play.google.com/store/apps/details?id={e["PACKAGE"]}">Google Play</a>\n'
            f'          <div class="links"><a href="/{e["SLUG"]}/privacy/">Privacy</a><a href="/{e["SLUG"]}/terms/">Terms</a></div>\n'
            f"        </article>\n"
        )
        end = "        <!-- games:end -->"
        if end not in page:
            raise SystemExit("public/index.html is missing the <!-- games:end --> marker")
        index.write_text(page.replace(end, card + end, 1))
    print(f"public/{args.slug}/ written (privacy, terms, page); home page card ok")


if __name__ == "__main__":
    main()
