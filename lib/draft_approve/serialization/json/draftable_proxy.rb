require 'draft_approve/serialization/json/helper'

module DraftApprove
  module Serialization
    module Json
      class DraftableProxy
        HELPER = DraftApprove::Serialization::Json::Helper

        def initialize(object, draft_transaction)
          if object.blank? || draft_transaction.blank?
            raise(ArgumentError, "#{self.class.name}.new - object & draft_transaction are both required arguments")
          end

          if object.new_record?
            raise(ArgumentError, "#{self.class.name}.new - object must already be persisted")
          end

          if object.is_a? Draft
            unless object.draft_transaction == draft_transaction
              raise(ArgumentError, "#{self.class.name}.new - draft_transaction for #{object} is inconsistent with given draft_transaction #{draft_transaction}")
            end

            # Construct DraftableProxy from a draft
            # Note that @draftable may be nil (if this is a CREATE draft)
            @draft = draft
            @draftable = (draft.draftable.present? && draft.draftable.persisted?) ? draft.draftable : nil
            @draftable_class = Object.const_get(draft.draftable_type)
            @draft_transaction = draft_transaction
          else
            # Construct DraftableProxy from a draftable
            # Note that @draft may be nil (if the draftable has no changes within the scope of this transaction)
            @draft = draft_transaction.drafts.find_by(draftable: object)
            @draftable = object
            @draftable_class = object.class
            @draft_transaction = draft_transaction
          end
        end

        # Whether or not the proxied `Draft` or draftable object has any
        # changes.
        #
        # Note, this method only considers changes to attributes and changes
        # to any `belongs_to` references. Any added / changed / deleted
        # `has_many` or `has_one` associations are not considered.
        #
        # @return [Boolean] whether or not the proxied object has changes
        def changed?
          if @draft.blank?
            false # No draft for this object, so nothing changed
          else
            @draft.draft_changes.present?
          end
        end

        # List of attributes on the proxied `Draft` or draftable object which
        # have changes.
        #
        # Note, this method only considers changes to attributes and changes
        # to any `belongs_to` references. Any added / changed / deleted
        # `has_many` or `has_one` associations are not considered.
        #
        # @return [Array<String>] array of the attributes which have changed on
        #   the proxied object
        def changed
          if @draft.blank?
            [] # No draft for this object, so no attributes have changed
          else
            @draft.draft_changes.keys
          end
        end

        # Hash of changes on the proxied `Draft` or draftable object which
        # have changes.
        #
        # Note, this method only considers changes to attributes and changes
        # to any `belongs_to` references. Any added / changed / deleted
        # `has_many` or `has_one` associations are not considered.
        #
        # @return [Hash<String, Array>] hash of the changes on the proxied
        #   object, eg. `{ "name" => ["old_name", "new_name"] }`
        def changes
          if @draft.blank?
            {} # No draft for this object, so no attributes have changed
          else
            @draft.draft_changes.each_with_object({}) do |(k,v), new_hash|
              new_hash[k] = [old_value(k), new_value(k)]
            end
          end
        end

        # The old, currently persisted value, for the given attribute on the
        # proxied `Draft` or draftable object.
        #
        # @param attribute_name [String]
        #
        # @return [Object, nil] the old value of the given attribute, or `nil`
        #   if there was no previous value
        def old_value(attribute_name)
          if @draftable.present?
            # 'Old' value is what is currently on the draftable object
            return draft_proxy_for(@draftable.public_send(attribute_name))
          else
            # No draftable exists, so this must be a CREATE draft, meaning
            # there's no 'old' value...
            association = @draftable_class.reflect_on_association(attribute_name)
            if (association.blank? || association.belongs_to? || association.has_one?)
              return nil  # Not an association, or links to a single object
            else
              return []   # Is a has_many association
            end
          end
        end

        # The new, drafted value for the given attribute on the proxied `Draft`
        # or draftable object. If no changes have been drafted for the given
        # attribute, then returns the currently persisted value for the
        # attribute.
        #
        # @param attribute_name [String]
        #
        # @return [Object, nil] the new value of the given attribute, or the
        #   currently persisted value if there are no draft changes for the
        #   attribute
        def new_value(attribute_name)
          association = @draftable_class.reflect_on_association(attribute_name)
          if association.blank?
            new_value_simple_attribute(attribute_name)
          elsif association.belongs_to?
            new_value_belongs_to_assocation(attribute_name)
          else
            new_value_non_belongs_to_assocation(attribute_name)
          end
        end

        private

        # def create_dynamic_methods
        #   # Create methods on
        #   HELPER.all_assocation_attribute_names do |assoc_attrib_name|
        #     define_method(assoc_attrib_name) do
        #
        #     end
        #   end
        #
        #   association_attribute_names.each do |assoc_attrib_name|
        #     # Define the method to get the 'new' value of the association
        #     define_method(assoc_attrib_name) do
        #       if @draft.draft_changes.has_key?(assoc_attrib_name)
        #         draft_value = @draft.draft_changes[assoc_attrib_name][1]
        #       else
        #         # Value of the association hasn't changed in the draft, get the
        #         # association value from the draftable object
        #         @draftable.public_send(assoc_attrib_name)
        #       end
        #     end
        #   end
        # end

        def new_value_simple_attribute(attribute_name)
          # This attribute is a simple value (not an association)
          if @draft.blank? || !@draft.draft_changes.has_key?(attribute_name)
            # Either no draft, or no changes for this attribute
            return draft_proxy_for(@draftable.public_send(attribute_name))
          else
            # Draft changes have been made on this attribute...
            new_value = @draft.draft_changes[attribute_name][1]
            return draft_proxy_for(new_value)
          end
        end

        def new_value_belongs_to_assocation(attribute_name)
          # This attribute is an association where the 'belongs_to' is on this
          # class...
          if @draft.blank? || !@draft.draft_changes.has_key?(attribute_name)
            # Either no draft, or no changes for this attribute
            return draft_proxy_for(@draftable.public_send(attribute_name))
          else
            # Draft changes have been made on this attribute...
            new_value = @draft.draft_changes[attribute_name][1]
            new_value_class = Object.const_get(new_value[HELPER::TYPE])
            new_value_object = new_value_class.find(new_value[HELPER::ID])
            return draft_proxy_for(new_value_object)
          end
        end

        def new_value_non_belongs_to_assocation(attribute_name)
          # This attribute is an association where the 'belongs_to' is on the
          # other class...
          association = @draftable_class.reflect_on_association(attribute_name)
          associated_class_name = association.class_name
          associated_attribute_name = association.inverse_of.name

          associated_instances = []

          if @draftable.present?
            # If we have a concrete object, get the objects already associated
            # with it, as well as any drafts pointed at it (drafts will point
            # at the live instance, not the draft changes)
            associated_instances << @draftable.public_send(attribute_name)

            associated_instances << @draft_transaction.drafts.where(
              draftable_type: associated_class_name
            ).where(
              <<~SQL
                draft_changes #>> '{#{associated_attribute_name},1,#{HELPER::TYPE}}' = '#{@draftable.class.name}'
                AND
                draft_changes #>> '{#{associated_attribute_name},1,#{HELPER::ID}}' = '#{@draftable.id}'
              SQL
            )
          else
            # If we don't have a concrete object, this is a CREATE draft, so
            # just get any drafts pointed at this draft
            associated_instances << @draft_transaction.drafts.where(
              draftable_type: associated_class_name
            ).where(
              <<~SQL
                draft_changes #>> '{#{associated_attribute_name},1,#{HELPER::TYPE}}' = '#{@draft.class.name}'
                AND
                draft_changes #>> '{#{associated_attribute_name},1,#{HELPER::ID}}' = '#{@draft.id}'
              SQL
            )
          end

          return draft_proxy_for(associated_instances)
        end

        def draft_proxy_for(object)
          if object.repsonds_to?(:map)
            # Object is a collection (likely an ActiveRecord collection), recursively call draft_proxy_for
            return object.map { |o| draft_proxy_for(o) }
          elsif (object.is_a? Draft) || (object.responds_to?(:draftable?) && object.draftable?)
            # Object is a draft or a draftable, wrap it in a DraftableProxy
            return DraftApprove::Serialization::Json::DraftableProxy.new(object, @draft_transaction)
          else
            return object
          end
        end
      end
    end
  end
end
