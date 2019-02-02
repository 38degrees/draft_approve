module DraftApprove
  module Serializers
    class Json
      def self.changes_for_model(model)
        changes = {}
        model.class.reflect_on_all_associations(:belongs_to).each do |belongs_to_assoc|
          changes.merge!(association_change(model, belongs_to_assoc))
        end
        return changes.merge!(non_association_changes(model))
      end

      private

      def self.association_change(model, association)
        old_value = association_old_value(model, association)
        new_value = association_new_value(model, association)

        if old_value == new_value
          return {}
        else
          return { association.name.to_s => [old_value, new_value] }
        end
      end

      def self.non_association_changes(model)
        association_attribute_names = model.class.reflect_on_all_associations(:belongs_to).map do |ref|
          [ref.foreign_type, ref.foreign_key, ref.association_foreign_key]
        end.flatten.uniq.compact

        non_association_attribute_names = model.attribute_names - association_attribute_names

        return non_association_attribute_names.each_with_object({}) do |attribute_name, result_hash|
          if model.public_send("#{attribute_name}_changed?")
            result_hash[attribute_name] = model.public_send("#{attribute_name}_change")
          end
        end
      end

      # The old value of an association must be nil or point to a persisted
      # non-draft object.
      def self.association_old_value(model, association)
        if association.polymorphic?
          old_type = model.public_send("#{association.foreign_type}_was")
          old_id = model.public_send("#{association.foreign_key}_was")
        else
          old_type = association.class_name
          old_id = model.public_send("#{association.foreign_key}_was")
        end

        return nil if old_id.blank? || old_type.blank?
        return { DraftApprove::TYPE => old_type, DraftApprove::ID => old_id }
      end

      # The new value of an association may be nil, or point to a persisted
      # model, or point to a non-persisted model with a persisted draft.
      #
      # Note that if the associated object is not persisted, and has no
      # persisted draft, then this is an error scenario.
      def self.association_new_value(model, association)
        associated_obj = model.public_send(association.name)

        if associated_obj.blank?
          return nil
        elsif associated_obj.persisted?
          if association.polymorphic?
            return {
              DraftApprove::TYPE => model.public_send(association.foreign_type),
              DraftApprove::ID => model.public_send(association.foreign_key)
            }
          else
            return {
              DraftApprove::TYPE => association.class_name,
              DraftApprove::ID => model.public_send(association.foreign_key)
            }
          end
        else  # associated_obj not persisted - so we need a persisted draft
          if associated_obj.draft.blank? || associated_obj.draft.new_record?
            raise(DraftApprove::AssociationUnsavedError, "#{association.name} points to an unsaved object")
          end

          return {
            DraftApprove::TYPE => associated_obj.draft.class.name,
            DraftApprove::ID => associated_obj.draft.id
          }
        end
      end
    end
  end
end
