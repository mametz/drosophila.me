class ActivityDay < ApplicationRecord
  belongs_to :user

  def self.record(user, day: Date.current)
    upsert({ user_id: user.id, day: day, requests: 1 },
           unique_by: %i[user_id day], on_duplicate: Arel.sql("requests = activity_days.requests + 1"))
  end
end
