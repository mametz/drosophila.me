# Everything the admin stats page shows. Counts only: no email addresses leave
# this class, accounts are shown by id and email domain.
#
# History comes from the dates on crosses, stocks, rooms and logins, which the
# import kept from the old site. Daily visits and page use are only counted
# from the day UsageTracking went live.
class UsageStats
  UNITS = %w[day week month year].freeze

  # Anything an account did, with when it happened.
  EVENTS = <<~SQL.squish
    SELECT user_id, created_at AS at, 'cross' AS kind FROM crosses
    UNION ALL SELECT user_id, updated_at, 'cross_edit' FROM crosses WHERE updated_at > created_at + interval '1 minute'
    UNION ALL SELECT user_id, created_at, 'stock' FROM stocks
    UNION ALL SELECT user_id, updated_at, 'stock_edit' FROM stocks WHERE updated_at > created_at + interval '1 minute'
    UNION ALL SELECT user_id, created_at, 'room' FROM rooms
    UNION ALL SELECT user_id, created_at, 'login' FROM sessions
    UNION ALL SELECT user_id, day::timestamp, 'visit' FROM activity_days
  SQL

  # Visits have no time of day, so they're left out wherever the hour matters.
  TIMED_EVENTS = "SELECT * FROM (#{EVENTS}) all_events WHERE kind <> 'visit'".freeze

  PERSONAL_DOMAINS = %w[
    gmail.com googlemail.com yahoo.com yahoo.co.uk yahoo.fr yahoo.de hotmail.com hotmail.fr hotmail.de outlook.com
    live.com msn.com icloud.com me.com mac.com aol.com protonmail.com proton.me gmx.de gmx.net gmx.ch web.de
    qq.com 163.com 126.com sina.com naver.com mail.ru yandex.ru
  ].freeze

  COUNTRIES = {
    "edu" => "United States", "gov" => "United States", "us" => "United States", "uk" => "United Kingdom",
    "de" => "Germany", "fr" => "France", "ch" => "Switzerland", "at" => "Austria", "it" => "Italy", "es" => "Spain",
    "pt" => "Portugal", "nl" => "Netherlands", "be" => "Belgium", "lu" => "Luxembourg", "dk" => "Denmark",
    "se" => "Sweden", "no" => "Norway", "fi" => "Finland", "is" => "Iceland", "ie" => "Ireland", "pl" => "Poland",
    "cz" => "Czechia", "sk" => "Slovakia", "hu" => "Hungary", "ro" => "Romania", "bg" => "Bulgaria", "gr" => "Greece",
    "hr" => "Croatia", "si" => "Slovenia", "rs" => "Serbia", "ee" => "Estonia", "lv" => "Latvia", "lt" => "Lithuania",
    "ua" => "Ukraine", "ru" => "Russia", "tr" => "Turkey", "il" => "Israel", "eg" => "Egypt", "za" => "South Africa",
    "ng" => "Nigeria", "ke" => "Kenya", "ma" => "Morocco", "sa" => "Saudi Arabia", "ae" => "United Arab Emirates",
    "ir" => "Iran", "in" => "India", "pk" => "Pakistan", "bd" => "Bangladesh", "cn" => "China", "hk" => "Hong Kong",
    "tw" => "Taiwan", "jp" => "Japan", "kr" => "South Korea", "sg" => "Singapore", "my" => "Malaysia",
    "th" => "Thailand", "vn" => "Vietnam", "id" => "Indonesia", "ph" => "Philippines", "au" => "Australia",
    "nz" => "New Zealand", "ca" => "Canada", "mx" => "Mexico", "br" => "Brazil", "ar" => "Argentina", "cl" => "Chile",
    "co" => "Colombia", "pe" => "Peru", "uy" => "Uruguay", "ve" => "Venezuela", "cu" => "Cuba"
  }.freeze

  PAGE_NAMES = {
    "static_pages#home" => "Home page", "static_pages#team" => "Team page",
    "crosses#index" => "Cross list", "crosses#new" => "New cross form", "crosses#create" => "Cross created",
    "crosses#update" => "Cross edited", "crosses#destroy" => "Cross deleted", "crosses#copy" => "Cross copied",
    "crosses#show" => "Cross page", "crosses#history" => "Lineage history", "crosses#qr" => "QR label",
    "crosses#chromosome" => "Chromosome view", "crosses#recombinants" => "Recombinants", "crosses#punnett" => "Punnett square",
    "stocks#index" => "Stock list", "stocks#index.csv" => "Stock list download", "stocks#show" => "Stock page",
    "stocks#new" => "New stock form", "stocks#create" => "Stock created", "stocks#edit" => "Stock edit form",
    "stocks#update" => "Stock edited", "stocks#destroy" => "Stock deleted", "stocks#from_fly" => "Stock from a fly",
    "rooms#index" => "Room list", "rooms#create" => "Room created", "rooms#update" => "Room edited",
    "rooms#destroy" => "Room deleted", "sessions#new" => "Login form", "sessions#create" => "Login",
    "sessions#destroy" => "Logout", "registrations#new" => "Sign-up form", "registrations#create" => "Sign-up",
    "accounts#edit" => "Profile", "accounts#update" => "Profile changed", "accounts#destroy" => "Account deleted",
    "passwords#new" => "Password reset form", "passwords#create" => "Password reset requested",
    "passwords#edit" => "New password form", "passwords#update" => "Password reset"
  }.freeze

  attr_reader :now, :today

  def initialize(now: Time.current)
    @now = now
    @today = now.to_date
  end

  # Headline numbers, each with the same count for the period before.
  def overview
    {
      accounts: User.count,
      accounts_with_data: value(<<~SQL.squish).to_i,
        SELECT count(*) FROM users WHERE EXISTS (SELECT 1 FROM crosses WHERE user_id = users.id)
          OR EXISTS (SELECT 1 FROM stocks WHERE user_id = users.id) OR EXISTS (SELECT 1 FROM rooms WHERE user_id = users.id)
      SQL
      active_7: compare { |from, to| active_users(from, to) }.call(7),
      active_30: compare { |from, to| active_users(from, to) }.call(30),
      active_365: compare { |from, to| active_users(from, to) }.call(365),
      new_accounts_30: compare { |from, to| User.where(created_at: from...to).count }.call(30),
      crosses_30: compare { |from, to| Cross.where(created_at: from...to).count }.call(30),
      stocks_30: compare { |from, to| Stock.where(created_at: from...to).count }.call(30),
      crosses: Cross.count,
      stocks: Stock.count,
      rooms: Room.count,
      first_signup: User.minimum(:created_at)
    }
  end

  # Daily active accounts, based on visits counted since tracking began.
  def engagement
    days = 28
    from = today - (days - 1)
    daily = rows("SELECT day, count(*) AS n, sum(requests) AS r FROM activity_days WHERE day >= ? GROUP BY day", from)
    mau = value("SELECT count(DISTINCT user_id) FROM activity_days WHERE day >= ?", from).to_i
    avg_dau = daily.sum { |row| row["n"].to_i } / days.to_f
    {
      tracking_since: ActivityDay.minimum(:day),
      dau_today: ActivityDay.where(day: today).count,
      avg_dau: avg_dau.round(1),
      mau: mau,
      stickiness: mau.zero? ? nil : avg_dau / mau,
      requests_per_visit: daily.sum { |row| row["n"].to_i }.zero? ? nil : (daily.sum { |row| row["r"].to_i } / daily.sum { |row| row["n"].to_i }.to_f).round(1),
      visit_days_per_account: value(<<~SQL.squish, from).to_f.round(1)
        SELECT avg(n) FROM (SELECT count(*) AS n FROM activity_days WHERE day >= ? GROUP BY user_id) per_user
      SQL
    }
  end

  def monthly_growth
    from = (User.minimum(:created_at) || now).beginning_of_month
    {
      accounts: bucketed("SELECT id AS user_id, created_at AS at FROM users", "month", from),
      crosses: bucketed("SELECT user_id, created_at AS at FROM crosses", "month", from),
      stocks: bucketed("SELECT user_id, created_at AS at FROM stocks", "month", from),
      active: bucketed(EVENTS, "month", from, distinct_users: true)
    }
  end

  def cumulative_accounts
    total = 0
    monthly_growth_accounts.map { |period, n| [ period, total += n ] }
  end

  def recent_activity
    from = today - 89
    {
      active: bucketed(EVENTS, "day", from, distinct_users: true),
      crosses: bucketed("SELECT user_id, created_at AS at FROM crosses", "day", from),
      stocks: bucketed("SELECT user_id, created_at AS at FROM stocks", "day", from),
      weekly_active: bucketed(EVENTS, "week", today.beginning_of_week - 51.weeks, distinct_users: true)
    }
  end

  def years
    rows(<<~SQL.squish)
      WITH events AS (#{EVENTS}),
      years AS (SELECT generate_series(extract(year FROM (SELECT min(created_at) FROM users))::int, extract(year FROM now())::int) AS year)
      SELECT year,
        (SELECT count(*) FROM users WHERE extract(year FROM created_at) = year) AS accounts,
        (SELECT count(DISTINCT user_id) FROM events WHERE extract(year FROM at) = year) AS active,
        (SELECT count(*) FROM crosses WHERE extract(year FROM created_at) = year) AS crosses,
        (SELECT count(*) FROM stocks WHERE extract(year FROM created_at) = year) AS stocks
      FROM years ORDER BY year DESC
    SQL
  end

  # Share of each sign-up group that was active again 0, 1, 2… periods later.
  def cohorts(unit, limit)
    raise ArgumentError, unit unless %w[month year].include?(unit)

    step = unit == "year" ? "12" : "1"
    data = rows(<<~SQL.squish, limit)
      WITH events AS (#{EVENTS}),
      cohort AS (
        SELECT id, date_trunc('#{unit}', created_at) AS start FROM users
        WHERE date_trunc('#{unit}', created_at) > date_trunc('#{unit}', now()) - (? * interval '1 #{unit}')
      ),
      offsets AS (
        SELECT cohort.start, cohort.id,
          floor((extract(year FROM age(date_trunc('#{unit}', e.at), cohort.start)) * 12
            + extract(month FROM age(date_trunc('#{unit}', e.at), cohort.start))) / #{step})::int AS k
        FROM cohort JOIN events e ON e.user_id = cohort.id AND e.at >= cohort.start
      )
      SELECT to_char(c.start, 'YYYY-MM-DD') AS start, c.size, o.k, o.n FROM
        (SELECT start, count(*) AS size FROM cohort GROUP BY start) c
        LEFT JOIN (SELECT start, k, count(DISTINCT id) AS n FROM offsets GROUP BY start, k) o ON o.start = c.start
      ORDER BY c.start DESC, o.k
    SQL
    data.group_by { |row| row["start"] }.map do |start, cells|
      size = cells.first["size"].to_i
      shares = cells.select { |row| row["k"] }.to_h { |row| [ row["k"].to_i, row["n"].to_f / size ] }
      { start: Date.parse(start), size: size, shares: shares }
    end
  end

  # New accounts in the last 180 days that added a cross or stock within a week.
  def activation
    row = rows(<<~SQL.squish, now - 180.days).first
      WITH recent AS (SELECT id, created_at FROM users WHERE created_at >= ?),
      first_work AS (
        SELECT recent.id, recent.created_at,
          (SELECT min(at) FROM (SELECT created_at AS at FROM crosses WHERE user_id = recent.id
                                UNION ALL SELECT created_at FROM stocks WHERE user_id = recent.id) w) AS first_at
        FROM recent
      )
      SELECT count(*) AS accounts,
        count(*) FILTER (WHERE first_at IS NOT NULL) AS ever,
        count(*) FILTER (WHERE first_at <= created_at + interval '7 days') AS week,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY greatest(extract(epoch FROM first_at - created_at), 0) / 3600) AS median_hours
      FROM first_work
    SQL
    row.transform_keys(&:to_sym)
  end

  def lifecycle
    rows(<<~SQL.squish, now - 30.days, now - 30.days, now - 90.days, now - 365.days).to_h { |row| [ row["stage"], row["n"].to_i ] }
      WITH last AS (SELECT user_id, max(at) AS at FROM (#{EVENTS}) e GROUP BY user_id)
      SELECT CASE
        WHEN users.created_at >= ? THEN 'new'
        WHEN last.at IS NULL THEN 'never'
        WHEN last.at >= ? THEN 'active'
        WHEN last.at >= ? THEN 'cooling'
        WHEN last.at >= ? THEN 'dormant'
        ELSE 'lapsed' END AS stage, count(*) AS n
      FROM users LEFT JOIN last ON last.user_id = users.id GROUP BY stage
    SQL
  end

  def size_buckets(table)
    raise ArgumentError, table unless %w[crosses stocks].include?(table)

    order = [ "0", "1", "2–5", "6–20", "21–100", "101–500", "500+" ]
    counts = rows(<<~SQL.squish).to_h { |row| [ row["bucket"], row["n"].to_i ] }
      SELECT CASE WHEN n = 0 THEN '0' WHEN n = 1 THEN '1' WHEN n <= 5 THEN '2–5' WHEN n <= 20 THEN '6–20'
        WHEN n <= 100 THEN '21–100' WHEN n <= 500 THEN '101–500' ELSE '500+' END AS bucket, count(*) AS n
      FROM (SELECT users.id, count(t.id) AS n FROM users LEFT JOIN #{table} t ON t.user_id = users.id GROUP BY users.id) per_user
      GROUP BY bucket
    SQL
    order.map { |bucket| [ bucket, counts.fetch(bucket, 0) ] }
  end

  def top_accounts(limit = 15)
    rows(<<~SQL.squish, now - 90.days, limit)
      WITH recent AS (SELECT user_id, kind FROM (#{EVENTS}) e WHERE at >= ?),
      ranked AS (SELECT user_id, count(*) AS actions,
          count(*) FILTER (WHERE kind = 'cross') AS new_crosses,
          count(*) FILTER (WHERE kind = 'stock') AS new_stocks
        FROM recent GROUP BY user_id ORDER BY actions DESC LIMIT ?)
      SELECT ranked.*, split_part(users.email_address, '@', 2) AS domain, users.created_at,
        (SELECT count(*) FROM crosses WHERE user_id = users.id) AS crosses,
        (SELECT count(*) FROM stocks WHERE user_id = users.id) AS stocks,
        (SELECT max(at) FROM (#{EVENTS}) e WHERE e.user_id = users.id) AS last_at
      FROM ranked JOIN users ON users.id = ranked.user_id ORDER BY actions DESC
    SQL
  end

  def domains(limit = 25)
    rows(<<~SQL.squish, now - 90.days, limit)
      WITH active AS (SELECT DISTINCT user_id FROM (#{EVENTS}) e WHERE at >= ?),
      per_user AS (SELECT user_id, count(*) AS n FROM crosses GROUP BY user_id)
      SELECT split_part(email_address, '@', 2) AS domain, count(*) AS accounts,
        count(active.user_id) AS active, coalesce(sum(per_user.n), 0) AS crosses
      FROM users LEFT JOIN active ON active.user_id = users.id LEFT JOIN per_user ON per_user.user_id = users.id
      GROUP BY domain ORDER BY accounts DESC, domain LIMIT ?
    SQL
  end

  # A guess from the email address ending; personal addresses can't be placed.
  def countries
    active = active_user_ids(now - 90.days)
    User.pluck(:id, :email_address).group_by { |_id, email| country_for(email) }
        .map { |country, users| { country: country, accounts: users.size, active: users.count { |id, _| active.include?(id) } } }
        .sort_by { |row| [ -row[:accounts], row[:country] ] }
  end

  def personal_email_share
    total = User.count
    return nil if total.zero?

    User.pluck(:email_address).count { |email| PERSONAL_DOMAINS.include?(email.split("@").last) } / total.to_f
  end

  # Actions by weekday (1 = Monday) and hour, in UTC, over the last year.
  def heatmap
    counts = rows(<<~SQL.squish, now - 365.days).to_h { |row| [ [ row["dow"].to_i, row["hour"].to_i ], row["n"].to_i ] }
      SELECT extract(isodow FROM at) AS dow, extract(hour FROM at) AS hour, count(*) AS n
      FROM (#{TIMED_EVENTS}) e WHERE at >= ? GROUP BY dow, hour
    SQL
    { counts: counts, max: counts.values.max || 0 }
  end

  def weekday_split
    rows(<<~SQL.squish, now - 365.days).to_h { |row| [ row["dow"].to_i, row["n"].to_i ] }
      SELECT extract(isodow FROM at) AS dow, count(*) AS n FROM (#{TIMED_EVENTS}) e WHERE at >= ? GROUP BY dow
    SQL
  end

  def cross_features
    rows(<<~SQL.squish).first.transform_keys(&:to_sym)
      SELECT count(*) AS total,
        count(*) FILTER (WHERE NOT shared) AS private,
        count(*) FILTER (WHERE parent_id IS NOT NULL) AS with_parent,
        count(*) FILTER (WHERE balancers <> '') AS with_balancers,
        count(*) FILTER (WHERE lethal <> '') AS with_lethal,
        count(*) FILTER (WHERE coalesce(description, '') <> '') AS with_description,
        (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY n) FROM (SELECT count(*) AS n FROM flies WHERE cross_id IS NOT NULL GROUP BY cross_id) f) AS median_flies,
        (SELECT round(avg(n), 1) FROM (SELECT count(*) AS n FROM flies WHERE cross_id IS NOT NULL GROUP BY cross_id) f) AS mean_flies,
        (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY created_at::date - crossdate) FROM crosses) AS median_entry_delay
      FROM crosses
    SQL
  end

  # How many generations each family of crosses runs to.
  def generations
    order = %w[1 2 3 4 5 6–10 11+]
    counts = rows(<<~SQL.squish, Cross::MAX_GENERATIONS).to_h { |row| [ row["bucket"], row["n"].to_i ] }
      WITH RECURSIVE tree AS (
        SELECT id, id AS root, 1 AS depth FROM crosses WHERE parent_id IS NULL
        UNION ALL
        SELECT crosses.id, tree.root, tree.depth + 1 FROM crosses JOIN tree ON crosses.parent_id = tree.id WHERE tree.depth < ?
      )
      SELECT CASE WHEN d <= 5 THEN d::text WHEN d <= 10 THEN '6–10' ELSE '11+' END AS bucket, count(*) AS n
      FROM (SELECT root, max(depth) AS d FROM tree GROUP BY root) families GROUP BY bucket
    SQL
    order.map { |bucket| [ bucket, counts.fetch(bucket, 0) ] }
  end

  def top_list_entries(column, limit = 15)
    raise ArgumentError, column unless %w[balancers lethal].include?(column)

    rows(<<~SQL.squish, limit)
      SELECT trim(entry) AS name, count(*) AS uses, count(DISTINCT user_id) AS accounts
      FROM crosses, unnest(string_to_array(#{column}, ';')) AS entry
      WHERE trim(entry) <> '' GROUP BY trim(entry) ORDER BY uses DESC, name LIMIT ?
    SQL
  end

  def stock_sources(limit = 15)
    rows(<<~SQL.squish, limit)
      SELECT min(trim(received_from)) AS name, count(*) AS stocks, count(DISTINCT user_id) AS accounts
      FROM stocks WHERE trim(coalesce(received_from, '')) <> ''
      GROUP BY lower(trim(received_from)) ORDER BY stocks DESC, name LIMIT ?
    SQL
  end

  def stock_features
    rows(<<~SQL.squish).first.transform_keys(&:to_sym)
      SELECT count(*) AS total,
        count(*) FILTER (WHERE room_id IS NOT NULL) AS with_room,
        count(*) FILTER (WHERE coalesce(name, '') <> '') AS with_name,
        count(*) FILTER (WHERE coalesce(comment, '') <> '') AS with_comment,
        count(*) FILTER (WHERE coalesce(reference, '') <> '') AS with_reference,
        count(*) FILTER (WHERE coalesce(received_from, '') <> '') AS with_source,
        count(*) FILTER (WHERE date_established IS NOT NULL) AS with_date,
        (SELECT count(DISTINCT user_id) FROM rooms) AS accounts_with_rooms
      FROM stocks
    SQL
  end

  def room_temperatures
    rows(<<~SQL.squish).map { |row| [ row["temperature"] ? "#{row["temperature"]} °C" : "Not set", row["n"].to_i ] }
      SELECT temperature, count(*) AS n FROM rooms GROUP BY temperature ORDER BY temperature NULLS LAST
    SQL
  end

  def pages
    since = PageView.minimum(:day)
    totals = rows(<<~SQL.squish, today - 6, today - 29, today - 29)
      SELECT page,
        sum(views) FILTER (WHERE day >= ?) AS week,
        sum(views) FILTER (WHERE day >= ?) AS month,
        sum(views) FILTER (WHERE day >= ? AND NOT signed_in) AS month_out,
        sum(views) AS total
      FROM page_views GROUP BY page ORDER BY month DESC NULLS LAST, total DESC
    SQL
    {
      since: since,
      rows: totals.map { |row| row.merge("name" => PAGE_NAMES.fetch(row["page"], row["page"])) },
      signed_in: daily_views(true),
      signed_out: daily_views(false)
    }
  end

  # Browsers and devices from logins since the switch to the new site.
  def devices
    agents = Session.pluck(:user_id, :user_agent)
    {
      logins: agents.size,
      device: tally(agents) { |agent| device_for(agent) },
      browser: tally(agents) { |agent| browser_for(agent) },
      os: tally(agents) { |agent| os_for(agent) },
      weekly_logins: bucketed("SELECT user_id, created_at AS at FROM sessions", "week", today.beginning_of_week - 25.weeks)
    }
  end

  def system
    {
      database_size: value("SELECT pg_database_size(current_database())").to_i,
      tables: { "Accounts" => User.count, "Crosses" => Cross.count, "Flies" => Fly.count, "Stocks" => Stock.count,
                "Rooms" => Room.count, "Logins" => Session.count, "Activity days" => ActivityDay.count,
                "Page counters" => PageView.count }
    }
  end

  def self.page_name(page) = PAGE_NAMES.fetch(page, page)

  def country_for(email)
    domain = email.to_s.split("@").last.to_s.downcase
    return "Personal email" if PERSONAL_DOMAINS.include?(domain)

    tld = domain.split(".").last
    COUNTRIES[tld] || (%w[com org net info io].include?(tld) ? "International (.#{tld})" : ".#{tld}")
  end

  def device_for(agent)
    case agent.to_s
    when "" then "Unknown"
    when /iPad|Tablet|Android(?!.*Mobile)/ then "Tablet"
    when /Mobi|iPhone|Android/ then "Phone"
    else "Computer"
    end
  end

  def browser_for(agent)
    case agent.to_s
    when "" then "Unknown"
    when /Edg\// then "Edge"
    when /OPR\/|Opera/ then "Opera"
    when /Firefox|FxiOS/ then "Firefox"
    when /SamsungBrowser/ then "Samsung Internet"
    when /Chrome|CriOS|Chromium/ then "Chrome"
    when /Safari/ then "Safari"
    else "Other"
    end
  end

  def os_for(agent)
    case agent.to_s
    when "" then "Unknown"
    when /iPhone|iPad|iPod/ then "iOS"
    when /Android/ then "Android"
    when /CrOS/ then "ChromeOS"
    when /Windows/ then "Windows"
    when /Mac OS X|Macintosh/ then "macOS"
    when /Linux/ then "Linux"
    else "Other"
    end
  end

  private

  def connection = ApplicationRecord.connection

  def rows(sql, *binds)
    connection.select_all(ApplicationRecord.sanitize_sql_array([ sql, *binds ])).to_a
  end

  def value(sql, *binds)
    connection.select_value(ApplicationRecord.sanitize_sql_array([ sql, *binds ]))
  end

  def active_users(from, to)
    value("SELECT count(DISTINCT user_id) FROM (#{EVENTS}) e WHERE at >= ? AND at < ?", from, to).to_i
  end

  def active_user_ids(from)
    connection.select_values(ApplicationRecord.sanitize_sql_array([ "SELECT DISTINCT user_id FROM (#{EVENTS}) e WHERE at >= ?", from ])).map(&:to_i).to_set
  end

  # Returns a lambda giving { current:, previous: } for the last n days and the n days before.
  def compare(&count)
    ->(days) { { current: count.call(now - days.days, now), previous: count.call(now - (2 * days).days, now - days.days) } }
  end

  # [[Date, count], ...] with a row for every period, empty ones included.
  def bucketed(source, unit, from, distinct_users: false)
    raise ArgumentError, unit unless UNITS.include?(unit)

    measure = distinct_users ? "count(DISTINCT t.user_id)" : "count(t.at)"
    rows(<<~SQL.squish, from, now, from).map { |row| [ Date.parse(row["period"]), row["n"].to_i ] }
      SELECT to_char(g, 'YYYY-MM-DD') AS period, #{measure} AS n
      FROM generate_series(date_trunc('#{unit}', ?::timestamp), date_trunc('#{unit}', ?::timestamp), interval '1 #{unit}') g
      LEFT JOIN (SELECT user_id, at FROM (#{source}) s WHERE at >= date_trunc('#{unit}', ?::timestamp)) t
        ON date_trunc('#{unit}', t.at) = g
      GROUP BY g ORDER BY g
    SQL
  end

  def monthly_growth_accounts
    bucketed("SELECT id AS user_id, created_at AS at FROM users", "month", (User.minimum(:created_at) || now).beginning_of_month)
  end

  def daily_views(signed_in)
    from = today - 29
    counts = rows("SELECT day, sum(views) AS n FROM page_views WHERE day >= ? AND signed_in = ? GROUP BY day", from, signed_in)
               .to_h { |row| [ row["day"].to_date, row["n"].to_i ] }
    (from..today).map { |day| [ day, counts.fetch(day, 0) ] }
  end

  # Each label with its number of logins and of distinct accounts.
  def tally(agents)
    agents.group_by { |_user, agent| yield agent }
          .map { |label, list| { label: label, logins: list.size, accounts: list.map(&:first).uniq.size } }
          .sort_by { |row| -row[:logins] }
  end
end
