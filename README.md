# DraftApprove

DraftApprove is a Ruby gem which lets you save draft changes of your ActiveRecord models to your database. It allows grouping of related changes into a 'Draft Transaction' which must be approved or rejected as a whole, rather than allowing individual draft changes to be applied independently.

## Alternative Drafting Gems

There are a number of other similar Ruby gems available for drafting changes to ActiveRecord models. Depending upon your projects needs, another gem may be more suitable. The specific features / functionality offered by DraftApprove are:

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

Once installed, you must generate the migration to create the required draft tables in your database:

    $ rails generate draft_approve:migration

And finally run the new migration:

    $ rails db:migrate

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/draft_approve. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the DraftApprove project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/draft_approve/blob/master/CODE_OF_CONDUCT.md).
