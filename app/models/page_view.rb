class PageView < ApplicationRecord
  def self.record(page, signed_in:, day: Date.current)
    upsert({ day: day, page: page, signed_in: signed_in, views: 1 },
           unique_by: %i[day page signed_in], on_duplicate: Arel.sql("views = page_views.views + 1"))
  end
end
