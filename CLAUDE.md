# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**r_booking** is a Rails 8.1 **multi-tenant booking platform** where business owners can offer services and clients can book appointments. The app features subscription-based access for owners (via Moyasar payment gateway), automated QR code generation for bookings, and calendar management.

**Business Model**:
- **Multi-tenancy**: Each business is owned by a user with `owner` role
- **Role-based Access**: Three roles (client, owner, admin) with different permissions
- **Subscription System**: Owners require active subscription (99 SAR/month, 2-week free trial) to create businesses
- **Booking Flow**: Clients browse businesses → select services → book available time slots → receive QR code

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
- Moyasar payment gateway (Saudi Arabia)
- Kamal for deployment

**Additional Gems**:
- `chartkick` + `groupdate` - Dashboard charts and time-based analytics
- `rqrcode` + `chunky_png` - QR code generation for bookings
- `friendly_id` - SEO-friendly URLs for businesses/services
- `faraday` - HTTP client for API integrations

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

### Business Domain & Data Model

**Core Entities** (in hierarchical order):

```
User (client/owner/admin)
  └─ Business (owners only, requires subscription)
      └─ Service (offered by business)
          └─ Booking (client creates, owner manages)
              ├─ CalendarEvent (auto-created for owner)
              └─ QR Code (auto-generated PNG/SVG)
  └─ Subscription (owners only)
```

**Key Relationships**:
- `User` has_many `businesses` (owner role only), `bookings`, `subscriptions`
- `Business` belongs_to `user` (owner), has_many `services`, has_one_attached `logo`, has_many_attached `images`
- `Service` belongs_to `business`, has_many `bookings`
- `Booking` belongs_to `user` (client), belongs_to `service`, has_one `calendar_event`
- `Subscription` belongs_to `user` (owner)

**Role-Based Access Control**:
- **client** (0): Default role, can browse businesses and create bookings
- **owner** (1): Can create businesses (requires active subscription), manage services, view calendar
- **admin** (2): Full system access, no subscription required

**Subscription Logic** ([app/models/user.rb:46-114](app/models/user.rb#L46-L114)):
- Owners need valid subscription to create/manage businesses
- Free 2-week trial on first subscription (no credit card required)
- Monthly subscription: 99 SAR/month via Moyasar
- Admins and clients bypass subscription checks

**Business Hours & Booking Validation** ([app/models/booking.rb:40-79](app/models/booking.rb#L40-L79)):
- Bookings must be within business operating hours (`open_time` - `close_time`)
- Automatic conflict detection prevents double-booking
- Duration calculated from service settings
- End time auto-calculated: `start_time + service.duration`

**QR Code Generation** ([app/models/booking.rb:85-134](app/models/booking.rb#L85-L134)):
- Auto-generated on booking creation
- Stored as PNG in `public/qr_codes/` directory
- Contains: booking_id, user_id, service_id, business_id, start_time, verification_code
- Fallback to SVG if PNG generation fails

**Internationalization**:
- Locale switching route: `GET /locale/:locale`
- Application controller handles locale persistence
- See [config/routes.rb:3](config/routes.rb#L3)

### Moyasar Payment Integration

**Purpose**: Subscription payments for business owners (99 SAR/month)

**Configuration** ([config/initializers/moyasar.rb](config/initializers/moyasar.rb)):
- Credentials stored in Rails encrypted credentials: `moyasar_publishable_key`, `moyasar_secret_key`
- API module provides helper methods: `Moyasar.publishable_key`, `Moyasar.to_halalas(amount)`
- Currency: SAR (Saudi Riyal), amounts in halalas (1 SAR = 100 halalas)

**Payment Flow**:
1. Owner starts trial or subscription ([app/controllers/subscriptions_controller.rb](app/controllers/subscriptions_controller.rb))
2. Frontend loads Moyasar.js SDK with publishable key
3. Client-side payment form collects card details
4. Server verifies payment and creates/updates subscription
5. Webhook receives payment notifications ([app/controllers/moyasar_webhooks_controller.rb](app/controllers/moyasar_webhooks_controller.rb))

**Subscription States** ([app/models/subscription.rb:5](app/models/subscription.rb#L5)):
- `trial` (0) - Free trial period (2 weeks)
- `active` (1) - Paid and current
- `past_due` (2) - Payment failed
- `cancelled` (3) - User cancelled
- `expired` (4) - Period ended

**Setup Guide**: See [MOYASAR_SETUP.md](MOYASAR_SETUP.md) for detailed configuration instructions including test card numbers.

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
- **Leaflet + OpenStreetMap**: Interactive maps for business locations

**Key files**:
- [config/importmap.rb](config/importmap.rb) - JavaScript dependencies
- [app/javascript/application.js](app/javascript/application.js) - Entry point
- [app/javascript/controllers/](app/javascript/controllers/) - Stimulus controllers
- [app/assets/stylesheets/application.css](app/assets/stylesheets/application.css) - CSS entry point

### Leaflet + OpenStreetMap Integration

**Interactive map for business locations** with auto-detection and reverse geocoding.

**Setup**:
- **Leaflet CSS**: [app/views/layouts/application.html.erb:28](app/views/layouts/application.html.erb#L28)
- **Leaflet JS**: [config/importmap.rb:14](config/importmap.rb#L14) - ESM module from unpkg CDN
- **Stimulus Controller**: [app/javascript/controllers/location_map_controller.js](app/javascript/controllers/location_map_controller.js)
- **Custom CSS**: [app/assets/stylesheets/map.css](app/assets/stylesheets/map.css)

**Features**:
- Auto-detect user location via browser Geolocation API
- Interactive OpenStreetMap tiles with click-to-place
- Draggable markers for fine-tuning location
- Reverse geocoding via Nominatim API (auto-fills address)
- Coordinates stored as decimal fields (precision: 10, scale: 6)

**Usage**:
```erb
<div data-controller="location-map"
     data-location-map-latitude-value="<%= business.latitude %>"
     data-location-map-longitude-value="<%= business.longitude %>">
  <div data-location-map-target="map"></div>
  <%= form.hidden_field :latitude, data: { location_map_target: "latitude" } %>
  <%= form.hidden_field :longitude, data: { location_map_target: "longitude" } %>
  <%= form.text_field :location, data: { location_map_target: "address" } %>
</div>
```

### Database Schema

**Key Models**:
- `User` - Devise fields + OAuth (`provider`, `uid`, `name`, `avatar_url`) + `role` enum
- `Business` - `name`, `description`, `category_id`, `user_id`, `open_time`, `close_time`, `phone_number`, `location`, `latitude`, `longitude`
- `Service` - `name`, `description`, `price`, `duration`, `business_id`
- `Booking` - `user_id`, `service_id`, `start_time`, `end_time`, `status` enum, `qr_code`, `notes`
- `Subscription` - `user_id`, `status` enum, `amount`, `currency`, `trial_ends_at`, `current_period_start/end`, `cancelled_at`
- `CalendarEvent` - `business_id`, `booking_id`, `title`, `start_time`, `end_time`
- `Category` - `name`, `description` (for business categorization)
- `QueueTicket` - Queue management for walk-in customers

**Important Schema Details**:
- All `time` fields use Rails `datetime` type (not `time`)
- Business hours stored as full datetime for time-only comparison
- Location coordinates: `latitude` and `longitude` stored as decimal (precision: 10, scale: 6)
- Active Storage attachments: `Business` has `logo` (one) and `images` (many)
- Migrations: [db/migrate/](db/migrate/)

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

### Working with Subscriptions

**Check subscription status**:
```ruby
user = User.find(id)
user.subscribed?              # Returns true if owner has valid subscription
user.on_trial?                # Returns true if in trial period
user.subscription_status_message  # Human-readable status
```

**Create trial subscription**:
```ruby
# Users get one free trial (2 weeks)
user.get_or_create_trial_subscription
```

**Subscription lifecycle**:
```ruby
sub = user.current_subscription
sub.valid_subscription?  # Active or trial + not expired
sub.days_remaining       # Days left in current period
sub.cancel!              # Cancel subscription
sub.renew!               # Renew for another month
```

**Testing Moyasar payments**:
- Test card: `4111 1111 1111 1111` (Visa success)
- Test card: `4000 0000 0000 0002` (Visa failure)
- CVV: Any 3 digits, Expiry: Any future date
- See [MOYASAR_SETUP.md](MOYASAR_SETUP.md) for complete testing guide

### Working with Bookings

**Creating bookings**:
```ruby
booking = Booking.create!(
  user: current_user,
  service: service,
  start_time: Time.zone.parse("2024-01-15 14:00")
  # end_time calculated automatically from service.duration
  # qr_code generated automatically
  # calendar_event created automatically for owner
)
```

**Automatic validations**:
- No time conflicts with other bookings for same service
- Within business operating hours
- End time after start time

**QR Code access**:
```ruby
booking.qr_code  # => "/qr_codes/booking_123_abc.png"
# QR code contains JSON: booking_id, user_id, service_id, business_id, start_time, verification_code
```

**Scopes**:
```ruby
Booking.upcoming        # Future bookings, ordered by start_time
Booking.past            # Past bookings, reverse chronological
Booking.by_status(:confirmed)  # Filter by status
```

### Managing Business Hours

**Business hours validation**:
```ruby
business = Business.find(id)
business.currently_open?          # Check if open now
business.time_until_status_change # "2h 30m" until open/close
```

Bookings automatically validate against business hours. See [app/models/booking.rb:54-79](app/models/booking.rb#L54-L79) for validation logic.

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
