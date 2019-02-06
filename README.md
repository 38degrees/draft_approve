# DraftApprove

DraftApprove is a Ruby gem which lets you save draft changes of your ActiveRecord models to your database. It allows grouping of related changes into a 'Draft Transaction' which must be approved or rejected as a whole, rather than allowing individual draft changes to be applied independently.

There are a number of other similar Ruby gems available for drafting changes to ActiveRecord models. Depending upon your projects needs, another gem may be more suitable. See the [Alternative Drafting Gems](#alternative-drafting-gems) section for full details.

The specific features / functionality offered by DraftApprove are:

* No changes are needed to your existing database tables
* No updates are required to your existing ActiveRecord queries or raw SQL queries
* It is possible to save drafts of new records, save draft changes to existing records, and save draft deletions of records
* Multiple related draft changes (new records, updates, deletions) may be grouped together in a 'Draft Transaction' which must then be approved or rejected as a whole
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

Add `has_drafts` to all models you'd like to be draftable. For example:

```
# app/models/person.rb
class Person < ActiveRecord::Base
  has_many :contact_addresses

  has_drafts
end

# app/models/contact_address.rb
class ContactAddress < ActiveRecord::Base
  belongs_to :person

  has_drafts
end
```

### Create a draft for a single object

Call `save_draft!` to save a draft of a new model, or save draft changes to an existing model.

Call `draft_destroy!` to draft the deletion of the model.

For example:

```
# Save draft of a new model
person = Person.new(name: 'new person')
draft = person.save_draft!

# Save draft changes to an existing person
person = Person.find(1)
person.name = 'update existing person'
draft = person.save_draft!

# Draft delete an existing person
person = Person.find(2)
draft = person.draft_destroy!
```

### Create multiple related drafts

If you want to ensure multiple related changes are all approved, or all rejected, as a single block, use a Draft Transaction. You do this by calling the `draft_transaction` method on any draftable model class, and passing it a block where all your drafts are saved. You use the same `save_draft!` and `draft_destroy!` methods within the Draft Transaction.

For example:

```
draft_transaction = Person.draft_transaction do
  person = Person.find(1)
  person.name = 'update person name'
  person.save_draft!
  
  contact_address = person.contact_addresses.first
  contact_address.draft_destroy!
  
  ContactAddress.new(person: person, label: 'email', value: 'email@test.com').save_draft!
end
```

This would create 3 drafts (one to update the person, one to delete the existing contact address, and one to create a new contact address). These must all be applied together, or all be rejected.

### Approve drafts

Regardless of how a draft was created, a Draft Transaction is always created, and the Draft Transaction is what needs to be approved. This will apply the changes in all drafts within the Draft Transaction (which may only be one draft).

For example:

```
# If you have reference to a Draft object
draft.draft_transaction.approve_changes

# If you have reference to a DraftTransaction object
draft_transaction.approve_changes
```

## Alternative Drafting Gems

* [Drafting](https://github.com/ledermann/drafting)
* [DraftPunk](https://github.com/stevehodges/draftpunk)
* [Draftsman](https://github.com/jmfederico/draftsman)

**DraftPunk** and **Draftsman** both require changes to your existing database tables. In itself, this is not a problem, however this also _potentially_ requires changes to your ActiveRecord Queries and any raw SQL you may be executing in order to ensure draft models or draft changes are not accidentally returned by queries or shown to end users.

This problem can be avoided using default scopes on your models. This may be a suitable solution for new projects, or projects which don't utilise much or any raw SQL queries.

See the [DraftPunk documentation](https://github.com/stevehodges/draftpunk#what-about-the-rest-of-the-application-people-are-seeing-draft-businesses) and [Draftsman documentation](https://github.com/jmfederico/draftsman#drafted-item-scopes) on using scopes.

**Drafting** does not require any modifications to existing tables, and therefore has no risk of existing queries accidentally returning draft data. However, [it only allows saving drafts on records which are not persisted yet](https://github.com/ledermann/drafting#hints). This may be suitable for projects where it is not necessary to create and approve draft updates to objects.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/draft_approve. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the DraftApprove project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/draft_approve/blob/master/CODE_OF_CONDUCT.md).
