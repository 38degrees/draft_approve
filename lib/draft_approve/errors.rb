module DraftApprove
  module Errors
    class DraftTransactionError < StandardError; end
    class NestedDraftTransactionError < DraftTransactionError; end
    class NoDraftTransactionError < DraftTransactionError; end

    class DraftSaveError < StandardError; end
    class ExistingDraftError < DraftSaveError; end
    class AlreadyPersistedModelError < DraftSaveError; end
    class UnpersistedModelError < DraftSaveError; end

    class ChangeSerializationError < StandardError; end
    class AssociationUnsavedError < ChangeSerializationError; end

    class ApplyDraftChangesError < StandardError; end
    class NoDraftableError < ApplyDraftChangesError; end
    class PriorDraftNotAppliedError < ApplyDraftChangesError; end
  end
end
