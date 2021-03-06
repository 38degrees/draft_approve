require 'active_record'
require 'bundler/setup'
require 'database_cleaner'
require 'rake'

require 'draft_approve'

require 'pry'

SPEC_ROOT = Pathname.new(File.expand_path('../', __FILE__))

# require all support files
Dir[SPEC_ROOT.join('support', '*.rb')].each{ |f| require f }

# require all dummy app models
Dir[SPEC_ROOT.join('dummy_app', 'models', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    # Establist SQLite connection
    ActiveRecord::Base.configurations = YAML.load_file(File.expand_path('database.yml', File.dirname(__FILE__)))
    ActiveRecord::Base.establish_connection(:postgres)
    ActiveRecord::Migration.verbose = false

    # Teardown any tables which may be erroneously leftover from previous runs
    database_teardown

    # Load the dummy app schema
    # TODO: Would be better to remove the draft tables from the dummy app schema
    # and generate / run the draft_approve migration here, but we'll worry about
    # that later!
    load SPEC_ROOT.join('dummy_app', 'db', 'schema.rb')

    # Clean the database before/after each test
    # Note we don't use transasaction strategy here because some tests make
    # use of database transactions via DraftApprove::Transaction, and we want to
    # ensure these tests are not contained within an outer database transaction
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.after(:suite) do
    # Teardown tables
    database_teardown
  end
end

# Teardown non-in-memory databases
def database_teardown
  unless [:sqlite].include? ActiveRecord::Base.connection.adapter_name.downcase.to_sym
    conn = ActiveRecord::Base.connection
    conn.tables.each do |table_name|
      conn.execute("DROP TABLE #{table_name} CASCADE")
    end
  end
end
