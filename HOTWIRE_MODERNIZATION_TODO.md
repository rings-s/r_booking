# Hotwire Modernization TODO List

**Project**: R_Booking Rails 8.1 Application
**Goal**: Modern SPA-like experience with Hotwire best practices
**Timeline**: 12-16 days
**Started**: 2025-01-11

---

## Progress Overview

- [ ] Phase 1: Foundation & Critical Fixes (3 days)
- [ ] Phase 2: Turbo Frames - Core Flows (4 days)
- [ ] Phase 3: Turbo Streams - Real-time Updates (4 days)
- [ ] Phase 4: Optimization & Polish (3 days)
- [ ] Phase 5: Advanced Features (2 days - Optional)

**Legend**: ⚡ Critical | 🔥 High Impact | 📊 Performance | 🎨 UX | 🧪 Testing

---

## Phase 1: Foundation & Critical Fixes (3 days)

### Step 1.1: N+1 Query Fixes ⚡📊

**Priority**: CRITICAL - Must do first

#### Task 1.1.1: Install Query Monitoring Tools
- [ ] Add `bullet` gem to Gemfile development group
- [ ] Add `rack-mini-profiler` gem to Gemfile development group
- [ ] Run `bundle install`
- [ ] Configure bullet in `config/environments/development.rb`
- [ ] Configure rack-mini-profiler

**Files to modify:**
```ruby
# Gemfile (add to development group)
gem 'bullet'
gem 'rack-mini-profiler'

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
end
```

#### Task 1.1.2: Fix BookingsController N+1 Queries
- [ ] Update `app/controllers/bookings_controller.rb:7`
- [ ] Add eager loading for `service.business`, `service.category`
- [ ] Test with bullet gem
- [ ] Verify query count reduction

**Current code (LINE 7):**
```ruby
@bookings = current_user.client? ?
  current_user.bookings.includes(:service) :
  Booking.joins(service: :business)
```

**Updated code:**
```ruby
@bookings = current_user.client? ?
  current_user.bookings.includes(service: [:business, :category]) :
  Booking.joins(service: :business)
    .where(businesses: { user_id: current_user.id })
    .includes({ service: [:business, :category] }, :user)
```

#### Task 1.1.3: Fix BusinessesController N+1 Queries
- [ ] Update `app/controllers/businesses_controller.rb:9-10` (index action)
- [ ] Add eager loading for `user`, `category`, Active Storage attachments
- [ ] Update `set_business` method (around line 42)
- [ ] Test business index and show pages

**For index action:**
```ruby
def index
  @businesses = Business.includes(:user, :category)
                       .with_attached_logo
                       .with_attached_images
                       .order(created_at: :desc)
  @categories = Category.all
end
```

**For show action (update set_business):**
```ruby
def set_business
  @business = Business.includes(
    :user,
    :category,
    services: [:category, { images_attachments: :blob }]
  ).with_attached_logo
   .with_attached_images
   .friendly
   .find(params[:id])
end
```

#### Task 1.1.4: Add Database Indices
- [ ] Create migration: `rails g migration AddPerformanceIndices`
- [ ] Add indices for frequent queries
- [ ] Run migration
- [ ] Test query performance

**Migration content:**
```ruby
class AddPerformanceIndices < ActiveRecord::Migration[8.0]
  def change
    # Bookings
    add_index :bookings, [:service_id, :start_time], if_not_exists: true
    add_index :bookings, [:user_id, :status], if_not_exists: true
    add_index :bookings, [:status, :start_time], if_not_exists: true

    # Services
    add_index :services, [:business_id, :created_at], if_not_exists: true
    add_index :services, :category_id, if_not_exists: true

    # Businesses
    add_index :businesses, [:user_id, :created_at], if_not_exists: true
    add_index :businesses, :category_id, if_not_exists: true

    # Active Storage
    add_index :active_storage_attachments, [:record_type, :record_id, :name, :blob_id],
              name: 'index_active_storage_attachments_uniqueness',
              unique: true,
              if_not_exists: true
  end
end
```

#### Task 1.1.5: Verify Performance Improvements
- [ ] Use `rails console` to compare query counts
- [ ] Check Bullet gem output
- [ ] Document query count reduction (before/after)

**Expected Results:**
- Bookings index: 50+ queries → ~5 queries
- Business index: 100+ queries → ~3 queries
- Business show: 50+ queries → ~6 queries

---

### Step 1.2: Configure Rails 8 Features

#### Task 1.2.1: Enable Turbo Page Refresh with Morphing
- [ ] Add meta tags to `app/views/layouts/application.html.erb`
- [ ] Configure scroll preservation
- [ ] Test page refresh behavior

**Add inside `<head>` tag:**
```erb
<!-- Turbo 8 Page Refresh with Morphing -->
<meta name="turbo-refresh-method" content="morph">
<meta name="turbo-refresh-scroll" content="preserve">
```

#### Task 1.2.2: Configure Turbo Permanent Elements
- [ ] Identify elements that should persist across navigations
- [ ] Add `data-turbo-permanent` to flash messages
- [ ] Add `data-turbo-permanent` to filter panels
- [ ] Test navigation behavior

**Update flash messages:**
```erb
<!-- app/views/layouts/application.html.erb -->
<div id="flash-messages" data-turbo-permanent>
  <% flash.each do |type, message| %>
    <div class="alert alert-<%= type %>"><%= message %></div>
  <% end %>
</div>
```

#### Task 1.2.3: Configure Turbo Drive
- [ ] Verify `data-turbo="true"` on body (default)
- [ ] Add `data-turbo-prefetch` to important links
- [ ] Configure `data-turbo-track` for assets

**Example for prefetching:**
```erb
<%= link_to "View Business", business_path(business),
    data: { turbo_prefetch: true } %>
```

---

### Step 1.3: Add Lazy Loading ⚡📊

#### Task 1.3.1: Update Business Card Images
- [ ] Open `app/views/businesses/_business_card.html.erb`
- [ ] Add `loading: "lazy"` to logo image (line ~12)
- [ ] Add `loading: "lazy"` to placeholder image (line ~20)
- [ ] Add `decoding: "async"` for better performance

**Update all image_tag calls:**
```erb
<%= image_tag business.logo.variant(resize_to_fill: [300, 200]),
    class: "...",
    alt: "#{business.name} logo",
    loading: "lazy",
    decoding: "async" %>
```

#### Task 1.3.2: Update Business Show Page Images
- [ ] Open `app/views/businesses/show.html.erb`
- [ ] Add lazy loading to logo (line ~20)
- [ ] Add lazy loading to banner image (line ~42)
- [ ] Add lazy loading to service images (line ~248)
- [ ] Add lazy loading to gallery images (line ~356)

#### Task 1.3.3: Test Lazy Loading
- [ ] Open DevTools Network tab
- [ ] Verify images load on scroll
- [ ] Check LCP (Largest Contentful Paint) improvement
- [ ] Test on slow 3G connection

**Expected Results:**
- Initial page load: Load only visible images
- Scroll-triggered: Load additional images
- LCP improvement: 30-50% faster

---

## Phase 2: Turbo Frames - Core Flows (4 days)

### Step 2.1: Booking Creation Flow 🔥

#### Task 2.1.1: Create Available Slots Endpoint
- [ ] Add route: `get 'businesses/:business_id/services/:service_id/bookings/available_slots'`
- [ ] Create action in `BookingsController`
- [ ] Return turbo_stream format
- [ ] Handle date parameter

**Add to routes.rb:**
```ruby
resources :businesses do
  resources :services do
    resources :bookings do
      get :available_slots, on: :collection
    end
  end
end
```

**Controller action:**
```ruby
# app/controllers/bookings_controller.rb
def available_slots
  @date = Date.parse(params[:date])
  @slots = @service.available_slots_for_date(@date)

  respond_to do |format|
    format.turbo_stream
  end
end
```

#### Task 2.1.2: Create Turbo Stream View
- [ ] Create `app/views/bookings/available_slots.turbo_stream.erb`
- [ ] Replace time slot section
- [ ] Add loading indicator
- [ ] Handle no slots available case

**View content:**
```erb
<%= turbo_stream.replace "available_slots" do %>
  <div id="available_slots">
    <% if @slots.any? %>
      <div class="grid grid-cols-4 gap-2">
        <% @slots.each do |slot| %>
          <%= render 'time_slot_button', slot: slot, service: @service %>
        <% end %>
      </div>
    <% else %>
      <p class="text-gray-500">No available slots for this date</p>
    <% end %>
  </div>
<% end %>
```

#### Task 2.1.3: Update Booking Form with Turbo Frame
- [ ] Wrap time slots in `<turbo-frame id="available_slots">`
- [ ] Remove JavaScript date change handler (line ~80)
- [ ] Add Stimulus controller for date selection
- [ ] Add loading state

**Update _form.html.erb:**
```erb
<!-- Date selection -->
<%= f.date_field :start_time,
    data: {
      action: "change->booking-form#loadSlots",
      booking_form_target: "dateInput"
    },
    min: Date.today,
    class: "..." %>

<!-- Time slots wrapped in Turbo Frame -->
<turbo-frame id="available_slots"
             src="<%= available_slots_business_service_bookings_path(@business, @service, date: Date.today) %>"
             loading="lazy">
  <div class="text-center py-8">
    <div class="spinner"></div>
    <p>Loading available times...</p>
  </div>
</turbo-frame>
```

#### Task 2.1.4: Create Booking Form Stimulus Controller
- [ ] Generate: `rails g stimulus booking_form`
- [ ] Add date change handler
- [ ] Add slot selection logic
- [ ] Add loading states

**Controller code:**
```javascript
// app/javascript/controllers/booking_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dateInput", "slots", "submitButton"]

  loadSlots(event) {
    const date = event.target.value
    const frame = document.getElementById('available_slots')
    const url = new URL(frame.src)
    url.searchParams.set('date', date)
    frame.src = url.toString()
  }

  selectSlot(event) {
    // Remove previous selection
    this.element.querySelectorAll('[data-selected]').forEach(el => {
      el.removeAttribute('data-selected')
      el.classList.remove('selected')
    })

    // Add selection
    event.currentTarget.setAttribute('data-selected', 'true')
    event.currentTarget.classList.add('selected')

    // Enable submit
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }
  }
}
```

#### Task 2.1.5: Test Booking Flow
- [ ] Test date selection updates slots without reload
- [ ] Verify Turbo Frame isolation
- [ ] Test back button behavior
- [ ] Test error handling
- [ ] Verify mobile responsiveness

---

### Step 2.2: Business List Pagination 📊

#### Task 2.2.1: Add Pagination Gem
- [ ] Add `gem 'pagy'` to Gemfile
- [ ] Run `bundle install`
- [ ] Include Pagy in ApplicationController
- [ ] Configure Pagy defaults

**Add to ApplicationController:**
```ruby
# app/controllers/application_controller.rb
include Pagy::Backend
```

**Add to ApplicationHelper:**
```ruby
# app/helpers/application_helper.rb
include Pagy::Frontend
```

#### Task 2.2.2: Implement Pagination in BusinessesController
- [ ] Update index action with `pagy`
- [ ] Set items per page to 12
- [ ] Add turbo_stream response for pagination

```ruby
def index
  @pagy, @businesses = pagy(
    Business.includes(:user, :category)
            .with_attached_logo
            .order(created_at: :desc),
    items: 12
  )
  @categories = Category.all

  respond_to do |format|
    format.html
    format.turbo_stream
  end
end
```

#### Task 2.2.3: Create Turbo Frame for Business List
- [ ] Wrap business list in Turbo Frame
- [ ] Create pagination partial
- [ ] Add loading indicator
- [ ] Create turbo_stream view

**Update index.html.erb:**
```erb
<turbo-frame id="businesses" data-turbo-action="advance">
  <%= render 'businesses_grid', businesses: @businesses %>
  <%= render 'pagination', pagy: @pagy %>
</turbo-frame>
```

#### Task 2.2.4: Create Infinite Scroll (Optional)
- [ ] Generate: `rails g stimulus infinite_scroll`
- [ ] Detect scroll to bottom
- [ ] Load next page automatically
- [ ] Add intersection observer

#### Task 2.2.5: Add Skeleton Loaders
- [ ] Create `_business_card_skeleton.html.erb`
- [ ] Show skeletons during loading
- [ ] Style with Tailwind

---

### Step 2.3: Dashboard Sections 🎨

#### Task 2.3.1: Split Dashboard into Partials
- [ ] Create `app/views/dashboard/_stats_cards.html.erb`
- [ ] Create `app/views/dashboard/_todays_bookings.html.erb`
- [ ] Create `app/views/dashboard/_upcoming_bookings.html.erb`
- [ ] Create `app/views/dashboard/_charts.html.erb`

#### Task 2.3.2: Wrap Sections in Turbo Frames
- [ ] Add Turbo Frame around stats cards
- [ ] Add Turbo Frame around today's bookings
- [ ] Add independent reload capability
- [ ] Set `data-turbo-action="advance"` for history

**Update owner.html.erb:**
```erb
<!-- Stats Cards as Turbo Frame -->
<turbo-frame id="dashboard_stats"
             src="<%= dashboard_stats_path %>"
             refresh="every 30s">
  <%= render 'stats_cards' %>
</turbo-frame>

<!-- Today's Bookings as Turbo Frame -->
<turbo-frame id="todays_bookings">
  <%= render 'todays_bookings', bookings: @todays_bookings %>
</turbo-frame>
```

#### Task 2.3.3: Create Dashboard Stats Endpoint
- [ ] Add route: `get 'dashboard/stats'`
- [ ] Create action in DashboardController
- [ ] Return turbo_stream or HTML in frame
- [ ] Cache for 30 seconds

---

## Phase 3: Turbo Streams - Real-time Updates (4 days)

### Step 3.1: Booking CRUD Operations 🔥

#### Task 3.1.1: Add Turbo Stream Responses to Create
- [ ] Update `BookingsController#create`
- [ ] Add turbo_stream format
- [ ] Create `create.turbo_stream.erb`
- [ ] Implement success and error streams

**Controller:**
```ruby
def create
  @booking = @service.bookings.build(booking_params)
  @booking.user = current_user

  respond_to do |format|
    if @booking.save
      format.html { redirect_to @booking, notice: 'Booking created.' }
      format.turbo_stream
    else
      format.html { render :new, status: :unprocessable_entity }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          'booking_form',
          partial: 'bookings/form',
          locals: { booking: @booking, business: @business, service: @service }
        )
      }
    end
  end
end
```

**View (create.turbo_stream.erb):**
```erb
<%= turbo_stream.replace "booking_form" do %>
  <%= render 'success_message', booking: @booking %>
<% end %>

<%= turbo_stream.prepend "upcoming_bookings" do %>
  <%= render 'bookings/booking_card', booking: @booking %>
<% end %>

<%= turbo_stream.update "flash_messages" do %>
  <div class="alert alert-success">Booking created successfully!</div>
<% end %>
```

#### Task 3.1.2: Add Turbo Stream Responses to Update
- [ ] Update `BookingsController#update`
- [ ] Create `update.turbo_stream.erb`
- [ ] Handle inline editing

#### Task 3.1.3: Add Turbo Stream Responses to Destroy
- [ ] Update `BookingsController#destroy`
- [ ] Create `destroy.turbo_stream.erb`
- [ ] Add confirmation dialog
- [ ] Animate removal

**destroy.turbo_stream.erb:**
```erb
<%= turbo_stream.remove "booking_#{@booking.id}" %>

<%= turbo_stream.update "flash_messages" do %>
  <div class="alert alert-info">Booking cancelled.</div>
<% end %>
```

#### Task 3.1.4: Add Inline Editing for Notes
- [ ] Create `edit.turbo_stream.erb`
- [ ] Replace booking card with form
- [ ] Add cancel button
- [ ] Preserve layout

---

### Step 3.2: Real-time Broadcasting 🔥

#### Task 3.2.1: Add Broadcast Callbacks to Booking Model
- [ ] Add `after_create_commit :broadcast_created`
- [ ] Add `after_update_commit :broadcast_updated`
- [ ] Add `after_destroy_commit :broadcast_destroyed`
- [ ] Target both user and owner streams

**Model code:**
```ruby
# app/models/booking.rb
class Booking < ApplicationRecord
  after_create_commit :broadcast_created
  after_update_commit :broadcast_updated
  after_destroy_commit :broadcast_destroyed

  private

  def broadcast_created
    # Notify client
    broadcast_prepend_to(
      "bookings_#{user_id}",
      target: "upcoming_bookings",
      partial: "bookings/booking_card",
      locals: { booking: self }
    )

    # Notify business owner
    broadcast_prepend_to(
      "dashboard_#{service.business.user_id}",
      target: "todays_bookings",
      partial: "dashboard/booking_row",
      locals: { booking: self }
    )
  end

  def broadcast_updated
    broadcast_replace_to "bookings_#{user_id}"
    broadcast_replace_to "dashboard_#{service.business.user_id}"
  end

  def broadcast_destroyed
    broadcast_remove_to "bookings_#{user_id}"
    broadcast_remove_to "dashboard_#{service.business.user_id}"
  end
end
```

#### Task 3.2.2: Subscribe to Streams in Views
- [ ] Add stream subscription to bookings/index.html.erb
- [ ] Add stream subscription to dashboard/owner.html.erb
- [ ] Test real-time updates across browser tabs

**Add to views:**
```erb
<!-- app/views/bookings/index.html.erb -->
<%= turbo_stream_from "bookings_#{current_user.id}" %>

<!-- app/views/dashboard/owner.html.erb -->
<%= turbo_stream_from "dashboard_#{current_user.id}" %>
```

#### Task 3.2.3: Test Real-time Broadcasting
- [ ] Open two browser windows
- [ ] Create booking in one window
- [ ] Verify it appears in other window
- [ ] Test update and delete
- [ ] Check Action Cable connection

---

### Step 3.3: Form Validations 🎨

#### Task 3.3.1: Create Inline Validation Partial
- [ ] Create `_validation_errors.html.erb`
- [ ] Style with Tailwind
- [ ] Show field-specific errors

#### Task 3.3.2: Add Turbo Stream Validation to Forms
- [ ] Update form submissions to use turbo_stream
- [ ] Return validation errors as turbo_stream
- [ ] Highlight invalid fields
- [ ] Preserve user input

**Example:**
```ruby
def create
  if @resource.save
    # success
  else
    render turbo_stream: turbo_stream.replace(
      "#{dom_id(@resource)}_form",
      partial: 'form',
      locals: { resource: @resource }
    ), status: :unprocessable_entity
  end
end
```

---

## Phase 4: Optimization & Polish (3 days)

### Step 4.1: Caching Implementation 📊

#### Task 4.1.1: Add Fragment Caching to Business Cards
- [ ] Wrap business card in cache block
- [ ] Use `cache business do`
- [ ] Add cache busting on update
- [ ] Test cache invalidation

```erb
<!-- app/views/businesses/_business_card.html.erb -->
<% cache business do %>
  <div class="business-card">...</div>
<% end %>
```

#### Task 4.1.2: Add Collection Caching
- [ ] Use `cached: true` in render calls
- [ ] Test with multiple businesses
- [ ] Verify cache keys

```erb
<%= render partial: 'business_card',
           collection: @businesses,
           cached: true %>
```

#### Task 4.1.3: Cache Dashboard Components
- [ ] Cache stats cards with time-based expiry
- [ ] Cache chart data
- [ ] Use Russian doll caching pattern

```erb
<% cache ["dashboard_stats", current_user, @bookings.maximum(:updated_at)], expires_in: 5.minutes do %>
  <%= render 'stats_cards' %>
<% end %>
```

#### Task 4.1.4: Configure Cache Store
- [ ] Verify Solid Cache configuration
- [ ] Set cache expiry defaults
- [ ] Add cache clearing rake task

---

### Step 4.2: Stimulus Optimizations

#### Task 4.2.1: Add Debouncing to Search Controller
- [ ] Update `business_filter_controller.js`
- [ ] Add 300ms debounce to search
- [ ] Prevent unnecessary DOM scans

**Update controller:**
```javascript
search() {
  clearTimeout(this.searchTimeout)
  this.searchTimeout = setTimeout(() => {
    this.performSearch()
  }, 300)
}
```

#### Task 4.2.2: Optimize Chartkick Controller
- [ ] Target specific charts instead of `createAll()`
- [ ] Lazy load charts on scroll
- [ ] Add loading indicators

#### Task 4.2.3: Add Keyboard Shortcuts
- [ ] Add global keyboard handler
- [ ] Implement common shortcuts (/, Esc, etc.)
- [ ] Document shortcuts for users

---

### Step 4.3: Performance Testing 🧪

#### Task 4.3.1: Install Performance Monitoring
- [ ] Verify rack-mini-profiler is active
- [ ] Add custom performance tracking
- [ ] Set up New Relic or Skylight (optional)

#### Task 4.3.2: Run Load Tests
- [ ] Use `siege` or `wrk` for load testing
- [ ] Test with 100 concurrent users
- [ ] Identify bottlenecks
- [ ] Document response times

#### Task 4.3.3: Optimize Slow Queries
- [ ] Review slow query log
- [ ] Add missing indices
- [ ] Optimize complex queries
- [ ] Consider database views

#### Task 4.3.4: Performance Benchmarks
- [ ] Document before/after metrics
- [ ] Page load times
- [ ] Time to interactive
- [ ] First contentful paint
- [ ] Query counts

**Target Metrics:**
- Homepage load: <1s
- Business list: <1.5s
- Booking creation: <500ms
- Dashboard: <2s
- All pages: <100 queries

---

## Phase 5: Advanced Features (2 days - Optional)

### Step 5.1: Calendar Live Updates

#### Task 5.1.1: Add Turbo Stream to Calendar
- [ ] Wrap calendar in Turbo Frame
- [ ] Subscribe to booking broadcasts
- [ ] Update calendar on new booking
- [ ] Handle drag-and-drop

#### Task 5.1.2: Implement Drag-and-Drop Rescheduling
- [ ] Add Stimulus controller for drag
- [ ] Update booking via turbo_stream
- [ ] Validate new time slot
- [ ] Show conflict warnings

---

### Step 5.2: Admin Panel Enhancements

#### Task 5.2.1: Inline User Editing
- [ ] Add edit mode to user rows
- [ ] Use Turbo Frames for row replacement
- [ ] Add inline validation
- [ ] Cancel editing preserves state

#### Task 5.2.2: Bulk Operations
- [ ] Add checkboxes to table rows
- [ ] Implement "select all"
- [ ] Create bulk actions (delete, export)
- [ ] Use Turbo Streams for batch updates

---

## Testing Checklist 🧪

### Unit Tests
- [ ] Model broadcast callbacks
- [ ] Cache key generation
- [ ] Query optimizations

### Integration Tests
- [ ] Turbo Frame navigation
- [ ] Turbo Stream broadcasts
- [ ] Form submissions
- [ ] Pagination

### System Tests
- [ ] Booking creation flow
- [ ] Real-time updates
- [ ] Back button behavior
- [ ] Mobile responsiveness

### Performance Tests
- [ ] Query count benchmarks
- [ ] Page load times
- [ ] Cache hit rates
- [ ] Memory usage

### Accessibility Tests
- [ ] Screen reader compatibility
- [ ] Keyboard navigation
- [ ] Focus management with Turbo
- [ ] ARIA labels

---

## Validation & Sign-off

### Phase 1 Completion Criteria
- [ ] All N+1 queries fixed (Bullet gem shows no alerts)
- [ ] Database indices added and working
- [ ] Lazy loading implemented on all images
- [ ] Rails 8 features configured
- [ ] Performance improvement: 50% reduction in queries

### Phase 2 Completion Criteria
- [ ] Booking form uses Turbo Frames (no full page reload)
- [ ] Business list has pagination
- [ ] Dashboard sections independently loadable
- [ ] Back button works correctly
- [ ] No JavaScript errors in console

### Phase 3 Completion Criteria
- [ ] CRUD operations use Turbo Streams
- [ ] Real-time broadcasts working
- [ ] Form validations show inline
- [ ] Multiple users see updates simultaneously
- [ ] Action Cable connection stable

### Phase 4 Completion Criteria
- [ ] Fragment caching implemented
- [ ] Query counts reduced by 60%+
- [ ] Page load times under targets
- [ ] No performance regressions
- [ ] Monitoring tools in place

### Final Sign-off
- [ ] All phases completed
- [ ] Full test suite passing
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Ready for production

---

## Notes & Learnings

**Document issues and solutions here as you progress:**

1. Issue: [Description]
   - Solution: [What worked]
   - Reference: [File:line or commit]

2. Performance Win: [Description]
   - Before: [metric]
   - After: [metric]
   - Change: [what was done]

---

## References

- [Turbo Handbook](https://turbo.hotwired.dev/)
- [Stimulus Handbook](https://stimulus.hotwired.dev/)
- [Rails Guides - Caching](https://guides.rubyonrails.org/caching_with_rails.html)
- [Pagy Documentation](https://ddnexus.github.io/pagy/)
- [Action Cable Guide](https://guides.rubyonrails.org/action_cable_overview.html)

---

**Last Updated**: 2025-01-11
**Current Phase**: Phase 1 - Foundation & Critical Fixes
**Next Milestone**: Complete N+1 query fixes by end of day
