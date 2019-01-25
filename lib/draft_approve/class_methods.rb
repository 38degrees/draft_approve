module DraftApprove
  module ClassMethods

    # draft_transaction begins a database transaction and creates a
    # DraftTransaction record to group together all draft changes which must
    # be approved and applied together
    def draft_transaction(user: nil)
      ActiveRecord::Base.transaction do
        Thread.current[:draft_approve_transaction] = DraftTransaction.create!(user: user)
        yield
        Thread.current[:draft_approve_transaction] = nil
      end
    end
  end
end
