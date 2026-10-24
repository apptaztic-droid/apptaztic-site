#!/usr/bin/env bash
# Installs or updates apptaztic.com on this server. Safe to run again at any time:
# the first run sets up nginx and HTTPS, later runs only publish the latest pages.
#
#   bash install.sh
#
# It adds one nginx file (sites-available/apptaztic.com.conf) and one web folder
# (/var/www/apptaztic). It never edits other sites' files, and it checks the nginx
# configuration before every reload, undoing its own change if the check fails.
set -euo pipefail

REPO="apptaztic-droid/apptaztic-site"
BRANCH="main"
DOMAIN="apptaztic.com"
EMAIL="support@apptaztic.com"
WEBROOT="/var/www/apptaztic"
CONF="/etc/nginx/sites-available/${DOMAIN}.conf"
LINK="/etc/nginx/sites-enabled/${DOMAIN}.conf"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

say "1/4 Downloading the latest site from GitHub"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if ! curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz" -o "$tmp/site.tar.gz"; then
  echo "Could not download ${REPO}. Is the repository public? Nothing was changed."
  exit 1
fi
tar -xzf "$tmp/site.tar.gz" -C "$tmp"
src="$tmp/apptaztic-site-${BRANCH}"
if [ ! -f "$src/public/index.html" ] || [ ! -f "$src/deploy/nginx-site.conf" ]; then
  echo "The download does not look like the site. Nothing was changed."
  exit 1
fi

say "2/4 Publishing the pages to ${WEBROOT}"
sudo rm -rf "${WEBROOT}.new" "${WEBROOT}.old"
sudo cp -r "$src/public" "${WEBROOT}.new"
sudo chown -R root:root "${WEBROOT}.new"
sudo find "${WEBROOT}.new" -type d -exec chmod 755 {} +
sudo find "${WEBROOT}.new" -type f -exec chmod 644 {} +
if [ -d "$WEBROOT" ]; then sudo mv "$WEBROOT" "${WEBROOT}.old"; fi
sudo mv "${WEBROOT}.new" "$WEBROOT"
sudo rm -rf "${WEBROOT}.old"
echo "Done."

# www is included once its DNS record points at the same server as the main name.
names="$DOMAIN"
apex_ip="$(dig +short "$DOMAIN" A | tail -n1)"
www_ip="$(dig +short "www.${DOMAIN}" A | tail -n1)"
if [ -n "$www_ip" ] && [ "$www_ip" = "$apex_ip" ]; then
  names="$DOMAIN www.${DOMAIN}"
else
  echo "Note: www.${DOMAIN} does not point here yet, so only ${DOMAIN} is set up."
  echo "      Add the DNS record and run this script again to add www."
fi

say "3/4 nginx"
if [ ! -f "$CONF" ]; then
  sed "s/__SERVER_NAMES__/${names}/" "$src/deploy/nginx-site.conf" | sudo tee "$CONF" >/dev/null
  sudo ln -sf "$CONF" "$LINK"
  if ! sudo nginx -t; then
    sudo rm -f "$LINK" "$CONF"
    echo "nginx rejected the new file, so it was removed again. Your other sites are untouched."
    exit 1
  fi
  sudo systemctl reload nginx
  echo "Added ${CONF} for: ${names}"
elif [[ "$names" == *"www."* ]] && ! sudo grep -q "www\.${DOMAIN}" "$CONF"; then
  sudo cp "$CONF" "$tmp/conf.backup"
  sudo sed -i -E "s/server_name[[:space:]]+${DOMAIN//./\\.};/server_name ${names};/" "$CONF"
  if ! sudo nginx -t; then
    sudo cp "$tmp/conf.backup" "$CONF"
    echo "nginx rejected the www change, so it was undone. Your sites are untouched."
    exit 1
  fi
  sudo systemctl reload nginx
  echo "Added www.${DOMAIN} to ${CONF}"
else
  echo "${CONF} already in place, left as it is."
fi

say "4/4 HTTPS certificate (Let's Encrypt)"
domains=()
for n in $names; do domains+=(-d "$n"); done
sudo certbot --nginx --cert-name "$DOMAIN" "${domains[@]}" \
  --non-interactive --agree-tos -m "$EMAIL" --no-eff-email \
  --redirect --keep-until-expiring --expand
if ! sudo nginx -t; then
  echo "nginx check failed after certbot. Run: sudo nginx -t   and send me the output."
  exit 1
fi
sudo systemctl reload nginx

say "All done. Check these open in your browser:"
for n in $names; do echo "  https://${n}/"; done
echo "  https://${DOMAIN}/pixelconga/privacy/"
echo "  https://${DOMAIN}/app-ads.txt"
