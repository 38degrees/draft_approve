require 'draft_approve/serialization/json/draft_changes_proxy'
require 'draft_approve/serialization/json/serializer'

module DraftApprove
  module Serialization
    module Json
      def self.get_serializer
        DraftApprove::Serialization::Json::Serializer
      end

      def self.get_draftable_proxy
        DraftApprove::Serialization::Json::DraftableProxy
      end
    end
  end
end
