# drosophila.me

Stock and genetic cross management for *Drosophila melanogaster*: record crosses,
see the possible offspring, follow a cross through generations and keep a stock list.

Runs on Ruby 3.4, Rails 8 and PostgreSQL.

## Setup

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

Set `DATABASE_URL` if PostgreSQL isn't on the default local socket.

## Tests

```bash
bin/rails test
```

`test/genetics/golden.json` holds results recorded from the original Rails 4.2 app.
`test/genetics/golden_test.rb` replays them, so a failure there means the genetics
changed. If that is intended, say why in the commit.

Known genetics quirks are pinned in `test/genetics/genetics_test.rb`.

## Where things live

- `app/models/genotype.rb`, `cross_calculator.rb`, `punnett_square.rb`: the genetics, plain Ruby
- `app/models/cross_builder.rb`: sets up a cross and its progeny from the form
- `app/helpers/genotype_helper.rb`: turns genotypes into the TeX that MathJax draws

Short links such as `/<slug>` and `/<slug>/qr` are printed on labels as QR codes, so
those paths must keep working.

## Production

Needs `SECRET_KEY_BASE` and `DATABASE_URL`. HTTPS is required, because `force_ssl` is on.
Password reset emails need SMTP settings in `config/environments/production.rb`.
