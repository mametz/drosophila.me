namespace :legacy do
  desc "Copy a restored old-app database into this one. Needs LEGACY_DATABASE_URL; DRY_RUN=1 saves nothing."
  task import: :environment do
    url = ENV.fetch("LEGACY_DATABASE_URL") { abort "Set LEGACY_DATABASE_URL to the restored old database." }
    LegacyImport.connect(url).run(dry_run: ENV["DRY_RUN"].present?)
  end
end
