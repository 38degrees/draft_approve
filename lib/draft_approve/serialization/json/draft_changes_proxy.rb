require 'draft_approve/draft_changes_proxy'
require 'draft_approve/serialization/json/constants'

module DraftApprove
  module Serialization
    module Json

      # Json implementation of +DraftApproveProxy+. Clients should not need to
      # worry about the specific implementation details of this class, and
      # should refer to the +DraftApprove::DraftChangesProxy+ module details of
      # the public API.
      #
      # It is often most convenient to use the
      # +DraftTransaction#draft_proxy_for+ method to construct a
      # +DraftApproveProxy+ instance. This will ensure the correct
      # implementation of +DraftApproveProxy+ is used.
      #
      # @api private
      #
      # @see DraftApprove::DraftChangesProxy
      # @see DraftTransaction#draft_proxy_for
      class DraftChangesProxy
        include DraftApprove::DraftChangesProxy
        include Comparable

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
        #
        # @see DraftApprove::DraftChangesProxy#new_value
        def new_value(attribute_name)
          # Create hash with default block for auto-memoization
          @new_values_memo ||= Hash.new do |hash, attribute|
            hash[attribute] = begin
              association = @draftable_class.reflect_on_association(attribute)
              if association.blank?
                new_value_simple_attribute(attribute)
              elsif association.belongs_to?
                new_value_belongs_to_assocation(attribute)
              else
                new_value_non_belongs_to_assocation(attribute)
              end
            end
          end

          # Get memoized value, or calculate and store it
          @new_values_memo[attribute_name.to_s]
        end

        # Whether any changes will occur to the given association of the proxied
        # +Draft+ or draftable object.
        #
        # @param association_name [String]
        #
        # @return [Boolean] +true+ if any objects will be added to this
        #   association, removed from this association, or existing associations
        #   changed in any way. +false+ otherwise.
        #
        # @see DraftApprove::DraftChangesProxy#association_changed?
        def association_changed?(association_name)
          # Create hash with default block for auto-memoization
          @association_changed_memo ||= Hash.new do |hash, association_name|
            hash[association_name] = begin
              (
                associations_added(association_name).present? ||
                associations_updated(association_name).present? ||
                associations_removed(association_name).present?
              )
            end
          end

          @association_changed_memo[association_name.to_s]
        end

        # All associated objects which will be added to the given association of
        # the proxied +Draft+ or draftable object.
        #
        # @param association_name [String]
        #
        # @return [Array<DraftChangesProxy>] DraftChangesProxy objects for each
        #   object which will be added to the given association
        #
        # @see DraftApprove::DraftChangesProxy#associations_added
        def associations_added(association_name)
          @associations_added_memo ||= Hash.new do |hash, association_name|
            hash[association_name] = association_values(association_name, :created)
          end

          @associations_added_memo[association_name.to_s]
        end

        # All associated objects which have been updated, but remain
        # the proxied +Draft+ or draftable object.
        #
        # @param association_name [String]
        #
        # @return [Array<DraftChangesProxy>] DraftChangesProxy objects for each
        #   object which will be added to the given association
        #
        # @see DraftApprove::DraftChangesProxy#associations_updated
        def associations_updated(association_name)
          @associations_updated_memo ||= Hash.new do |hash, association_name|
            hash[association_name] = association_values(association_name, :updated)
          end

          @associations_updated_memo[association_name.to_s]
        end

        # All associated objects which will be removed from the given
        # association of the proxied +Draft+ or draftable object.
        #
        # @param association_name [String]
        #
        # @return [Array<DraftChangesProxy>] DraftChangesProxy objects for each
        #   object which will be removed from the given association
        #
        # @see DraftApprove::DraftChangesProxy#associations_removed
        def associations_removed(association_name)
          @associations_removed_memo ||= Hash.new do |hash, association_name|
            hash[association_name] = association_values(association_name, :deleted)
          end

          @associations_removed_memo[association_name.to_s]
        end

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
