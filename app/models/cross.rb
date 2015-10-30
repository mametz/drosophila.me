class Cross < ActiveRecord::Base
	belongs_to :user
	has_many :flies

  default_scope { order('crossdate DESC') }

	extend FriendlyId
  	friendly_id :slug_candidates, use: [:slugged, :finders]

  	def slug_candidates
    [
      :link,
      [:link, :id]
    ]
  end
end
