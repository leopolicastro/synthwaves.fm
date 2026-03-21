# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Tests", "bundle exec rspec"
  step "Lint", "bundle exec standardrb"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
end
