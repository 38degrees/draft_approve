require 'draft_approve/serialization/json/constants'

module DraftApprove
  module Serialization
    module Json
      
      # Logic for serializing changes to ActiveRecord models into JSON format,
      # and deserializing the changes on a +Draft+ object into the new values
      # for an ActiveRecord model.
      #
      # @api private
      class Serializer

        # Serialize changes on an ActiveRecord model into a JSON representation
        # of the changes.
        #
        # @param model [Object] the +acts_as_draftable+ ActiveRecord model whose
        #   changes will be serialized to JSON
        #
        # @return [Hash] a hash representation of the changes to the given
        #   model, which can be automatically converted to JSON if persisted to
        #   a JSON formatted database column
        def self.changes_for_model(model)
          JsonSerializer.new(model).changes_for_model
        end

        # Deserialize changes from a +Draft+ object into the new values for the
        # +acts_as_draftable+ ActiveRecord model the draft relates to.
        #
        # @param draft [Draft] the +Draft+ whose changes will be deserialized
        #
        # @return [Hash] a hash representation of the new values for the object
        #   the given draft relates to.
        #
        # @example
        #   draft = Person.new(name: 'Joe Bloggs').save_draft!
        #   Json::Serializer.new_values_for_draft(draft)
        #   #=> { "name" => [nil, "Joe Bloggs"] }
        def self.new_values_for_draft(draft)
          JsonDeserializer.new(draft).new_values_for_draft
        end

        # Private Inner Class to contain the JSON Serialization logic
        class JsonSerializer
          def initialize(model)
            @model = model
          end

          def changes_for_model
            changes = {}
            @model.class.reflect_on_all_associations(:belongs_to).each do |belongs_to_assoc|
              changes.merge!(association_change(belongs_to_assoc))
            end
            return changes.merge!(non_association_changes)
          end

          private

          def association_change(association)
            old_value = association_old_value(association)
            new_value = association_new_value(association)

            if old_value == new_value
              return {}
            else
              return { association.name.to_s => [old_value, new_value] }
            end
          end

          def non_association_changes
            association_attribute_names = @model.class.reflect_on_all_associations(:belongs_to).map do |ref|
              [ref.foreign_type, ref.foreign_key, ref.association_foreign_key]
            end.flatten.uniq.compact

            non_association_attribute_names = @model.attribute_names - association_attribute_names

            return non_association_attribute_names.each_with_object({}) do |attribute_name, result_hash|
              if @model.public_send("#{attribute_name}_changed?")
                result_hash[attribute_name] = @model.public_send("#{attribute_name}_change")
              end
            end
          end

          # The old value of an association must be nil or point to a persisted
          # non-draft object.
          def association_old_value(association)
            if association.polymorphic?
              old_type = @model.public_send("#{association.foreign_type}_was")
              old_id = @model.public_send("#{association.foreign_key}_was")
            else
              old_type = association.class_name
              old_id = @model.public_send("#{association.foreign_key}_was")
            end

            return nil if old_id.blank? || old_type.blank?
            return { Constants::TYPE => old_type, Constants::ID => old_id }
          end

          # The new value of an association may be nil, or point to a persisted
          # model, or point to a non-persisted model with a persisted draft.
          #
          # Note that if the associated object is not persisted, and has no
          # persisted draft, then this is an error scenario.
          def association_new_value(association)
            associated_obj = @model.public_send(association.name)

            if associated_obj.blank?
              return nil
            elsif associated_obj.persisted?
              if association.polymorphic?
                return {
                  Constants::TYPE => @model.public_send(association.foreign_type),
                  Constants::ID => @model.public_send(association.foreign_key)
                }
              else
                return {
                  Constants::TYPE => association.class_name,
                  Constants::ID => @model.public_send(association.foreign_key)
                }
              end
            else  # associated_obj not persisted - so we need a persisted draft
              draft = associated_obj.draft_pending_approval

              if draft.blank? || draft.new_record?
                raise(DraftApprove::Errors::AssociationUnsavedError, "#{association.name} points to an unsaved object")
              end

              return { Constants::TYPE => draft.class.name, Constants::ID => draft.id }
            end
          end
        end

        # Private Inner Class to contain the JSON Serialization logic
        class JsonDeserializer
          def initialize(draft)
            @draft = draft
          end

          def new_values_for_draft
            draftable_class = Object.const_get(@draft.draftable_type)
            association_attribute_names = draftable_class.reflect_on_all_associations(:belongs_to).map(&:name).map(&:to_s)

            return @draft.draft_changes.each_with_object({}) do |(attribute_name, change), result_hash|
              new_value = change[1]
              if association_attribute_names.include?(attribute_name)
                result_hash[attribute_name] = associated_model_for_new_value(new_value)
              else
                result_hash[attribute_name] = new_value
              end
            end
          end

          private

          def associated_model_for_new_value(new_value)
            return nil if new_value.nil?

            associated_model_type = new_value[Constants::TYPE]
            associated_model_id = new_value[Constants::ID]

            associated_class = Object.const_get(associated_model_type)

            if associated_class.ancestors.include? Draft
              # The associated class is a draft (or subclass).
              # It must be in the same draft transaction as the draft we're getting values for.
              associated_draft = @draft.draft_transaction.drafts.find(associated_model_id)

              raise(DraftApprove::Errors::PriorDraftNotAppliedError) if associated_draft.draftable.nil?

              return associated_draft.draftable
            else
              return associated_class.find(associated_model_id)
            end
          end
        end

        private_constant :JsonSerializer, :JsonDeserializer
      end
    end
  end
end
