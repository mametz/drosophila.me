class Stock < ActiveRecord::Base
	
	belongs_to :user

	default_scope { order('number ASC') }
end
