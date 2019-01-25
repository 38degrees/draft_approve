require 'active_record'

require 'draft_approve/base_class_methods'
require 'draft_approve/class_methods'
require 'draft_approve/instance_methods'
require 'draft_approve/draft'

ActiveRecord::Base.extend Drafting::BaseClassMethods
