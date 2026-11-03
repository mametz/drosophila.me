# Deploying to a new droplet with Dokku

Commands run on the **new droplet** unless a step says otherwise. Replace `NEW_IP`.

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

## 4. Import a test copy

Copy a dump from the old droplet to the new one, then restore it into a temporary database:

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

The import refuses to run on a database with data. To repeat it, destroy and recreate the database, which also removes the old link:

```bash
dokku postgres:unlink drosophila drosophila && dokku postgres:destroy drosophila
```

```bash
dokku postgres:create drosophila && dokku postgres:link drosophila drosophila
```

Check at `new.drosophila.me`: log in with a real account, open crosses and stocks, and scan a printed QR code after replacing the host.

## 5. Switch over

1. A day ahead, lower the DNS TTL for `drosophila.me`.
2. On the old droplet, stop the app so no new data arrives: `dokku ps:stop drosophila`.
3. Export and copy the final dump, as for the test copy. Delete it from the old droplet afterwards.
4. On the new droplet, recreate the database as in step 4, restore the final dump into a fresh `legacy` database and import.
5. Point DNS at `NEW_IP`.
6. On the new droplet, once DNS has changed:

```bash
dokku domains:set drosophila drosophila.me && dokku config:set drosophila APP_HOST=drosophila.me
```

```bash
dokku letsencrypt:enable drosophila
```

## 6. Afterwards

Remove the temporary database:

```bash
dokku postgres:unlink legacy drosophila && dokku postgres:destroy legacy
```

Set up backups:

```bash
dokku postgres:backup-schedule drosophila "0 3 * * *" your-backup-bucket
```

That also needs `dokku postgres:backup-auth`, with storage credentials. Don't remove `drosophila` from the old droplet until the new site has run well for a week or two.

## If it goes wrong

Before DNS has changed, restart the old app with `dokku ps:start drosophila` on the old droplet.

After DNS has changed, rolling back is much harder. The new site tells browsers to use only HTTPS and they remember that for up to two years, so visitors can't reach the old HTTP-only server until it has HTTPS too. Data entered on the new site after the switch won't be on the old one. Fix problems on the new site if you can, which is why the test on `new.drosophila.me` matters.
