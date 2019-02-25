require 'draft_approve/serialization/json/draft_changes_proxy'
require 'draft_approve/serialization/json/serializer'

module DraftApprove
  module Serialization
    module Json
      def self.get_serializer
        DraftApprove::Serialization::Json::Serializer
      end

      def self.get_draft_changes_proxy
        DraftApprove::Serialization::Json::DraftChangesProxy
      end
    end
  end
end
