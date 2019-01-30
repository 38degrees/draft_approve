module DraftApprove
  module Serializers
    class Json
      def self.changes_for_model(model)
        changes = {}
        model.class.reflect_on_all_associations(:belongs_to).each do |belongs_to_assoc|
          if belongs_to_assoc.polymorphic?
            changes.merge(polymorphic_association_changes(model, belongs_to_assoc))
          else
            changes.merge(non_polymorphic_association_changes(model, belongs_to_assoc))
          end
        end
        changes.merge(non_association_changes(model))

        return changes
      end

      def self.polymorphic_association_changes(model, association)
        changes = {}
        association_method_name = association.name
        associated_obj = model.public_send(association_method_name)
        foreign_type_column_name = association.foreign_type
        foreign_key_column_name = association.foreign_key

        if associated_obj.present? && associated_obj.new_record?
          unless associated_obj.draft.present? && associated_obj.draft.persisted?
            raise "Can't save draft which references #{associated_obj} - associated object isn't saved & doesn't have a persisted draft"
          end

          changes[foreign_type_column_name] = model.public_send("#{foreign_type_column_name}_change")
          changes[foreign_key_column_name] = [
            model.public_send("#{foreign_key_column_name}_was"),
            { 'draft_id' => associated_obj.draft.id }
          ]
        else
          # The associated object either references nothing, or references a saved record
          changes[foreign_type_column_name] = model.public_send("#{foreign_type_column_name}_change")
          changes[foreign_key_column_name] = model.public_send("#{foreign_key_column_name}_change")
        end

        return changes
      end

      def self.non_polymorphic_association_changes(model, association)
        changes = {}
        association_method_name = association.name
        associated_obj = model.public_send(association_method_name)
        foreign_key_column_name = association.association_foreign_key

        if associated_obj.present? && associated_obj.new_record?
          unless associated_obj.draft.present? && associated_obj.draft.persisted?
            raise "Can't save draft which references #{associated_obj} - associated object isn't saved & doesn't have a persisted draft"
          end

          changes[foreign_key_column_name] = [
            model.public_send("#{foreign_key_column_name}_was"),
            { 'draft_id' => associated_obj.draft.id }
          ]
        else
          # The associated object either references nothing, or references a saved record
          changes[foreign_key_column_name] = model.public_send("#{foreign_key_column_name}_change")
        end

        return changes
      end

      def self.non_association_changes(model)
        changes = {}
        association_attribute_names = model.class.reflect_on_all_associations(:belongs_to).map do |ref|
          [ref.foreign_type, ref.foreign_key, ref.association_foreign_key]
        end.flatten.uniq.compact

        non_association_attribute_names = model.attribute_names - association_attribute_names
        non_association_attribute_names.each do |attribute_name|
          if model.public_send("#{attribute_name}_changed?")
            changes[attribute_name] = model.public_send("#{attribute_name}_change")
          end
        end

        return changes
      end
    end
  end
end
