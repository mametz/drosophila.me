# Deploying to a new droplet with Dokku

Commands run on the **new droplet** unless a step says otherwise. Replace `NEW_IP` and `OLD_IP`.

Don't delete the old droplet afterwards: it also hosts `aandd`.

## 1. Server

Create an Ubuntu LTS droplet with at least 1 GB of RAM. Add swap, because building Rails assets uses a lot of memory:

```bash
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

Install Dokku using the commands at https://dokku.com/docs/getting-started/installation/, then add the plugins:

```bash
dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
```

```bash
dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git letsencrypt
```

Allow only SSH, HTTP and HTTPS through the firewall:

```bash
ufw allow OpenSSH && ufw allow http && ufw allow https && ufw enable
```

## 2. App and database

```bash
dokku apps:create drosophila
```

```bash
dokku postgres:create drosophila && dokku postgres:link drosophila drosophila
```

Never run `postgres:expose` on this database.

Use a temporary name so you can test before moving DNS. Point `new.drosophila.me` at `NEW_IP` first:

```bash
dokku domains:set drosophila new.drosophila.me
```

Generate the secret on the droplet, so it never appears in chat or the repo:

```bash
dokku config:set --no-restart drosophila SECRET_KEY_BASE="$(openssl rand -hex 64)" APP_HOST=new.drosophila.me
```

Set mail too, or password reset emails will fail. DigitalOcean blocks the usual mail ports, so use port 2525, and allow the droplet's IP in the provider's settings if it restricts them. This reads the key without showing it or saving it in your shell history:

```bash
read -rs SMTP_PASSWORD
```

```bash
dokku config:set --no-restart drosophila SMTP_ADDRESS=smtp-relay.brevo.com SMTP_PORT=2525 SMTP_USERNAME=your-login SMTP_PASSWORD="$SMTP_PASSWORD" && unset SMTP_PASSWORD
```

## 3. First deploy

Dokku needs your Mac's public SSH key. On your Mac, print it:

```bash
cat ~/.ssh/id_ed25519.pub
```

Then on the droplet, replacing `PUBLIC_KEY` with that line:

```bash
echo "PUBLIC_KEY" | dokku ssh-keys:add admin
```

Back on your Mac, from this repository. Dokku deploys what is pushed to its `master` branch:

```bash
git remote add dokku dokku@NEW_IP:drosophila
```

```bash
git push dokku rails-8-rewrite:master
```

Then on the droplet:

```bash
dokku letsencrypt:set drosophila email you@example.com && dokku letsencrypt:enable drosophila
```

```bash
dokku letsencrypt:cron-job --add
```

Dokku's nginx sets its own HTTPS rule for browsers. Keep it short for now, to match the app, so a return to the old server stays possible during the first weeks:

```bash
dokku nginx:set drosophila hsts-max-age 3600 && dokku nginx:set drosophila hsts-include-subdomains false
```

```bash
dokku proxy:build-config drosophila
```

Check the result. Each `strict-transport-security` line should say `max-age=3600`:

```bash
curl -sI https://new.drosophila.me/ | grep -i strict-transport
```

## 4. Import a test copy

On the old droplet, export the database:

```bash
dokku postgres:export drosophila > /root/drosophila.dump
```

On your Mac, copy it down and up to the new droplet, then delete it from the old one with `rm /root/drosophila.dump`:

```bash
scp root@OLD_IP:/root/drosophila.dump ~/drosophila-data/
```

```bash
scp ~/drosophila-data/drosophila.dump root@NEW_IP:/root/
```

On the new droplet, restore it into a temporary database:

```bash
dokku postgres:create legacy
```

```bash
dokku postgres:import legacy < /root/drosophila.dump
```

An error about `schema "public" already exists` is expected and harmless.

Link it and try the import. This adds `LEGACY_DATABASE_URL`:

```bash
dokku postgres:link legacy drosophila --alias LEGACY_DATABASE
```

```bash
dokku run drosophila env DRY_RUN=1 bin/rails legacy:import
```

```bash
dokku run drosophila bin/rails legacy:import
```

The import leaves out accounts that never created a cross, stock or room. Those people can sign up again. Keep the dump until you're sure nothing else is needed from it.

The import refuses to run on a database with data. To repeat it, start both databases from scratch. Each `destroy` asks you to type the name:

```bash
dokku postgres:unlink legacy drosophila && dokku postgres:destroy legacy
```

```bash
dokku postgres:unlink drosophila drosophila && dokku postgres:destroy drosophila
```

```bash
dokku postgres:create drosophila && dokku postgres:link drosophila drosophila
```

```bash
dokku postgres:create legacy && dokku postgres:import legacy < /root/drosophila.dump && dokku postgres:link legacy drosophila --alias LEGACY_DATABASE
```

Then rebuild the app. The new databases get new passwords, and the restarts that `postgres:link` triggers don't reliably pass them on: the app keeps the old ones and every command fails with `password authentication failed`. The rebuild also runs `db:migrate`, which creates the empty tables:

```bash
dokku ps:rebuild drosophila
```

Check that the app has the new passwords. They should match the `Dsn` lines `postgres:create` printed:

```bash
dokku run drosophila printenv DATABASE_URL LEGACY_DATABASE_URL
```

Then run the dry run and the import as above.

`dokku run` passes its arguments through a shell without their quotes, so commands with quotes or brackets, such as `bin/rails runner '...'`, break. Stick to plain commands. Its output also hangs when piped.

Check at `new.drosophila.me`: log in with a real account, open crosses and stocks, and scan a printed QR code after replacing the host.

## 5. Switch over

1. A day ahead, lower the DNS TTL for `drosophila.me`.
2. On the old droplet, stop the app so no new data arrives: `dokku ps:stop drosophila`.
3. Export and copy the final dump, as for the test copy. Delete it from the old droplet afterwards.
4. On the new droplet, start both databases from scratch with the final dump, rebuild, check the passwords and import, all as in step 4. Log in and check your own crosses before moving on.
5. Point DNS at `NEW_IP`. Check from your Mac with `dig +short drosophila.me @1.1.1.1`.
6. On the new droplet, once DNS has changed:

```bash
dokku domains:set drosophila drosophila.me www.drosophila.me && dokku config:set drosophila APP_HOST=drosophila.me
```

```bash
dokku letsencrypt:enable drosophila
```

## 6. Afterwards

Remove the temporary database:

```bash
dokku postgres:unlink legacy drosophila && dokku postgres:destroy legacy
```

Keep the final dump files (`/root/drosophila.dump` and the copy on your Mac) as the record of the old site.

### Backups

A nightly job writes a dump to the droplet's disk and keeps 14. DigitalOcean's daily droplet backups, with the window set to 05:00–09:00 CET, copy it off the server. The dump has to finish before that window opens, so it runs at 01:15 UTC.

```bash
mkdir -p /var/backups/drosophila && chmod 700 /var/backups/drosophila
```

```bash
cat > /etc/cron.d/drosophila-dump <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
15 1 * * * root f=/var/backups/drosophila/drosophila-$(date +\%F).dump; dokku postgres:export drosophila > $f.tmp 2>>/var/log/drosophila-dump.log && mv $f.tmp $f && find /var/backups/drosophila -name '*.dump' -mtime +14 -delete
EOF
```

Check that a dump is complete. It should show 8 tables, the app's 6 plus Rails' 2:

```bash
docker exec -i dokku.postgres.drosophila pg_restore --list < /var/backups/drosophila/drosophila-YYYY-MM-DD.dump | grep -c "TABLE DATA"
```

Errors from the nightly job go to `/var/log/drosophila-dump.log`. Test a full restore into a scratch database once, because a backup you haven't restored isn't proven.

Once you're sure you won't go back to the old server, raise the HTTPS rule to a year: `expires` in `config/environments/production.rb` and `dokku nginx:set drosophila hsts-max-age 31536000`, then rebuild and deploy. Don't remove `drosophila` from the old droplet until the new site has run well for a week or two.

## If it goes wrong

Before DNS has changed, restart the old app with `dokku ps:start drosophila` on the old droplet.

After DNS has changed, point DNS back as well. The new site tells browsers to use only HTTPS, but while that rule is set to one hour, visitors can reach the old HTTP-only server again soon after. Data entered on the new site after the switch won't be on the old one. Fix problems on the new site if you can, which is why the test on `new.drosophila.me` matters.
