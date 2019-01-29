require 'rails/generators'
require 'rails/generators/migration'

module DraftApprove
  module Generators
    class MigrationGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path('../templates', __FILE__)

      desc 'Generates the migrations for DraftApprove'

      def create_migration_file
        migration_template(
          'create_draft_approve_tables.rb',
          'db/migrate/create_draft_approve_tables.rb',
          { migration_version: migration_version, json_type: json_type }
        )
      end

      def self.next_migration_number(path)
        next_migration_number = current_migration_number(path) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end

      def json_type
        if ActiveRecord::Base.connection.adapter_name.downcase.to_sym == :postgresql
          'jsonb'
        else
          'json'
        end
      end
    end
  end
end
