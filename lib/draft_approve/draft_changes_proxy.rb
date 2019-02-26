module DraftApprove

  # Mixin wrapper for +Draft+ and +acts_as_draftable+ objects, such that both
  # have a consistent API to get current and new values within the context of
  # a specific +DraftTransaction+.
  #
  # References to other objects returned by methods from this class are also
  # wrapped in a +DraftChangesProxy+, meaning it is relatively easy to chain
  # and navigate complex association trees within the context of a
  # +DraftTransaction+.
  #
  # This can be useful, for example, to display all changes that will occur
  # on an object, including changes to all it's associated 'child' objects.
  #
  # It is often most convenient to use the
  # +DraftTransaction#draft_proxy_for+ method to construct a
  # +DraftApproveProxy+ instance. This will ensure the correct implementation
  # of +DraftApproveProxy+ is used.
  #
  # Classes which include this module must implement the instance methods
  # +new_value+, +association_changed?+, +associations_added+,
  # +associations_updated+, +associations_removed+.
  #
  # @see DraftTransaction#draft_proxy_for
  module DraftChangesProxy
    attr_reader :draft, :draftable, :draftable_class, :draft_transaction

    # Creates a new DraftChangesProxy
    #
    # @param object [Object] the +Draft+ object, or the instance of an
    #   +acts_as_draftable+ class, which is being proxied to get changes
    # @param transaction [DraftTransaction] the +DraftTransaction+ within
    #   which to look for changes. If +object+ is a +Draft+, this parameter
    #   is optional and if not provided will use the +DraftTransaction+
    #   associated with the given +Draft+. If +object+ is not a +Draft+,
    #   this parameter is required.
    def initialize(object, transaction = nil)
      if object.blank?
        raise(ArgumentError, "object is required")
      end

      if object.new_record?
        raise(ArgumentError, "object #{object} must already be persisted")
      end

      if object.is_a? Draft
        if transaction.present? && object.draft_transaction != transaction
          raise(ArgumentError, "draft_transaction for #{object} is inconsistent with given draft_transaction #{transaction}")
        end

        # Construct DraftableProxy from a draft
        # Note that @draftable may be nil (if this is a CREATE draft)
        @draft = object
        @draftable = (object.draftable.present? && object.draftable.persisted?) ? object.draftable : nil
        @draftable_class = Object.const_get(object.draftable_type)
        @draft_transaction = object.draft_transaction
      else
        if transaction.blank?
          raise(ArgumentError, "draft_transaction is required when object is a draftable")
        end

        # Construct DraftableProxy from a draftable
        # Note that @draft may be nil (if the draftable has no changes within the scope of this transaction)
        @draft = transaction.drafts.find_by(draftable: object)
        @draftable = object
        @draftable_class = object.class
        @draft_transaction = transaction
      end
    end

    # @return [Boolean] +true+ if this +Draft+ is to create a new record,
    #   +false+ otherwise
    def create?
      @draft.present? && @draft.create?
    end

    # @return [Boolean] +true+ if this +Draft+ is to delete an existing
    #   record, +false+ otherwise
    def delete?
      @draft.present? && @draft.delete?
    end

    # Whether or not the proxied +Draft+ or draftable object has any
    # changes.
    #
    # Note, this method only considers changes to attributes and changes
    # to any +belongs_to+ references. Any added / changed / deleted
    # +has_many+ or +has_one+ associations are not considered.
    #
    # @return [Boolean] whether or not the proxied object has changes
    def changed?
      if @draft.blank?
        false # No draft for this object, so nothing changed
      else
        @draft.draft_changes.present?
      end
    end

    # List of attributes on the proxied +Draft+ or draftable object which
    # have changes.
    #
    # Note, this method only considers changes to attributes and changes
    # to any +belongs_to+ references. Any added / changed / deleted
    # +has_many+ or +has_one+ associations are not considered.
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

    # Hash of changes on the proxied +Draft+ or draftable object which
    # have changes.
    #
    # Note, this method only considers changes to attributes and changes
    # to any +belongs_to+ references. Any added / changed / deleted
    # +has_many+ or +has_one+ associations are not considered.
    #
    # @return [Hash<String, Array>] hash of the changes on the proxied
    #   object, eg. <tt>{ "name" => ["old_name", "new_name"] }</tt>
    def changes
      @changes_memo ||= begin  # Memoize result
        if @draft.blank?
          {} # No draft for this object, so no attributes have changed
        else
          @draft.draft_changes.each_with_object({}) do |(k,v), new_hash|
            new_hash[k] = [current_value(k), new_value(k)]
          end
        end
      end
    end

    # The currently persisted value for the given attribute on the proxied
    # +Draft+ or draftable object.
    #
    # @param attribute_name [String]
    #
    # @return [Object, nil] the old value of the given attribute, or +nil+
    #   if there was no previous value
    def current_value(attribute_name)
      # Create hash with default block for auto-memoization
      @current_values_memo ||= Hash.new do |hash, attribute|
        hash[attribute] = begin
          if @draftable.present?
            # Current value is what's on the draftable object
            draft_proxy_for(@draftable.public_send(attribute))
          else
            # No draftable exists, so this must be a CREATE draft, meaning
            # there's no 'old' value...
            association = @draftable_class.reflect_on_association(attribute)
            if (association.blank? || association.belongs_to? || association.has_one?)
              nil # Not an association, or links to a single object
            else
              []  # Is a has_many association
            end
          end
        end
      end

      # Get memoized value, or calculate and store it
      @current_values_memo[attribute_name.to_s]
    end

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
      raise "#new_value has not been implemented in #{self.class.name}"
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
      raise "#association_changed? has not been implemented in #{self.class.name}"
    end

    # All associated objects which will be added to the given association of
    # the proxied +Draft+ or draftable object.
    #
    # @param association_name [String]
    #
    # @return [Array<DraftChangesProxy>] DraftChangesProxy objects for each
    #   object which will be added to the given association
    def associations_added(association_name)
      raise "#associations_added has not been implemented in #{self.class.name}"
    end

    # All associated objects which have been updated, but remain
    # the proxied +Draft+ or draftable object.
    #
    # @param association_name [String]
    #
    # @return [Array<DraftChangesProxy>] DraftChangesProxy objects for each
    #   object which will be added to the given association
    def associations_updated(association_name)
      raise "#associations_updated has not been implemented in #{self.class.name}"
    end

    # All associated objects which will be removed from the given
    # association of the proxied +Draft+ or draftable object.
    #
    # @param association_name [String]
    #
    # @return [Array<DraftChangesProxy>] DraftChangesProxy objects for each
    #   object which will be removed from the given association
    def associations_removed(association_name)
      raise "#associations_removed has not been implemented in #{self.class.name}"
    end

    # Returns a string representing the current value of the proxied object.
    #
    # @return [String] the +to_s+ of the current value of the proxied object
    #   (ie. the value before any changes would take effect). If there is no
    #   current value (ie. this is a proxy for a new draft) then simply
    #   returns "New <classname>".
    def current_to_s
      if @draftable.present?
        return "#{@draftable_class}:#{@draftable.id} - #{@draftable.to_s}"
      else
        # No current draftable
        return "New #{@draftable_class}"
      end
    end
  end
end
