require 'draft_approve/serialization/draft_changes_proxy'
require 'draft_approve/serialization/json/constants'

module DraftApprove
  module Serialization
    module Json

      # Wrapper for +Draft+ and +acts_as_draftable+ objects, such that both have
      # a consistent API to get current and new values within the context of a
      # specific +DraftTransaction+.
      #
      # References to other objects returned by methods from this class are also
      # wrapped in a +DraftChangesProxy+, meaning it is easy to chain and
      # navigate complex association trees within the context of a
      # +DraftTransaction+.
      #
      # This can be useful, for example, to display all changes that will occur
      # on an object, including changes to all it's associated 'child' objects.
      class DraftChangesProxy
        include DraftApprove::Serialization::DraftChangesProxy
        include Comparable

        # attr_reader :draft, :draftable, :draftable_class, :draft_transaction
        #
        # # Creates a new DraftChangesProxy
        # #
        # # @param object [Object] the +Draft+ object, or the instance of an
        # #   +acts_as_draftable+ class, which is being proxied to get changes
        # # @param transaction [DraftTransaction] the +DraftTransaction+ within
        # #   which to look for changes. If +object+ is a +Draft+, this parameter
        # #   is optional and if not provided will use the +DraftTransaction+
        # #   associated with the given +Draft+. If +object+ is not a +Draft+,
        # #   this parameter is required.
        # def initialize(object, transaction = nil)
        #   if object.blank?
        #     raise(ArgumentError, "object is required")
        #   end
        #
        #   if object.new_record?
        #     raise(ArgumentError, "object #{object} must already be persisted")
        #   end
        #
        #   if object.is_a? Draft
        #     if transaction.present? && object.draft_transaction != transaction
        #       raise(ArgumentError, "draft_transaction for #{object} is inconsistent with given draft_transaction #{transaction}")
        #     end
        #
        #     # Construct DraftableProxy from a draft
        #     # Note that @draftable may be nil (if this is a CREATE draft)
        #     @draft = object
        #     @draftable = (object.draftable.present? && object.draftable.persisted?) ? object.draftable : nil
        #     @draftable_class = Object.const_get(object.draftable_type)
        #     @draft_transaction = object.draft_transaction
        #   else
        #     if transaction.blank?
        #       raise(ArgumentError, "draft_transaction is required when object is a draftable")
        #     end
        #
        #     # Construct DraftableProxy from a draftable
        #     # Note that @draft may be nil (if the draftable has no changes within the scope of this transaction)
        #     @draft = transaction.drafts.find_by(draftable: object)
        #     @draftable = object
        #     @draftable_class = object.class
        #     @draft_transaction = transaction
        #   end
        # end
        #
        # # @return [Boolean] +true+ if this +Draft+ is to create a new record,
        # #   +false+ otherwise
        # def create?
        #   @draft.present? && @draft.create?
        # end
        #
        # # @return [Boolean] +true+ if this +Draft+ is to delete an existing
        # #   record, +false+ otherwise
        # def delete?
        #   @draft.present? && @draft.delete?
        # end
        #
        # # Whether or not the proxied +Draft+ or draftable object has any
        # # changes.
        # #
        # # Note, this method only considers changes to attributes and changes
        # # to any +belongs_to+ references. Any added / changed / deleted
        # # +has_many+ or +has_one+ associations are not considered.
        # #
        # # @return [Boolean] whether or not the proxied object has changes
        # def changed?
        #   if @draft.blank?
        #     false # No draft for this object, so nothing changed
        #   else
        #     @draft.draft_changes.present?
        #   end
        # end
        #
        # # List of attributes on the proxied +Draft+ or draftable object which
        # # have changes.
        # #
        # # Note, this method only considers changes to attributes and changes
        # # to any +belongs_to+ references. Any added / changed / deleted
        # # +has_many+ or +has_one+ associations are not considered.
        # #
        # # @return [Array<String>] array of the attributes which have changed on
        # #   the proxied object
        # def changed
        #   if @draft.blank?
        #     [] # No draft for this object, so no attributes have changed
        #   else
        #     @draft.draft_changes.keys
        #   end
        # end
        #
        # # Hash of changes on the proxied +Draft+ or draftable object which
        # # have changes.
        # #
        # # Note, this method only considers changes to attributes and changes
        # # to any +belongs_to+ references. Any added / changed / deleted
        # # +has_many+ or +has_one+ associations are not considered.
        # #
        # # @return [Hash<String, Array>] hash of the changes on the proxied
        # #   object, eg. <tt>{ "name" => ["old_name", "new_name"] }</tt>
        # def changes
        #   if @draft.blank?
        #     {} # No draft for this object, so no attributes have changed
        #   else
        #     @draft.draft_changes.each_with_object({}) do |(k,v), new_hash|
        #       new_hash[k] = [current_value(k), new_value(k)]
        #     end
        #   end
        # end
        #
        # # The currently persisted value for the given attribute on the proxied
        # # +Draft+ or draftable object.
        # #
        # # @param attribute_name [String]
        # #
        # # @return [Object, nil] the old value of the given attribute, or +nil+
        # #   if there was no previous value
        # def current_value(attribute_name)
        #   attribute_name = attribute_name.to_s
        #
        #   if @draftable.present?
        #     # 'Old' value is what is currently on the draftable object
        #     return draft_proxy_for(@draftable.public_send(attribute_name))
        #   else
        #     # No draftable exists, so this must be a CREATE draft, meaning
        #     # there's no 'old' value...
        #     association = @draftable_class.reflect_on_association(attribute_name)
        #     if (association.blank? || association.belongs_to? || association.has_one?)
        #       return nil  # Not an association, or links to a single object
        #     else
        #       return []   # Is a has_many association
        #     end
        #   end
        # end

        # The new, drafted value for the given attribute on the proxied +Draft+
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
          attribute_name = attribute_name.to_s

          association = @draftable_class.reflect_on_association(attribute_name)
          if association.blank?
            new_value_simple_attribute(attribute_name)
          elsif association.belongs_to?
            new_value_belongs_to_assocation(attribute_name)
          else
            new_value_non_belongs_to_assocation(attribute_name)
          end
        end

        # Whether any changes will occur to the given association of the proxied
        # +Draft+ or draftable object.
        #
        # @param association_name [String]
        #
        # @return [Boolean] +true+ if any objects will be added to this
        #   association, removed from this association, or existing associations
        #   changed in any way. +false+ otherwise.
        def association_changed?(association_name)
          return (
            associations_added(association_name).present? ||
            associations_updated(association_name).present? ||
            associations_removed(association_name).present?
          )
        end

        # All associated objects which will be added to the given association of
        # the proxied +Draft+ or draftable object.
        #
        # @param association_name [String]
        #
        # @return [Array<DraftChangesProxy>] DraftChangesProxy objects for each
        #   object which will be added to the given association
        def associations_added(association_name)
          association_values(association_name, :created)
        end

        # All associated objects which have been updated, but remain
        # the proxied +Draft+ or draftable object.
        #
        # @param association_name [String]
        #
        # @return [Array<DraftChangesProxy>] DraftChangesProxy objects for each
        #   object which will be added to the given association
        def associations_updated(association_name)
          association_values(association_name, :updated)
        end

        # All associated objects which will be removed from the given
        # association of the proxied +Draft+ or draftable object.
        #
        # @param association_name [String]
        #
        # @return [Array<DraftChangesProxy>] DraftChangesProxy objects for each
        #   object which will be removed from the given association
        def associations_removed(association_name)
          association_values(association_name, :deleted)
        end

        # Returns a string representing the current value of the proxied object.
        #
        # @return the +to_s+ of the current value of the proxied object (ie.
        #   the value before any changes would take effect). If there is no
        #   current value (ie. this is a proxy for a new draft) then simply
        #   returns "New #{classname}".
        # def current_to_s
        #   if @draftable.present?
        #     return "#{@draftable_class}: #{@draftable.to_s}"
        #   else
        #     # No current draftable
        #     return "New #{@draftable_class}"
        #   end
        # end

        # Override comparable for +DraftChangesProxy+ objects. This is so
        # operators such as <tt>+</tt> and <tt>-</tt> work accurately when an
        # array of +DraftChangesProxy+ objects are being returned. It also makes
        # testing easier.
        #
        # @return [Integer] 0 if the given object is a +DraftChangesProxy+
        #   which refers to the same +Draft+ (if any), the same draftable
        #   (if any), the same draftable class, and the same +DraftTransaction+.
        #   Non-zero otherwise.
        def <=>(other)
          return -1 unless other.is_a?(self.class)

          [:draft, :draftable, :draftable_class, :draft_transaction].each do |method|
            comp = self.public_send(method) <=> other.public_send(method)
            return -1 if comp.nil?
            return comp unless comp.zero?
          end

          # Checked all attributes, and all are equal
          return 0
        end

        alias :eql? :==

        # Override hash for +DraftChangesProxy+ objects. This is so operators
        # such as + and - work accurately when an array of +DraftChangesProxy+
        # objects are being returned. It also makes testing easier.
        #
        # @return [Integer] a hash of all the +DraftChangeProxy+s attributes
        def hash
          [@draft, @draftable, @draftable_class, @draft_transaction].hash
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

        # Helper to get the new value of a simple attribute as a result of this
        # draft transaction
        def new_value_simple_attribute(attribute_name)
          attribute_name = attribute_name.to_s

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

        # Helper to get the new value of a belongs_to association as a result
        # of this draft transaction
        def new_value_belongs_to_assocation(attribute_name)
          attribute_name = attribute_name.to_s

          # This attribute is an association where the 'belongs_to' is on this
          # class...
          if @draft.blank? || !@draft.draft_changes.has_key?(attribute_name)
            # Either no draft, or no changes for this attribute
            return draft_proxy_for(@draftable.public_send(attribute_name))
          else
            # Draft changes have been made on this attribute...
            new_value = @draft.draft_changes[attribute_name][1]

            if new_value.blank?
              return nil  # The association link has been removed on the draft
            else
              new_value_class = Object.const_get(new_value[Constants::TYPE])
              new_value_object = new_value_class.find(new_value[Constants::ID])
              return draft_proxy_for(new_value_object)
            end
          end
        end

        # Helper to get the new value of has_one / has_many associations (ie.
        # get all the objects the association would return after this draft
        # dransaction has been applied)
        def new_value_non_belongs_to_assocation(association_name)
          association_name = association_name.to_s

          associated_instances = []

          # Starting point is all objects already associated
          associated_instances += current_value(association_name)

          # Add any new objects which will be created by this transaction and
          # refer to this object
          associated_instances += associations_added(association_name)

          # Finally remove any associations which will be deleted or not
          # refer to this object anymore as a reuslt of this transaction
          associated_instances -= associations_removed(association_name)

          return associated_instances
        end

        # Helper to get the associations which have been created or deleted as
        # a result of this draft transaction
        def association_values(association_name, mode)
          association_name = association_name.to_s

          association = @draftable_class.reflect_on_association(association_name)
          if association.blank? || association.belongs_to?
            raise(ArgumentError, "#{association_name} must be a has_many or has_one association")
          end

          associated_class_name = association.class_name
          associated_attribute_name = association.inverse_of.name

          # If we are proxying a concrete object, all associations will point
          # directly at it, otherwise we are proxying a CREATE draft and
          # associations will point at the draft
          required_object = (@draftable.present? ? @draftable : @draft)

          case mode
          when :created
            # Looking for newly created associations, so we want to find
            # objects where the new value (index=1) of the associated
            # attribute points at this object.
            # eg. if looking for new memberships for Person 1, we want to find
            # Membership objects where the json changes look like this:
            # { "person" => [nil, { "TYPE" => "Person", "ID" => 1 }] }
            json_query_str_type = "{#{associated_attribute_name},1,#{Constants::TYPE}}"
            json_query_str_id = "{#{associated_attribute_name},1,#{Constants::ID}}"

            created_associations = @draft_transaction.drafts.where(
              draftable_type: associated_class_name
            ).where(
              <<~SQL
                draft_changes #>> '#{json_query_str_type}' = '#{required_object.class.name}'
                AND
                draft_changes #>> '#{json_query_str_id}' = '#{required_object.id}'
              SQL
            )

            return draft_proxy_for(created_associations)
          when :updated
            # Looking for associations which have draft updates but which still
            # point at this object (if it didn't previously point at this object
            # the change is a new association, so covered by the association
            # created case - if it no longer points at this object the
            # association has been broken, so covered by the association deleted
            # case)
            required_proxy = draft_proxy_for(required_object)

            updated_associations = current_value(association_name).select do |proxy|
              proxy.changed? &&
                proxy.new_value(associated_attribute_name) == required_proxy
            end

            return draft_proxy_for(updated_associations)
          when :deleted
            # Looking for current associations which have either been drafted
            # for complete deletion, or which have had their reference changed
            # to no longer point at this object
            required_proxy = draft_proxy_for(required_object)

            deleted_associations = current_value(association_name).select do |proxy|
              proxy.delete? ||
                proxy.new_value(associated_attribute_name) != required_proxy
            end

            return draft_proxy_for(deleted_associations)
          else
            raise(ArgumentError, "Unrecognised mode #{mode}")
          end
        end

        # Helper to get a draft proxy for any object before returning it
        def draft_proxy_for(object)
          if object.respond_to?(:map)
            # Object is a collection (likely an ActiveRecord collection), recursively call draft_proxy_for
            return object.map { |o| draft_proxy_for(o) }
          elsif (object.is_a? Draft) || (object.respond_to?(:draftable?) && object.draftable?)
            # Object is a draft or a draftable, wrap it in a DraftChangesProxy
            return self.class.new(object, @draft_transaction)
          else
            return object
          end
        end
      end
    end
  end
end
