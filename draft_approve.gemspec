
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'draft_approve/version'

Gem::Specification.new do |spec|
  spec.name          = 'draft_approve'
  spec.version       = DraftApprove::VERSION
  spec.authors       = ['Andrew Sibley']
  spec.email         = ['andrew.s@38degrees.org.uk']

  spec.homepage      = 'https://github.com/38dgs/draft_approve'
  spec.summary       = %q{Save drafts of ActiveRecord models & approve them to apply the changes.}
  spec.description   = %q{
    All draft data is saved in a separate table, so no need to worry about
    existing code / SQL accidentally finding non-approved data. Supports draft
    changes to existing objects, and creating new objects as drafts. Supports
    'draft transactions' which may update / create many objects, and must be
    approved / rejected in their entirety.
  }

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/38dgs/draft_approve'
    spec.metadata['changelog_uri'] = 'https://github.com/38dgs/draft_approve/CHANGELOG.md'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", "~> 5.2"

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "database_cleaner", "~> 1.7"
  spec.add_development_dependency "sqlite3", "~> 1.3"
  spec.add_development_dependency "factory_bot", "~> 4.11"
  spec.add_development_dependency "codecov", "~> 0.1"
  spec.add_development_dependency "appraisal", "~> 2.2"
  spec.add_development_dependency "pry", "~> 0.12"
end
