class Cross < ActiveRecord::Base
	has_many :flies, :dependent => :destroy
end
