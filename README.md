# DraftApprove

##### Table of Contents

* [Introduction](#introduction)
* [Installation](#installation)
* [Usage](#usage)
* [Compatibility](#compatibility)
* [Frequently Asked Questions](#images)
* [Alternative Drafting Gems](#code)
* [License](#license)
* [Development](#development)
* [Contributing](#contributing)
* [Code of Conduct](#hr)

## Introduction

DraftApprove is a Ruby gem which lets you save draft changes of your ActiveRecord models to your database. It allows grouping of related changes into a 'Draft Transaction' which must be approved or rejected as a whole, rather than allowing individual draft changes to be applied independently.

There are a number of other similar Ruby gems available for drafting changes to ActiveRecord models. Depending upon your projects needs, another gem may be more suitable. See the [Alternative Drafting Gems](#alternative-drafting-gems) section for full details.

The specific features / functionality offered by DraftApprove are:

* No changes are needed to your existing database tables
* No updates are required to your existing ActiveRecord queries or raw SQL queries
* It is possible to save drafts of new records, save draft updates to existing records, and save draft deletions of records
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
class Person < ActiveRecord::Base
  has_many :contact_addresses
  acts_as_draftable
end

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

#### Skipping validations when saving drafts

By default, models will have their ActiveRecords validations checked before a draft is saved. This prevents invalid drafts from being persisted, which would just fail validation when the Draft Transaction is approved anyway.

_Side note - when saving a draft, only ActiveRecord validations are checked. Since the draft data is not written to your application table, database-only validations cannot be checked!_

If you would like to skip checking ActiveRecord validations when saving a draft, you may pass the `validate: false` option to `draft_save`, for example:

```
person = Person.new
person.draft_save!(validate: false)
```

Validations will still run when the draft is approved, so this option is not especially useful unless combined with a custom method for creating or updating the record (see below).

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

## Compatibility

### Ruby & Active Record versions

DraftApprove has no runtime dependencies aside from Ruby and ActiveRecord. The test suite for DraftApprove tests various combinations of Ruby and ActiveRecord. The table below shows which combinations are known to pass the test suite, and which combinations do not work. Combinations which are not listed below may or may not work - use at your own risk!

|                    |     Ruby 2.6.6     |     Ruby 2.7.2     |     Ruby 3.0.0     |
|               ---: |        :---:       |        :---:       |        :---:       |
| ActiveRecord 2.4.x | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| ActiveRecord 6.0.x | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
| ActiveRecord 6.1.x |       :x: ¹        | :heavy_check_mark: | :heavy_check_mark: |

**Notes**

- ¹ ActiveRecord 6.1.x is not compatible with Ruby 2.6.6 

### Compatible Databases

DraftApprove is currently tested against version 10.6 of the Postgres database. It is expected to work with Postgres versions 10.6 and higher.

Compatibility with other databases has not been tested, but a SQL-compliant database which supports JSON columns will likely work.

Support for database which do not support JSON columns could be added by creating a new `Serialization` module which can serialize, deserialize, and query drafts in another format. Take a look at the existing `DraftApprove::Serialization::Json` module to see what methods are required, and how you might go about this.

## Frequently Asked Questions

### Why am I getting `ActiveRecord::RecordInvalid` errors when I save a draft?

If you wish to purposefully save drafts which do not pass validations, see the [Skipping validations when saving drafts](#skipping-validations-when-saving-drafts) section.

If you are unexpectedly getting `ActiveRecord::RecordInvalid` errors, a _possible_ reason is explicit validations on foreign key columns. For example, the following would fail:

```ruby
class Person < ActiveRecord::Base
  has_many :contact_addresses
  acts_as_draftable
end

class ContactAddress < ActiveRecord::Base
  belongs_to :person
  validates :person_id, presence: true  # This validation is unnecessary and can cause errors
  acts_as_draftable
end

draft_transaction = Person.draft_transaction do
  # Create a new person, and save it as a draft (note, this means p.id is nil!)
  p = Person.new(name: 'person name')
  p.save_draft!

  c = ContactAddress.new(person: p)
  c.save_draft!  # raises ActiveRecord::RecordInvalid because contact_address.person_id is nil
end
```

This can be fixed by removing the explicit `presence: true` validation of foreign key columns. Such validations should not be necessary anyway, because by default `belongs_to` relationships validate the associated object is not `nil`.

_Side note: the `belongs_to` validations do not cause such errors when saving a draft because they check the associated object (eg. `person`) is not `nil` - rather than validating that the component attributes / columns of the association (eg. `person_id`) are not `nil`. In the example above, the `belongs_to` validation would check `contact_address.person` is not `nil`, which it is not - the `Person` object referred to has not been persisted, but it is not `nil`, so the validation passes._

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

Copyright (c) 2019-2021, 38 Degrees Ltd

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Running Tests

**Pre-Requisites**

DraftApprove is primarily concerned with writing data to a database, so you need a local database running to run the tests. Currently the only supported database is Postgres.

You need a postgres installation which the test can connect to using the details in `spec/database.yml`. ie:

- host: localhost
- port: 5432
- database: draft_approve_test
- username: draft_approve_test
- password: draft_approve_test

**Simple Testing**

Run `rake spec` or `bundle exec rspec` to run tests with the current ruby installation, and the currently installed gems.

**Testing with different versions of ActiveRecord**

The CI config for DraftApprove tests the gem against multiple versions of ActiveRecord (ActiveRecord is the only gem which DraftApprove has a runtime dependency on).

You may wish to test with different versions of ActiveRecord locally. Testing different versions of dependencies is made easy by using the [Appraisal gem](https://github.com/thoughtbot/appraisal), which is included as a test dependency. The Appraisal gem runs tests against multiple appraisal definitions, which is a list of dependencies - in our case, just a more specific version of ActiveRecord. You can see the appraisal definitions, and add more, in the `Appraisal` file in the root directory of the project.

Run `bundle exec appraisal install` to install the necessary gems for each appraisal definition.

Run `bundle exec appraisal rspec` to run the tests for every appraisal definition.

Run `bundle exec appraisal <appraisal_definition_name> rspec` to run the tests for a specific appraisal definition - eg. `bundle exec appraisal activerecord-5-2-x rspec`

**Testing with different ruby versions**

The CI config for DraftApprove _also_ tests the gem against multiple versions of Ruby.

If you wish to do this locally, you may simply install another version of Ruby, install gems, and run tests. However, the recommended way to manage this is via [RVM](https://rvm.io/).

With rvm installed, you can install new ruby versions with `rvm install <ruby-version>` - eg. `rvm install 3.0.0`

You can then use `rvm-exec <ruby-version>` to run commands using a specific version of ruby. For example, `rvm-exec 3.0.0 bash -c "bundle exec appraisal install && bundle exec appraisal rspec"` would install the necessary gems for all appraisal definitions, and then run the tests against each appraisal definition, all using version 3.0.0 of ruby.  

### Installing the gem locally

To install this gem onto your local machine, run `bundle exec rake install`. Alternatively you may run `gem build draft_approve.gemspec` to generate the `.gem` file, then run `gem install ./draft_approve-0.1.0.gem` (replace `0.1.0` with the correct gem version).

### Releasing a new version of the gem

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Generating documentation

To generate the YARD documentation locally, run `yard doc`, which will install the documentation into the `doc/` folder.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/38dgs/draft_approve. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the DraftApprove project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/38dgs/draft_approve/blob/master/CODE_OF_CONDUCT.md).
