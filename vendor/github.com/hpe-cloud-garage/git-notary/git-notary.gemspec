Gem::Specification.new do |gem|
  gem.name     = 'git-notary'
  gem.version  = `git describe --tags --abbrev=0`.chomp
  gem.license  = 'MIT'
  gem.author   = 'Chris Olstrom'
  gem.email    = 'chris@olstrom.com'
  gem.homepage = 'https://github.com/colstrom/git-notary'
  gem.summary  = 'generates canonical version tags from versioning notes'
  gem.files    = `git ls-files`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
end
