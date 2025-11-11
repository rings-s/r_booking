# Google OAuth2 Implementation Guide - Complete Tutorial

This guide teaches you how to implement Google OAuth2 authentication in a Rails application using Devise and OmniAuth. Use this as a reference for implementing Google sign-in in your future projects.

---

## Table of Contents

1. [Understanding OAuth2](#understanding-oauth2)
2. [Prerequisites](#prerequisites)
3. [Implementation Steps](#implementation-steps)
4. [Code Explanation](#code-explanation)
5. [Security Considerations](#security-considerations)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

---

## Understanding OAuth2

### What is OAuth2?

OAuth2 is an authorization framework that allows users to sign in to your application using their existing accounts (Google, Facebook, GitHub, etc.) without sharing their passwords with your app.

### OAuth2 Flow Diagram

```
User Clicks "Sign in with Google"
         ↓
Redirect to Google OAuth consent screen
         ↓
User grants permissions to your app
         ↓
Google redirects back with authorization code
         ↓
Your app exchanges code for user data
         ↓
Create/update user account in your database
         ↓
Sign user into your application
```

### Key Concepts

- **Provider**: The service providing OAuth (Google, Facebook, etc.)
- **Client ID**: Public identifier for your application
- **Client Secret**: Secret key used to authenticate your app (keep secure!)
- **Redirect URI**: Where Google sends users after authentication
- **Scopes**: What data your app requests access to (email, profile, etc.)
- **OAuth Token**: Temporary credential proving user authorized your app

---

## Prerequisites

### Required Gems

Add these to your `Gemfile`:

```ruby
# Authentication
gem 'devise', '~> 4.9'

# OAuth2 provider for Google
gem 'omniauth-google-oauth2', '~> 1.1'

# Required for OmniAuth in Rails 7+
gem 'omniauth-rails_csrf_protection', '~> 1.0'
```

Then run:
```bash
bundle install
```

### Why These Gems?

- **devise**: Handles user authentication (sign up, sign in, password reset, etc.)
- **omniauth-google-oauth2**: Implements OAuth2 protocol specifically for Google
- **omniauth-rails_csrf_protection**: Protects against CSRF attacks in OAuth callbacks

---

## Implementation Steps

### Step 1: Set Up Google Cloud Console

#### 1.1 Create a Google Cloud Project

1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "New Project"
3. Enter project name (e.g., "My Rails App")
4. Click "Create"

#### 1.2 Enable Google+ API or People API

1. Go to "APIs & Services" → "Library"
2. Search for "Google+ API" or "People API"
3. Click "Enable"

**Why?** Your app needs permission to access Google user profile data.

#### 1.3 Configure OAuth Consent Screen

1. Go to "APIs & Services" → "OAuth consent screen"
2. Choose "External" (allows anyone with Google account)
3. Fill in required fields:
   - **App name**: Your app name (e.g., "R_Booking")
   - **User support email**: Your email
   - **Developer contact**: Your email
4. Click "Save and Continue"

5. **Add Scopes**:
   - Click "Add or Remove Scopes"
   - Select:
     - `userinfo.email` (get user's email)
     - `userinfo.profile` (get user's name and avatar)
   - Click "Update" → "Save and Continue"

6. **Add Test Users** (for development):
   - Add your Gmail address
   - Click "Save and Continue"

**Why?** Google requires you to declare what data your app will access.

#### 1.4 Create OAuth 2.0 Credentials

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth 2.0 Client ID"
3. Application type: **Web application**
4. Name: "My Rails App Web Client"

5. **Authorized redirect URIs** (CRITICAL):

   Add these EXACT URIs:
   ```
   http://localhost:3000/users/auth/google_oauth2/callback
   http://127.0.0.1:3000/users/auth/google_oauth2/callback
   ```

   For production:
   ```
   https://yourdomain.com/users/auth/google_oauth2/callback
   ```

   **Important Notes**:
   - Use `http://` for localhost (NOT `https://`)
   - URL must match EXACTLY (no trailing slashes!)
   - `/users/auth/google_oauth2/callback` is Devise's default OAuth callback path

6. Click "Create"

7. **Copy Your Credentials**:
   - **Client ID**: `xxxxx.apps.googleusercontent.com`
   - **Client Secret**: `GOCSPX-xxxxxx`

   Keep these safe! You'll need them next.

**Why?** Google needs to know where to redirect users after authentication to prevent phishing attacks.

---

### Step 2: Install and Configure Devise

#### 2.1 Install Devise

```bash
bin/rails generate devise:install
bin/rails generate devise User
```

This creates:
- `config/initializers/devise.rb` - Devise configuration
- `app/models/user.rb` - User model with Devise modules
- Migration for users table

#### 2.2 Add OAuth Columns to User Model

Create migration:
```bash
bin/rails generate migration AddOmniauthToUsers provider:string uid:string name:string avatar_url:string
```

This adds:
- `provider`: OAuth provider name (e.g., "google_oauth2")
- `uid`: Unique identifier from provider
- `name`: User's full name from OAuth
- `avatar_url`: User's profile picture URL

Run migration:
```bash
bin/rails db:migrate
```

**Why these columns?**
- `provider + uid`: Uniquely identifies the user's OAuth account
- `name`: Display user's name in your app
- `avatar_url`: Show user's profile picture

#### 2.3 Add Indexes for Performance

```bash
bin/rails generate migration AddIndexesToUsers
```

In the migration file:
```ruby
class AddIndexesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_index :users, [:provider, :uid], unique: true
    add_index :users, :email, unique: true
  end
end
```

Run: `bin/rails db:migrate`

**Why?** Faster database lookups when finding users by OAuth credentials.

---

### Step 3: Store Credentials Securely

#### 3.1 Edit Rails Credentials

```bash
EDITOR=nano bin/rails credentials:edit
```

Or with VS Code:
```bash
EDITOR="code --wait" bin/rails credentials:edit
```

#### 3.2 Add Your Google OAuth Credentials

```yaml
google_client_id: YOUR_CLIENT_ID.apps.googleusercontent.com
google_client_secret: GOCSPX-YOUR_CLIENT_SECRET
```

Save and close.

**Why Rails credentials?**
- Encrypted file (safe to commit to git)
- Different per environment (development/production)
- Decrypted using `config/master.key` (NEVER commit this!)

#### 3.3 Verify Credentials

```bash
bin/rails console
```

```ruby
Rails.application.credentials.google_client_id
# Should output your Client ID
```

---

### Step 4: Configure Devise for OmniAuth

#### 4.1 Edit Devise Initializer

Open `config/initializers/devise.rb` and add after line 40:

```ruby
# OmniAuth configuration for Google OAuth2
# Note: Do NOT create a separate config/initializers/omniauth.rb file as it will conflict
config.omniauth :google_oauth2,
                Rails.application.credentials.dig(:google_client_id),
                Rails.application.credentials.dig(:google_client_secret),
                {
                  scope: 'userinfo.email,userinfo.profile',
                  prompt: 'select_account',
                  image_aspect_ratio: 'square',
                  image_size: 50
                }
```

**Configuration explained**:
- `scope`: What data we request (email and profile)
- `prompt: 'select_account'`: Always show account chooser (better UX)
- `image_aspect_ratio: 'square'`: Request square avatar images
- `image_size: 50`: Avatar size in pixels

**IMPORTANT**: Never create a separate `config/initializers/omniauth.rb` file - it conflicts with Devise!

---

### Step 5: Update User Model

Open `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  # Include :omniauthable module and specify providers
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  # Role enum for authorization
  enum :role, { client: 0, owner: 1, admin: 2 }

  # Method to find or create user from OAuth data
  def self.from_omniauth(auth)
    # First, try to find user by provider and uid
    user = where(provider: auth.provider, uid: auth.uid).first

    # If not found, try to find by email and link the account
    if user.nil? && auth.info.email.present?
      user = find_by(email: auth.info.email)
      if user
        # Link the OAuth account to existing email/password user
        user.update(
          provider: auth.provider,
          uid: auth.uid,
          name: auth.info.name || user.name,
          avatar_url: auth.info.image || user.avatar_url
        )
      end
    end

    # If still not found, create a new user
    user ||= where(provider: auth.provider, uid: auth.uid).first_or_create do |new_user|
      new_user.email = auth.info.email
      new_user.password = Devise.friendly_token[0, 20]  # Random password
      new_user.name = auth.info.name
      new_user.avatar_url = auth.info.image
    end

    user
  end
end
```

**Code explanation**:

1. **Add `:omniauthable` module**: Enables OAuth authentication
2. **Specify providers**: `omniauth_providers: [:google_oauth2]`
3. **`from_omniauth` method**: Handles OAuth callback data
   - Tries to find existing OAuth user
   - If no OAuth user, tries to link to existing email user
   - If neither exists, creates new user
   - Generates random password (OAuth users don't need it)

**Why link by email?** If user created account with email/password, then later uses "Sign in with Google", they should get the same account.

---

### Step 6: Create OAuth Callbacks Controller

Create file `app/controllers/users/omniauth_callbacks_controller.rb`:

```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Skip CSRF verification for OAuth callback (Google's response is trusted)
  skip_before_action :verify_authenticity_token, only: :google_oauth2

  # Called when Google redirects back after successful authentication
  def google_oauth2
    # Get user from OAuth data
    @user = User.from_omniauth(request.env['omniauth.auth'])

    if @user.persisted?
      # User successfully created/found, sign them in
      flash[:notice] = I18n.t 'devise.omniauth_callbacks.success', kind: 'Google'
      sign_in_and_redirect @user, event: :authentication
    else
      # User could not be saved (validation errors)
      session['devise.google_data'] = request.env['omniauth.auth'].except('extra')
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  # Called if OAuth fails (user denies permission, network error, etc.)
  def failure
    redirect_to root_path
  end
end
```

**Code explanation**:

- `skip_before_action :verify_authenticity_token`: OAuth callbacks don't have CSRF tokens (they come from Google, not your forms)
- `request.env['omniauth.auth']`: OAuth data from Google (email, name, uid, etc.)
- `sign_in_and_redirect`: Signs user in and redirects to after_sign_in_path
- `failure`: Handles OAuth errors gracefully

**OAuth Auth Hash Structure**:
```ruby
{
  'provider' => 'google_oauth2',
  'uid' => '123456789',
  'info' => {
    'email' => 'user@example.com',
    'name' => 'John Doe',
    'image' => 'https://lh3.googleusercontent.com/...'
  }
}
```

---

### Step 7: Configure Routes

Open `config/routes.rb` and configure Devise routes:

```ruby
Rails.application.routes.draw do
  # Devise routes with custom OAuth callbacks controller
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  # ... rest of your routes
end
```

**Why custom controller?** To use our `Users::OmniauthCallbacksController` instead of Devise's default.

This creates these routes:
```
GET|POST /users/auth/google_oauth2          # Initiates OAuth flow
GET|POST /users/auth/google_oauth2/callback # OAuth callback endpoint
```

---

### Step 8: Add Sign-In Button to Views

#### Option 1: Using `button_to` (Recommended for Turbo)

```erb
<%= button_to "Sign in with Google",
              user_google_oauth2_omniauth_authorize_path,
              method: :post,
              data: { turbo: false },
              class: "btn btn-google" %>
```

#### Option 2: Using `link_to`

```erb
<%= link_to "Sign in with Google",
            user_google_oauth2_omniauth_authorize_path,
            method: :post,
            data: { turbo: false },
            class: "btn btn-google" %>
```

**Important**: `data: { turbo: false }` disables Turbo for OAuth (OAuth redirects must use full page navigation).

#### Styled Google Button Example

```erb
<div class="oauth-buttons">
  <%= button_to user_google_oauth2_omniauth_authorize_path,
                method: :post,
                data: { turbo: false },
                class: "google-btn" do %>
    <svg class="google-icon" viewBox="0 0 24 24">
      <!-- Google SVG icon -->
    </svg>
    <span>Sign in with Google</span>
  <% end %>
</div>
```

---

## Code Explanation

### How OAuth Flow Works in This Implementation

1. **User clicks "Sign in with Google"**
   - Browser sends POST to `/users/auth/google_oauth2`
   - OmniAuth middleware intercepts request

2. **OmniAuth redirects to Google**
   - Constructs OAuth URL with your Client ID and requested scopes
   - User sees Google consent screen

3. **User grants permissions**
   - Google redirects to your callback URL
   - Includes authorization code in URL parameters

4. **Callback receives OAuth data**
   - OmniAuth exchanges code for user data (using Client Secret)
   - Makes request to Google's API
   - Stores result in `request.env['omniauth.auth']`

5. **Your controller processes data**
   - Calls `User.from_omniauth(auth)`
   - Finds or creates user
   - Signs user in

6. **User is authenticated**
   - Redirected to your app's homepage (or `after_sign_in_path`)

### Security Measures in This Implementation

#### 1. Encrypted Credentials
```ruby
Rails.application.credentials.dig(:google_client_id)
```
- Credentials stored encrypted
- Decrypted at runtime
- Never exposed in code

#### 2. OAuth State Parameter
- Automatically handled by OmniAuth
- Prevents CSRF attacks
- Validates callback came from your initiated request

#### 3. HTTPS Required in Production
- OAuth2 spec requires HTTPS for production
- Protects against man-in-the-middle attacks

#### 4. Email Verification
- Google verifies email ownership
- You can trust email is valid
- Optional: Add `skip_confirmation!` if using Devise confirmable

---

## Security Considerations

### Protecting Your Credentials

#### Never Commit These Files:
```gitignore
# .gitignore
config/master.key
config/credentials/*.key
.env
```

#### Keep Master Key Safe:
- Store in password manager
- Required to decrypt credentials
- Different for each environment

### Production Security Checklist

- [ ] Use HTTPS (required for OAuth2)
- [ ] Use production Google OAuth credentials (not test)
- [ ] Submit app for Google verification (removes "unverified app" warning)
- [ ] Set proper redirect URIs in Google Console
- [ ] Rotate credentials if compromised
- [ ] Monitor OAuth usage in Google Console

### Account Linking Security

The `from_omniauth` method links accounts by email. Consider:

**Pros**:
- Seamless UX (same account for email/password and OAuth)
- User doesn't create duplicate accounts

**Cons**:
- If email is hijacked, attacker can link OAuth account
- Mitigation: Google verifies email, so trust is transferred

**Alternative**: Require email verification before linking:
```ruby
if user && user.confirmed?  # Devise confirmable
  user.update(provider: auth.provider, uid: auth.uid)
end
```

---

## Testing

### Manual Testing Flow

1. Start Rails server:
   ```bash
   bin/dev
   ```

2. Visit `http://localhost:3000`

3. Click "Sign in with Google"

4. Select Google account

5. Grant permissions (first time only)

6. Should redirect back to your app, signed in

7. Check user created:
   ```bash
   bin/rails console
   User.last
   # Should show user with provider: "google_oauth2"
   ```

### Test in Console

```ruby
# Simulate OAuth data
auth = OmniAuth::AuthHash.new({
  provider: 'google_oauth2',
  uid: '123456',
  info: {
    email: 'test@example.com',
    name: 'Test User',
    image: 'http://example.com/image.jpg'
  }
})

# Test user creation
user = User.from_omniauth(auth)
puts user.inspect
puts user.errors.full_messages if user.errors.any?
```

### RSpec Tests (Optional)

```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  describe '.from_omniauth' do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: 'google_oauth2',
        uid: '123456',
        info: {
          email: 'user@example.com',
          name: 'John Doe',
          image: 'http://example.com/photo.jpg'
        }
      )
    end

    it 'creates a new user from OAuth data' do
      expect {
        User.from_omniauth(auth)
      }.to change(User, :count).by(1)
    end

    it 'finds existing user by provider and uid' do
      user = User.from_omniauth(auth)
      expect(User.from_omniauth(auth)).to eq(user)
    end

    it 'links OAuth to existing email user' do
      user = User.create!(email: 'user@example.com', password: 'password123')
      oauth_user = User.from_omniauth(auth)
      expect(oauth_user.id).to eq(user.id)
      expect(oauth_user.provider).to eq('google_oauth2')
    end
  end
end
```

---

## Troubleshooting

### Error: "redirect_uri_mismatch"

**Cause**: Google doesn't recognize your redirect URI.

**Solution**:
1. Check Google Console → Credentials → Authorized redirect URIs
2. Must match EXACTLY:
   - ✅ `http://localhost:3000/users/auth/google_oauth2/callback`
   - ❌ `http://localhost:3000/auth/google_oauth2/callback` (missing /users)
   - ❌ `http://localhost:3000/users/auth/google_oauth2/callback/` (extra /)

### Error: "This app isn't verified"

**Normal for development!**

Click:
1. "Advanced"
2. "Go to [app name] (unsafe)"

For production, submit app for Google verification (takes 3-5 days).

### Error: "Access blocked: Authorization Error"

**Causes**:
- OAuth consent screen not configured
- Required scopes not added
- Email not added as test user

**Solution**:
1. Google Console → OAuth consent screen
2. Add scopes: `userinfo.email`, `userinfo.profile`
3. Add your email as test user

### User Can't Be Saved

**Check**:
```bash
bin/rails console
auth = OmniAuth::AuthHash.new({...})
user = User.from_omniauth(auth)
puts user.errors.full_messages
```

**Common issues**:
- Missing database columns (`provider`, `uid`, `name`, `avatar_url`)
- Email validation failing
- Password validation (should skip for OAuth users)

**Solution**:
```bash
bin/rails db:migrate:status  # Check migrations ran
```

### CSRF Token Errors

**Cause**: Not skipping CSRF for OAuth callback.

**Solution**: Ensure in controller:
```ruby
skip_before_action :verify_authenticity_token, only: :google_oauth2
```

---

## Summary

You've learned:

✅ How OAuth2 works and why to use it
✅ Setting up Google Cloud Console for OAuth
✅ Configuring Devise with OmniAuth
✅ Securely storing credentials
✅ Handling OAuth callbacks
✅ Linking OAuth accounts with existing users
✅ Security best practices
✅ Testing and troubleshooting

### Next Steps for Production

1. Get production Google OAuth credentials
2. Add production redirect URI to Google Console
3. Submit app for Google verification (optional but recommended)
4. Test thoroughly in staging environment
5. Monitor OAuth errors in production logs

---

## References

- [Devise Wiki - OmniAuth Overview](https://github.com/heartcombo/devise/wiki/OmniAuth:-Overview)
- [OmniAuth Google OAuth2 Gem](https://github.com/zquestz/omniauth-google-oauth2)
- [Google OAuth2 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Google Cloud Console](https://console.cloud.google.com/)
- [OAuth 2.0 RFC](https://datatracker.ietf.org/doc/html/rfc6749)

---

**Note**: This guide is based on the implementation in the r_booking Rails 8.1 application. Adapt as needed for your specific requirements.
