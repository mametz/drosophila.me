class Stock < ActiveRecord::Base
	default_scope { order('number ASC') }
end
