# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**r_booking** is a Rails 8.1 booking application using modern Rails conventions with Hotwire (Turbo + Stimulus), Tailwind CSS, and Devise authentication with Google OAuth2 integration.

**Tech Stack**:
- Ruby 3.4.7
- Rails 8.1.1
- SQLite3 database
- Solid Queue (background jobs)
- Solid Cache (database-backed caching)
- Solid Cable (WebSocket connections)
- Hotwire (Turbo Rails + Stimulus)
- Tailwind CSS
- Import maps (no Node.js/webpack)
- Devise authentication + OmniAuth (Google OAuth2)
- Kamal for deployment

## Development Commands

### Setup
```bash
bin/setup                    # Initial setup (install deps, setup db)
bin/rails db:migrate         # Run migrations
bin/rails db:seed            # Seed database
```

### Running the Application
```bash
bin/dev                      # Start app with Puma + Tailwind CSS watcher (uses Procfile.dev)
bin/rails server             # Start Puma server only (port 3000)
```

### Testing
```bash
bin/rails test               # Run all tests
bin/rails test:system        # Run system tests only
bin/rails test test/models/user_test.rb              # Run specific test file
bin/rails test test/models/user_test.rb:15           # Run specific test at line
```

### Code Quality
```bash
bin/rubocop                  # Lint with RuboCop (Omakase Ruby style)
bin/rubocop -a               # Auto-correct RuboCop offenses
bin/brakeman                 # Security vulnerability scan
bin/bundler-audit            # Check gems for security vulnerabilities
bin/importmap audit          # Check JavaScript dependencies for vulnerabilities
```

### Database
```bash
bin/rails db:create          # Create database
bin/rails db:reset           # Drop, create, migrate, and seed
bin/rails db:test:prepare    # Prepare test database
bin/rails dbconsole          # Open database console
```

### Assets
```bash
bin/rails tailwindcss:watch  # Watch and compile Tailwind CSS
bin/rails tailwindcss:build  # Build Tailwind CSS for production
bin/importmap pin [package]  # Pin JavaScript package
```

### Console & Debugging
```bash
bin/rails console            # Rails console
bin/kamal console            # Remote console via Kamal
bin/kamal shell              # Remote shell via Kamal
```

### Deployment (Kamal)
```bash
bin/kamal setup              # Initial server setup
bin/kamal deploy             # Deploy application
bin/kamal app logs -f        # Tail application logs
bin/kamal dbc                # Remote database console
```

## Architecture

### Authentication System

**Devise + OmniAuth Integration**: The app uses Devise for authentication with Google OAuth2 as the primary provider. The system is designed to:

1. **OAuth-first approach**: Users can sign in with Google OAuth2
2. **Email unification**: If a user signs in with Google and matches an existing email, it links the accounts
3. **Provider tracking**: `User` model stores `provider` and `uid` for OAuth providers
4. **User attributes**: Stores `name`, `email`, `avatar_url` from OAuth data

**Key files**:
- [config/initializers/devise.rb:43](config/initializers/devise.rb#L43) - OmniAuth provider config (reads from Rails credentials)
- [app/models/user.rb:9-31](app/models/user.rb#L9-L31) - `User.from_omniauth` method handles OAuth callback
- [app/controllers/users/omniauth_callbacks_controller.rb](app/controllers/users/omniauth_callbacks_controller.rb) - OAuth callback handler

**Credentials**: Google OAuth2 credentials stored in encrypted credentials:
- `google_client_id`
- `google_client_secret`

Edit with: `bin/rails credentials:edit`

### Rails 8 Solid Suite

This app uses Rails 8's "Solid" adapters for persistence:

1. **Solid Queue**: Database-backed job queue (runs in Puma process via `SOLID_QUEUE_IN_PUMA=true`)
2. **Solid Cache**: Database-backed caching instead of Redis
3. **Solid Cable**: Database-backed WebSocket connections for Action Cable

**Configuration**: See [config/queue.yml](config/queue.yml), [config/cache.yml](config/cache.yml), [config/cable.yml](config/cable.yml)

**Deployment note**: In production with multiple servers, move job processing to dedicated workers by removing `SOLID_QUEUE_IN_PUMA` and adding job servers in [config/deploy.yml](config/deploy.yml#L11-L14).

### Frontend Architecture

**Hotwire-first approach**: No JavaScript build step, uses Import maps + Turbo + Stimulus.

- **Turbo**: SPA-like navigation without full page reloads
- **Stimulus**: Lightweight JavaScript framework for sprinkles of interactivity
- **Tailwind CSS**: Utility-first CSS framework
- **Import maps**: JavaScript module imports without bundling

**Key files**:
- [config/importmap.rb](config/importmap.rb) - JavaScript dependencies
- [app/javascript/application.js](app/javascript/application.js) - Entry point
- [app/javascript/controllers/](app/javascript/controllers/) - Stimulus controllers
- [app/assets/stylesheets/application.tailwind.css](app/assets/stylesheets/application.tailwind.css) - Tailwind entry

### Database Schema Notes

**User model** has standard Devise columns plus OAuth fields:
- `provider` (string) - OAuth provider name (e.g., 'google_oauth2')
- `uid` (string) - OAuth provider user ID
- `name` (string) - User's full name
- `avatar_url` (string) - User's profile image URL
- `role` (enum) - User role: client (0), owner (1), admin (2)

**Additional gems in use**:
- `friendly_id` - SEO-friendly URLs for businesses/services
- `rqrcode` - QR code generation functionality

Migrations: [db/migrate/](db/migrate/)

### Testing Strategy

- **Minitest** (Rails default) for unit and integration tests
- **Capybara + Selenium WebDriver** for system tests
- **Parallel test execution** enabled by default
- **Fixtures** in [test/fixtures/](test/fixtures/) for test data

CI pipeline runs: security scans (Brakeman, bundler-audit, importmap audit), linting (RuboCop), tests, system tests.

### Deployment

**Kamal deployment** to containerized servers:
- Docker image builds with Ruby 3.4.7
- SQLite database persisted in Docker volume `r_booking_storage`
- Assets served via Propshaft with fingerprinting
- Thruster for HTTP caching/compression and X-Sendfile

**Required secrets** (set in `.kamal/secrets`):
- `RAILS_MASTER_KEY` - For encrypted credentials
- `KAMAL_REGISTRY_PASSWORD` - If using authenticated registry

**Server config**: [config/deploy.yml](config/deploy.yml)

## Important Conventions

### Devise + Turbo Integration

This app uses Rails 8 defaults for Devise + Turbo compatibility:
- Error responses use `:unprocessable_entity` status
- Redirects use `:see_other` status
- See [config/initializers/devise.rb:318-319](config/initializers/devise.rb#L318-L319)

### Code Style

Uses **rubocop-rails-omakase** - Basecamp's Ruby style guide for Rails. Configuration in [.rubocop.yml](.rubocop.yml).

Key style points:
- Single quotes preferred over double quotes
- 2-space indentation
- No frozen string literal comments needed (Ruby 3+)

### Database

Uses **SQLite3** for development, test, and production. Suitable for moderate traffic apps. Database file stored in Docker volume for production persistence.

For high-traffic apps, consider migrating to PostgreSQL or MySQL (see commented accessory in [config/deploy.yml:99-114](config/deploy.yml#L99-L114)).

### Environment Variables

Managed via Rails encrypted credentials (not ENV vars). Edit: `bin/rails credentials:edit`

Exception: Deployment-specific ENV vars in [config/deploy.yml:40-59](config/deploy.yml#L40-L59).

## Common Patterns

### Adding a New OAuth Provider

1. Add gem to Gemfile: `gem 'omniauth-[provider]'`
2. Configure in [config/initializers/devise.rb:43](config/initializers/devise.rb#L43)
3. Add provider to `User` model `omniauth_providers` array
4. Add callback method in [app/controllers/users/omniauth_callbacks_controller.rb](app/controllers/users/omniauth_callbacks_controller.rb)
5. Add credentials: `bin/rails credentials:edit`

**Important**: Do NOT create a separate `config/initializers/omniauth.rb` file - it will conflict with Devise's OmniAuth configuration.

### Adding Background Jobs

Jobs run via Solid Queue. Create with:
```bash
bin/rails generate job ProcessBooking
```

Jobs automatically execute in Puma process (dev/single-server) or dedicated workers (multi-server).

### Adding Stimulus Controllers

```bash
bin/rails generate stimulus [controller_name]
```

Controllers auto-load via [config/importmap.rb](config/importmap.rb) pin.

### Database Migrations

Always test rollback:
```bash
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:migrate
```

Production migrations run automatically during Kamal deployment.
