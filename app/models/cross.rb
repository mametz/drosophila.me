class Cross < ActiveRecord::Base
	belongs_to :user
	has_many :flies, :dependent => :destroy

	extend FriendlyId
  	friendly_id :slug_candidates, use: [:slugged, :finders]

  	def slug_candidates
    [
      :link,
      [:link, :id]
    ]
  end
end
