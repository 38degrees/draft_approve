require 'active_record'

require 'draft_approve/draftable/base_class_methods'

ActiveRecord::Base.extend DraftApprove::Draftable::BaseClassMethods
