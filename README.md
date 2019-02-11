# DraftApprove

DraftApprove is a Ruby gem which lets you save draft changes of your ActiveRecord models to your database. It allows grouping of related changes into a 'Draft Transaction' which must be approved or rejected as a whole, rather than allowing individual draft changes to be applied independently.

There are a number of other similar Ruby gems available for drafting changes to ActiveRecord models. Depending upon your projects needs, another gem may be more suitable. See the [Alternative Drafting Gems](#alternative-drafting-gems) section for full details.

The specific features / functionality offered by DraftApprove are:

* No changes are needed to your existing database tables
* No updates are required to your existing ActiveRecord queries or raw SQL queries
* It is possible to save drafts of new records, save draft changes to existing records, and save draft deletions of records
* Multiple related draft changes (new records, updates, deletions) may be grouped together in a 'Draft Transaction' which must then be approved or rejected as a whole
  * This includes being able to save a draft of a model which references an _unsaved_ model - as long as that unsaved model already has a draft
* Each model may only have one pending draft at a time

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'draft_approve'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install draft_approve

Once installed, you must generate the migration to create the required draft tables in your database, and run the migration:

```
$ rails generate draft_approve:migration
$ rails db:migrate
```

## Usage

### Make your Models draftable

Add `acts_as_draftable` to all models you'd like to be draftable. For example:

```ruby
# app/models/person.rb
class Person < ActiveRecord::Base
  has_many :contact_addresses

  acts_as_draftable
end

# app/models/contact_address.rb
class ContactAddress < ActiveRecord::Base
  belongs_to :person

  acts_as_draftable
end
```

### Create a draft for a single object

Call `draft_save!` to save a draft of a new model, or save draft changes to an existing model.

Call `draft_destroy!` to draft the deletion of the model.

There are also convenience methods `draft_create!` and `draft_update!`.

For example:

```ruby
### CREATE EXAMPLES

# Save draft of a new model
person = Person.new(name: 'new person')
draft = person.draft_save!

# Short-hand to save draft of a new model
draft = Person.draft_create!(name: 'new person')

### UPDATE EXAMPLES

# Save draft changes to an existing person
person = Person.find(1)
person.name = 'update existing person'
draft = person.draft_save!

# Short-hand to save draft changes to an existing person
draft = person.draft_update!(name: 'update existing person')

### DELETE EXAMPLES

# Draft delete an existing person
person = Person.find(2)
draft = person.draft_destroy!
```

### Create multiple related drafts

If you want to ensure multiple related changes are all approved, or all rejected, as a single block, use a Draft Transaction. You do this by calling the `draft_transaction` method on any draftable model class, and passing it a block where all your drafts are saved. You use the same `draft_save!` and `draft_destroy!` methods within the Draft Transaction.

For example:

```ruby
draft_transaction = Person.draft_transaction do
  # Want reference to person object, so don't use shorthand draft_create! method
  person = Person.new(name: 'new person name')
  person.draft_save!

  existing_contact_address = ContactAddress.find(1)
  existing_contact_address.draft_update!(person: person)

  ContactAddress.find(2).draft_destroy!
end
```

This would create 3 drafts (one to create a new person, one to update an existing contact address, and one to delete a different contact address). These must all be applied together, or all be rejected.

### Approve drafts

Regardless of how a draft was created, a Draft Transaction is always created, and the Draft Transaction is what needs to be approved. This will apply the changes in all drafts within the Draft Transaction (which may only be one draft).

For example:

```ruby
# If you have reference to a Draft object
draft.draft_transaction.approve_changes!(reviewed_by: 'my_username', review_reason: 'Looks Good!')

# If you have reference to a DraftTransaction object
draft_transaction.approve_changes!(reviewed_by: 'my_username', review_reason: 'Looks Good!')
```

### Reject drafts

This will reject all changes in all drafts within the Draft Transaction (which may only be one draft).

For example:

```ruby
# If you have reference to a Draft object
draft.draft_transaction.reject_changes!(reviewed_by: 'my_username', review_reason: 'Nope!')

# If you have reference to a DraftTransaction object
draft_transaction.reject_changes!(reviewed_by: 'my_username', review_reason: 'Nope!')
```

### Find drafts pending approval

As discussed, all drafts are created inside a Draft Transaction, and it is these which must be approved or rejected.

You can find all Draft Transactions with a particular status using the following methods:

```ruby
pending_draft_transactions = DraftTransaction.pending_approval

approved_draft_transactions = DraftTransaction.approved

rejected_draft_transactions = DraftTransaction.rejected
```

### Errors

If an error occurs while approving a transaction, the error will cause the transaction to fail, so none of the draft changes will be applied. The Draft Transaction will have its `status` set to `approval_error`, and its `error` column will contain more information (the error and the backtrace).

All Draft Transactions with an error can be found using the following:

```ruby
errored_draft_transactions = DraftTransaction.approval_error
```

### Advanced usage

#### Who created a draft?

When creating a Draft Transaction, you may pass in a `created_by` string. This could be a username or the name of an automated process, and will be stored in the `DraftTransaction.created_by` column in the database. This option is only available when saving drafts within an explicit Draft Transaction.

For example:

```ruby
draft_transaction = Person.draft_transaction(created_by: 'UserA') do
  Person.new(name: 'new person name').draft_save!
end
```

#### Extra metadata for drafts

When creating a Draft Transaction, you may pass in an `extra_data` hash. This can contain anything, and will be stored in the `DraftTransaction.extra_data` column in the database. This option is only available when saving drafts within an explicit Draft Transaction.

Possible use-cases for the extra data hash are storing which users or roles are allowed to approve these drafts, storing additional data about why or how the drafts were created, etc. The DraftApprove gem does not implement these features for you (eg. limiting who can approve drafts), but simply gives you a way to store generic metadata about a Draft Transaction should you wish to build such features within your application logic.

For example:

```ruby
extra_data = {
  'can_be_approved_by' => ['SuperAdminRole', 'UserB'],
  'data_source_url' => 'https://en.wikipedia.org/wiki/RubyGems',
  'data_scraped_at' => '2019-02-08 12:00:00'
}

draft_transaction = Person.draft_transaction(extra_data: extra_data) do
  Person.new(name: 'new person name').draft_save!
end
```

#### Custom methods for creating, updating and deleting data

When a Draft Transaction is approved, all drafts within the transaction are applied, meaning the changes within the draft are made live on the database. This is acheived by calling suitable ActiveRecord methods. The default methods used by the DraftApprove gem are:

* `create!` for new models saved with `draft_save!`
* `update!` for existing models which have been modified and saved with `draft_save!`
* `destroy!` for models which have had `draft_destroy!` called on them

Note that `create!` is a _class_ level ActiveRecord method, while `update!` and `destroy!` are _instance_ level ActiveRecord methods.

When saving drafts, you may override the method used to save the changes by passing an options hash to the `draft_save!` or `draft_destroy!` methods. You are not able to do this with the convenience `draft_create!` or `draft_update!` methods.

For example:

```ruby
draft_transaction = Person.draft_transaction do
  # When approved, find or create Person A
  person = Person.new(name: 'Person A')
  person.draft_save!(create_method: :find_or_create_by!)
  
  # When approved, update the record ignoring validations
  existing_person = Person.find(1)
  existing_person.birth_date = '1800-01-01'
  existing_person.draft_save!(update_method: :update_columns)

  # When approved, delete the record directly in the database without any ActiveRecord callbacks
  Person.find(2).draft_destroy!(delete_method: :delete)
end
```

**CAUTION**
* No validation is done to check you are using sensible alternative methods, so use at your own risk!
* **It is strongly recommended to use methods which will raise an error if they fail**, otherwise one draft in a Draft Transaction may 'silently' fail, causing subsequent drafts to be applied, and the Draft Transaction as a whole may appear to have been successfully approved & applied
* Methods used as the `create_method` **must** be _class_ methods for the model you are drafting, which accept a hash of attribute names to attribute values (eg. `Person.create!`, `Person.find_or_create_by!`, etc)
* Methods used as the `update_method` **must** be _instance_ methods for the model you are drafting, which accept a hash of attribute names to attribute values (eg. `person.update!`, `person.update_attributes!`, etc)
* Methods used as the `delete_method` **must** be _instance_ methods for the model you are drafting, which requires no arguments (eg. `person.destroy!`, `person.delete`, etc)

### More examples

Further examples can be seen in the [integration tests](spec/integration).

## Alternative Drafting Gems

* [Drafting](https://github.com/ledermann/drafting)
* [DraftPunk](https://github.com/stevehodges/draftpunk)
* [Draftsman](https://github.com/jmfederico/draftsman)

**DraftPunk** and **Draftsman** both require changes to your existing database tables. In itself, this is not a problem, however this also _potentially_ requires changes to your ActiveRecord Queries and any raw SQL you may be executing in order to ensure draft models or draft changes are not accidentally returned by queries or shown to end users.

This problem can be avoided using default scopes on your models. This may be a suitable solution for new projects, or projects which don't utilise much or any raw SQL queries.

See the [DraftPunk documentation](https://github.com/stevehodges/draftpunk#what-about-the-rest-of-the-application-people-are-seeing-draft-businesses) and [Draftsman documentation](https://github.com/jmfederico/draftsman#drafted-item-scopes) on using scopes.

**Drafting** does not require any modifications to existing tables, and therefore has no risk of existing queries accidentally returning draft data. However, [it only allows saving drafts on records which are not persisted yet](https://github.com/ledermann/drafting#hints). This may be suitable for projects where it is not necessary to create and approve draft updates to objects.

All the above gem also have other specific features / advantages unique to them, so before selecting the most suitable gem for your needs, it is recommended you read their documentation and trial them to find which is most suited to your project requirements.

## License

[MIT License](LICENSE.md)

Copyright (c) 2019, 38 Degrees Ltd

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. Alternatively you may run `gem build draft_approve.gemspec` to generate the `.gem` file, then run `gem install ./draft_approve-0.1.0.gem` (replace `0.1.0` with the correct gem version).

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/38dgs/draft_approve. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the DraftApprove project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/38dgs/draft_approve/blob/master/CODE_OF_CONDUCT.md).
