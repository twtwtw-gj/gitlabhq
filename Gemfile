# frozen_string_literal: true

source 'https://rubygems.org'

if ENV['BUNDLER_CHECKSUM_VERIFICATION_OPT_IN'] # this verification is still experimental
  $:.unshift(File.expand_path("vendor/gems/bundler-checksum/lib", __dir__))
  require 'bundler-checksum'
  Bundler::Checksum.patch!
end

gem 'bundler-checksum', '~> 0.1.0', path: 'vendor/gems/bundler-checksum', require: false

# NOTE: When incrementing the major or minor version here, also increment activerecord_version
# in vendor/gems/attr_encrypted/attr_encrypted.gemspec until we resolve
# https://gitlab.com/gitlab-org/gitlab/-/issues/375713
gem 'rails', '~> 6.1.6.1'

gem 'bootsnap', '~> 1.13.0', require: false

# Pin openssl to match the version bundled with our supported Rubies.
# See https://stdgems.org/openssl/#gem-version.
gem 'openssl', '2.2.1'
# This gem was originally bundled with Ruby 2.7, but is unbundled as of Ruby 3.
# Since the latest version caused problems with GitLab, we pin this to an older
# version for now.
# See https://gitlab.com/gitlab-org/gitlab/-/issues/376417
gem 'ipaddr', '1.2.2'

# Responders respond_to and respond_with
gem 'responders', '~> 3.0'

gem 'sprockets', '~> 3.7.0'

gem 'view_component', '~> 2.71.0'

# Default values for AR models
gem 'default_value_for', '~> 3.4.0'

# Supported DBs
gem 'pg', '~> 1.4.3'

gem 'rugged', '~> 1.2'
gem 'grape-path-helpers', '~> 1.7.1'

gem 'faraday', '~> 1.0'
gem 'marginalia', '~> 1.10.0'

# Authorization
gem 'declarative_policy', '~> 1.1.0'

# Authentication libraries
gem 'devise', '~> 4.8.1'
gem 'devise-pbkdf2-encryptable', '~> 0.0.0', path: 'vendor/gems/devise-pbkdf2-encryptable'
gem 'bcrypt', '~> 3.1', '>= 3.1.14'
gem 'doorkeeper', '~> 5.5.0.rc2'
gem 'doorkeeper-openid_connect', '~> 1.7.5'
gem 'rexml', '~> 3.2.5'
gem 'ruby-saml', '~> 1.13.0'
gem 'omniauth', '~> 2.1.0'
gem 'omniauth-auth0', '~> 2.0.0'
gem 'omniauth-azure-activedirectory-v2', '~> 1.0'
gem 'omniauth-azure-oauth2', '~> 0.0.9', path: 'vendor/gems/omniauth-azure-oauth2' # See gem README.md
gem 'omniauth-cas3', '~> 1.1.4', path: 'vendor/gems/omniauth-cas3' # See vendor/gems/omniauth-cas3/README.md
gem 'omniauth-dingtalk-oauth2', '~> 1.0'
gem 'omniauth-alicloud', '~> 1.0.1'
gem 'omniauth-facebook', '~> 4.0.0'
gem 'omniauth-github', '2.0.0'
gem 'omniauth-gitlab', '~> 4.0.0', path: 'vendor/gems/omniauth-gitlab' # See vendor/gems/omniauth-gitlab/README.md
gem 'omniauth-google-oauth2', '~> 1.0.1', path: 'vendor/gems/omniauth-google-oauth2' # See gem README.md
gem 'omniauth-oauth2-generic', '~> 0.2.2'
gem 'omniauth-saml', '~> 2.0.0'
gem 'omniauth-shibboleth', '~> 1.3.0'
gem 'omniauth-twitter', '~> 1.4'
gem 'omniauth_crowd', '~> 2.4.0', path: 'vendor/gems/omniauth_crowd' # See vendor/gems/omniauth_crowd/README.md
gem 'omniauth-authentiq', '~> 0.3.3'
gem 'gitlab-omniauth-openid-connect', '~> 0.10.0', require: 'omniauth_openid_connect'
gem 'omniauth-salesforce', '~> 1.0.5', path: 'vendor/gems/omniauth-salesforce' # See gem README.md
gem 'omniauth-atlassian-oauth2', '~> 0.2.0'
gem 'rack-oauth2', '~> 1.21.3'
gem 'jwt', '~> 2.1.0'

# Kerberos authentication. EE-only
gem 'gssapi', group: :kerberos
gem 'timfel-krb5-auth', '~> 0.8', group: :kerberos

# Spam and anti-bot protection
gem 'recaptcha', '~> 4.11', require: 'recaptcha/rails'
gem 'akismet', '~> 3.0'
gem 'invisible_captcha', '~> 1.1.0'

# Two-factor authentication
gem 'devise-two-factor', '~> 4.0.2'
gem 'rqrcode-rails3', '~> 0.1.7'
gem 'attr_encrypted', '~> 3.2.4', path: 'vendor/gems/attr_encrypted'
gem 'u2f', '~> 0.2.1'

# GitLab Pages
gem 'validates_hostname', '~> 1.0.11'
gem 'rubyzip', '~> 2.3.2', require: 'zip'
# GitLab Pages letsencrypt support
gem 'acme-client', '~> 2.0'

# Browser detection
gem 'browser', '~> 4.2'

# OS detection for usage ping
gem 'ohai', '~> 16.10'

# GPG
gem 'gpgme', '~> 2.0.19'

# LDAP Auth
# GitLab fork with several improvements to original library. For full list of changes
# see https://github.com/intridea/omniauth-ldap/compare/master...gitlabhq:master
gem 'gitlab_omniauth-ldap', '~> 2.2.0', require: 'omniauth-ldap'
gem 'net-ldap', '~> 0.16.3'

# API
gem 'grape', '~> 1.5.2'
gem 'grape-entity', '~> 0.10.0'
gem 'rack-cors', '~> 1.1.1', require: 'rack/cors'

# GraphQL API
gem 'graphql', '~> 1.13.12'
gem 'graphiql-rails', '~> 1.8'
gem 'apollo_upload_server', '~> 2.1.0'
gem 'graphql-docs', '~> 2.1.0', group: [:development, :test]
gem 'graphlient', '~> 0.5.0' # Used by BulkImport feature (group::import)

gem 'hashie'
# Disable strong_params so that Mash does not respond to :permitted?
gem 'hashie-forbidden_attributes'

# Pagination
gem 'kaminari', '~> 1.0'

# HAML
gem 'hamlit', '~> 2.15.0'

# Files attachments
gem 'carrierwave', '~> 1.3'
gem 'mini_magick', '~> 4.10.1'

# for backups
gem 'fog-aws', '~> 3.14'
# Locked until fog-google resolves https://github.com/fog/fog-google/issues/421.
# Also see config/initializers/fog_core_patch.rb.
gem 'fog-core', '= 2.1.0'
gem 'fog-google', '~> 1.15', require: 'fog/google'
gem 'fog-local', '~> 0.6'
gem 'fog-openstack', '~> 1.0'
gem 'fog-rackspace', '~> 0.1.1'
gem 'fog-aliyun', '~> 0.3'
gem 'gitlab-fog-azure-rm', '~> 1.3.0', require: 'fog/azurerm'

# for Google storage
gem 'google-api-client', '~> 0.33'

# for aws storage
gem 'unf', '~> 0.1.4'

# Seed data
gem 'seed-fu', '~> 2.3.7'

# Search
gem 'elasticsearch-model', '~> 7.2'
gem 'elasticsearch-rails', '~> 7.2', require: 'elasticsearch/rails/instrumentation'
gem 'elasticsearch-api',   '7.13.3'
gem 'aws-sdk-core', '~> 3.159.0'
gem 'aws-sdk-cloudformation', '~> 1'
gem 'aws-sdk-s3', '~> 1.114.0'
gem 'faraday_middleware-aws-sigv4', '~>0.3.0'
gem 'typhoeus', '~> 1.4.0' # Used with Elasticsearch to support http keep-alive connections

# Markdown and HTML processing
gem 'html-pipeline', '~> 2.13.2'
gem 'deckar01-task_list', '2.3.1'
gem 'gitlab-markup', '~> 1.8.0'
gem 'github-markup', '~> 1.7.0', require: 'github/markup'
gem 'commonmarker', '~> 0.23.6'
gem 'kramdown', '~> 2.3.1'
gem 'RedCloth', '~> 4.3.2'
gem 'rdoc', '~> 6.3.2'
gem 'org-ruby', '~> 0.9.12'
gem 'creole', '~> 0.5.0'
gem 'wikicloth', '0.8.1'
gem 'asciidoctor', '~> 2.0.17'
gem 'asciidoctor-include-ext', '~> 0.4.0', require: false
gem 'asciidoctor-plantuml', '~> 0.0.16'
gem 'asciidoctor-kroki', '~> 0.5.0', require: false
gem 'rouge', '~> 3.30.0'
gem 'truncato', '~> 0.7.12'
gem 'bootstrap_form', '~> 4.2.0'
gem 'nokogiri', '~> 1.13.8'
gem 'escape_utils', '~> 1.1'

# Calendar rendering
gem 'icalendar'

# Diffs
gem 'diffy', '~> 3.4'
gem 'diff_match_patch', '~> 0.1.0'

# Application server
gem 'rack', '~> 2.2.4'
# https://github.com/zombocom/rack-timeout/blob/master/README.md#rails-apps-manually
gem 'rack-timeout', '~> 0.6.3', require: 'rack/timeout/base'

group :puma do
  gem 'puma', '~> 5.6.5', require: false
  gem 'puma_worker_killer', '~> 0.3.1', require: false
  gem 'sd_notify', '~> 0.1.0', require: false
end

# State machine
gem 'state_machines-activerecord', '~> 0.8.0'

# CI domain tags
gem 'acts-as-taggable-on', '~> 9.0'

# Background jobs
gem 'sidekiq', '~> 6.4.0'
gem 'sidekiq-cron', '~> 1.8.0'
gem 'redis-namespace', '~> 1.9.0'
gem 'gitlab-sidekiq-fetcher', '0.8.0', require: 'sidekiq-reliable-fetch'

# Cron Parser
gem 'fugit', '~> 1.2.1'

# HTTP requests
gem 'httparty', '~> 0.16.4'

# Colored output to console
gem 'rainbow', '~> 3.0'

# Progress bar
gem 'ruby-progressbar', '~> 1.10'

# GitLab settings
gem 'settingslogic', '~> 2.0.9'

# Linear-time regex library for untrusted regular expressions
gem 're2', '~> 1.4.0'

# Misc

gem 'version_sorter', '~> 2.2.4'

# Export Ruby Regex to Javascript
gem 'js_regex', '~> 3.7'

# User agent parsing
gem 'device_detector'

# Redis
gem 'redis', '~> 4.7.0'
gem 'connection_pool', '~> 2.0'

# Redis session store
gem 'redis-actionpack', '~> 5.3.0'

# Discord integration
gem 'discordrb-webhooks', '~> 3.4', require: false

# Jira integration
gem 'jira-ruby', '~> 2.1.4'
gem 'atlassian-jwt', '~> 0.2.0'

# Flowdock integration
gem 'flowdock', '~> 0.7'

# Slack integration
gem 'slack-messenger', '~> 2.3.4'

# Hangouts Chat integration
gem 'hangouts-chat', '~> 0.0.5', require: 'hangouts_chat'

# Asana integration
gem 'asana', '~> 0.10.13'

# FogBugz integration
gem 'ruby-fogbugz', '~> 0.2.1'

# Kubernetes integration
gem 'kubeclient', '~> 4.9.3'

# Sanitize user input
gem 'sanitize', '~> 6.0'
gem 'babosa', '~> 1.0.4'

# Sanitizes SVG input
gem 'loofah', '~> 2.19.0'

# Working with license
# Detects the open source license the repository includes
# This version needs to be in sync with gitlab-org/gitaly
gem 'licensee', '~> 9.15'

# Detect and convert string character encoding
gem 'charlock_holmes', '~> 0.7.7'

# Detect mime content type from content
gem 'ruby-magic', '~> 0.5'

# Faster blank
gem 'fast_blank'

# Parse time & duration
gem 'gitlab-chronic', '~> 0.10.5'
gem 'gitlab_chronic_duration', '~> 0.10.6.2'

gem 'rack-proxy', '~> 0.7.4'

gem 'sassc-rails', '~> 2.1.0'
gem 'autoprefixer-rails', '10.2.5.1'
gem 'terser', '1.0.2'

gem 'addressable', '~> 2.8'
gem 'tanuki_emoji', '~> 0.6'
gem 'gon', '~> 6.4.0'
gem 'request_store', '~> 1.5'
gem 'base32', '~> 0.3.0'

gem 'gitlab-license', '~> 2.2.1'

# Protect against bruteforcing
gem 'rack-attack', '~> 6.6.1'

# Sentry integration
gem 'sentry-raven', '~> 3.1'
gem 'sentry-ruby', '~> 5.1.1'
gem 'sentry-rails', '~> 5.1.1'
gem 'sentry-sidekiq', '~> 5.1.1'

# PostgreSQL query parsing
#
gem 'pg_query', '~> 2.1.4'

gem 'premailer-rails', '~> 1.10.3'

# LabKit: Tracing and Correlation
gem 'gitlab-labkit', '~> 0.24.0'
gem 'thrift', '>= 0.16.0'

# I18n
gem 'ruby_parser', '~> 3.15', require: false
gem 'rails-i18n', '~> 7.0'
gem 'gettext_i18n_rails', '~> 1.8.0'
gem 'gettext_i18n_rails_js', '~> 1.3'
gem 'gettext', '~> 3.3', require: false, group: :development

gem 'batch-loader', '~> 2.0.1'

# Perf bar
gem 'peek', '~> 1.1'

# Snowplow events tracking
gem 'snowplow-tracker', '~> 0.6.1'

# Metrics
gem 'webrick', '~> 1.6.1', require: false
gem 'prometheus-client-mmap', '~> 0.16', require: 'prometheus/client'

gem 'warning', '~> 1.3.0'

group :development do
  gem 'lefthook', '~> 1.1.2', require: false
  gem 'rubocop'
  gem 'solargraph', '~> 0.47.2', require: false

  gem 'letter_opener_web', '~> 2.0.0'
  gem 'lookbook', '~> 1.0', '>= 1.0.8'

  # Better errors handler
  gem 'better_errors', '~> 2.9.1'

  gem 'sprite-factory', '~> 1.7'
end

group :development, :test do
  gem 'deprecation_toolkit', '~> 1.5.1', require: false
  gem 'bullet', '~> 7.0.2'
  gem 'pry-byebug'
  gem 'pry-rails', '~> 0.3.9'
  gem 'pry-shell', '~> 0.5.1'

  gem 'awesome_print', require: false

  gem 'database_cleaner', '~> 1.7.0'
  gem 'factory_bot_rails', '~> 6.2.0'
  gem 'rspec-rails', '~> 5.0.1'

  # Prevent occasions where minitest is not bundled in packaged versions of ruby (see #3826)
  gem 'minitest', '~> 5.11.0'

  # Generate Fake data
  gem 'ffaker', '~> 2.10'

  gem 'spring', '~> 2.1.0'
  gem 'spring-commands-rspec', '~> 1.0.4'

  gem 'gitlab-styles', '~> 9.0.0', require: false

  gem 'haml_lint', '~> 0.40.0', require: false
  gem 'bundler-audit', '~> 0.7.0.1', require: false

  # Benchmarking & profiling
  gem 'benchmark-ips', '~> 2.3.0', require: false
  gem 'benchmark-memory', '~> 0.1', require: false

  gem 'knapsack', '~> 1.21.1'
  gem 'crystalball', '~> 0.7.0', require: false

  gem 'simple_po_parser', '~> 1.1.6', require: false

  gem 'timecop', '~> 0.9.1'

  gem 'png_quantizator', '~> 0.2.1', require: false

  gem 'parallel', '~> 1.19', require: false

  gem 'test_file_finder', '~> 0.1.3'

  gem 'sigdump', '~> 0.2.4', require: 'sigdump/setup'

  gem 'pact', '~> 1.12'
end

group :development, :test, :danger do
  gem 'gitlab-dangerfiles', '~> 3.5.2', require: false
end

group :development, :test, :coverage do
  gem 'simplecov', '~> 0.21', require: false
  gem 'simplecov-lcov', '~> 0.8.0', require: false
  gem 'simplecov-cobertura', '~> 1.3.1', require: false
  gem 'undercover', '~> 0.4.4', require: false
end

# Gems required in omnibus-gitlab pipeline
group :development, :test, :omnibus do
  gem 'license_finder', '~> 7.0', require: false
end

group :test do
  gem 'fuubar', '~> 2.2.0'
  gem 'rspec-retry', '~> 0.6.1'
  gem 'rspec_profiling', '~> 0.0.6'
  gem 'rspec-benchmark', '~> 0.6.0'
  gem 'rspec-parameterized', require: false

  gem 'capybara', '~> 3.35.3'
  gem 'capybara-screenshot', '~> 1.0.22'
  gem 'selenium-webdriver', '~> 3.142'

  gem 'graphlyte', '~> 1.0.0'

  gem 'shoulda-matchers', '~> 5.1.0', require: false
  gem 'email_spec', '~> 2.2.0'
  gem 'webmock', '~> 3.9.1'
  gem 'rails-controller-testing'
  gem 'concurrent-ruby', '~> 1.1'
  gem 'test-prof', '~> 1.0.7'
  gem 'rspec_junit_formatter'
  gem 'guard-rspec'

  # Moved in `test` because https://gitlab.com/gitlab-org/gitlab/-/issues/217527
  gem 'derailed_benchmarks', require: false
end

gem 'octokit', '~> 4.15'

# Updating this gem version here is deprecated. See:
# https://docs.gitlab.com/ee/development/emails.html#mailroom-gem-updates
gem 'gitlab-mail_room', '~> 0.0.9', require: 'mail_room'

gem 'email_reply_trimmer', '~> 0.1'
gem 'html2text'

gem 'ruby-prof', '~> 1.3.0'
gem 'stackprof', '~> 0.2.21', require: false
gem 'rbtrace', '~> 0.4', require: false
gem 'memory_profiler', '~> 0.9', require: false
gem 'activerecord-explain-analyze', '~> 0.1', require: false

# OAuth
gem 'oauth2', '~> 2.0'

# Health check
gem 'health_check', '~> 3.0'

# System information
gem 'vmstat', '~> 2.3.0'
gem 'sys-filesystem', '~> 1.4.3'

# NTP client
gem 'net-ntp'

# SSH keys support
gem 'ssh_data', '~> 1.3'

# Spamcheck GRPC protocol definitions
gem 'spamcheck', '~> 1.0.0'

# Gitaly GRPC protocol definitions
gem 'gitaly', '~> 15.4.0-rc2'

# KAS GRPC protocol definitions
gem 'kas-grpc', '~> 0.0.2'

gem 'grpc', '~> 1.42.0'

gem 'google-protobuf', '~> 3.21'

gem 'toml-rb', '~> 2.0'

# Feature toggles
gem 'flipper', '~> 0.25.0'
gem 'flipper-active_record', '~> 0.25.0'
gem 'flipper-active_support_cache_store', '~> 0.25.0'
gem 'unleash', '~> 3.2.2'
gem 'gitlab-experiment', '~> 0.7.1'

# Structured logging
gem 'lograge', '~> 0.5'
gem 'grape_logging', '~> 1.8'

# DNS Lookup
gem 'gitlab-net-dns', '~> 0.9.1'

# Countries list
gem 'countries', '~> 3.0'

gem 'retriable', '~> 3.1.2'

# LRU cache
gem 'lru_redux'

# Locked as long as quoted-printable encoding issues are not resolved
# Monkey-patched in `config/initializers/mail_encoding_patch.rb`
# See https://gitlab.com/gitlab-org/gitlab/issues/197386
gem 'mail', '= 2.7.1'
gem 'mail-smtp_pool', '~> 0.1.0', path: 'vendor/gems/mail-smtp_pool', require: false

gem 'microsoft_graph_mailer', '~> 0.1.0', path: 'vendor/gems/microsoft_graph_mailer'

# File encryption
gem 'lockbox', '~> 0.6.2'

# Email validation
gem 'valid_email', '~> 0.1'

# JSON
gem 'json', '~> 2.5.1'
gem 'json_schemer', '~> 0.2.18'
gem 'oj', '~> 3.13.21'
gem 'multi_json', '~> 1.14.1'
gem 'yajl-ruby', '~> 1.4.3', require: 'yajl'

gem 'webauthn', '~> 2.3'

# IPAddress utilities
gem 'ipaddress', '~> 0.8.3'

gem 'parslet', '~> 1.8'

gem 'ipynbdiff', path: 'vendor/gems/ipynbdiff'

gem 'ed25519', '~> 1.3.0'

# Error Tracking OpenAPI client
# See https://gitlab.com/gitlab-org/gitlab/-/blob/master/doc/development/rake_tasks.md#update-openapi-client-for-error-tracking-feature
gem 'error_tracking_open_api', path: 'vendor/gems/error_tracking_open_api'

# Vulnerability advisories
gem 'cvss-suite', '~> 3.0.1', require: 'cvss_suite'

# Work with RPM packages
gem 'arr-pm', '~> 0.0.12'
