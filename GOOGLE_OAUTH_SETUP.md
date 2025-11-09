# Google OAuth2 Setup Guide for r_booking

## Quick Fix for redirect_uri_mismatch Error

The **"Error 400: redirect_uri_mismatch"** means Google can't find a matching redirect URI. Follow these steps to fix it.

---

## Step-by-Step Setup

### 1. Get Your OAuth Callback URL

Your Rails app uses this callback URL:

```
http://localhost:3000/users/auth/google_oauth2/callback
```

For production, it will be:
```
https://yourdomain.com/users/auth/google_oauth2/callback
```

### 2. Configure Google Cloud Console

1. **Go to Google Cloud Console**
   - Visit: https://console.cloud.google.com/
   - Select your project or create a new one

2. **Enable Required APIs**
   - Go to "APIs & Services" > "Library"
   - Search for "Google+ API" or "People API"
   - Click "Enable"

3. **Configure OAuth Consent Screen**
   - Go to "APIs & Services" > "OAuth consent screen"
   - Choose "External" for user type
   - Fill in required information:
     - App name: `r_booking`
     - User support email: your email
     - Developer contact: your email
   - Click "Save and Continue"
   - **Add Scopes:**
     - Click "Add or Remove Scopes"
     - Select: `userinfo.email` and `userinfo.profile`
     - Save
   - Add test users if needed (for development)
   - Click "Save and Continue"

4. **Create OAuth 2.0 Client ID**
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "OAuth 2.0 Client ID"
   - Application type: **Web application**
   - Name: `r_booking Web Client`

   **⚠️ IMPORTANT - Authorized redirect URIs:**

   Add these URIs exactly (one per line):
   ```
   http://localhost:3000/users/auth/google_oauth2/callback
   http://127.0.0.1:3000/users/auth/google_oauth2/callback
   ```

   For production, also add:
   ```
   https://yourdomain.com/users/auth/google_oauth2/callback
   ```

5. **Copy Your Credentials**
   - After creation, you'll see:
     - **Client ID**: `xxxxx.apps.googleusercontent.com`
     - **Client Secret**: `xxxxxxxxx`
   - Copy both values

### 3. Add Credentials to Rails

1. **Edit Rails credentials:**
   ```bash
   bin/rails credentials:edit
   ```

2. **Add your Google OAuth credentials:**
   ```yaml
   google_client_id: your-client-id.apps.googleusercontent.com
   google_client_secret: your-client-secret
   ```

3. **Save and exit** (`:wq` in vim, `Ctrl+X` then `Y` in nano)

4. **Verify credentials are saved:**
   ```bash
   bin/rails console
   ```
   Then type:
   ```ruby
   Rails.application.credentials.dig(:google_client_id)
   # Should output your client ID
   ```

### 4. Restart Your Server

```bash
# Stop your current server (Ctrl+C)
bin/dev
# Or
bin/rails server
```

### 5. Test the OAuth Flow

1. Open your browser: http://localhost:3000
2. Click "Sign in with Google"
3. Select your Google account
4. Grant permissions (first time only)
5. You should be redirected back and signed in! ✅

---

## Troubleshooting

### Still Getting redirect_uri_mismatch?

**Check these:**

1. **Exact URL Match Required**
   - Google requires an EXACT match
   - ✅ Correct: `http://localhost:3000/users/auth/google_oauth2/callback`
   - ❌ Wrong: `http://localhost:3000/users/auth/google_oauth2/callback/` (extra slash)
   - ❌ Wrong: `http://localhost:3000/auth/google_oauth2/callback` (missing /users)

2. **Verify Port Number**
   - Make sure your Rails server is running on port 3000
   - Check terminal output: should say "Listening on http://127.0.0.1:3000"

3. **Check Credentials Are Loaded**
   ```bash
   bin/rails console
   Rails.application.credentials.dig(:google_client_id)
   # Should return your client ID, not nil
   ```

4. **Clear Browser Cache**
   - Sometimes old OAuth data gets cached
   - Try in an incognito/private browser window

5. **Check Routes**
   ```bash
   bin/rails routes | grep omniauth
   ```
   Should show:
   ```
   user_google_oauth2_omniauth_authorize GET|POST /users/auth/google_oauth2(.:format)
   user_google_oauth2_omniauth_callback  GET|POST /users/auth/google_oauth2/callback(.:format)
   ```

### Error: "This app isn't verified"

This is **normal** for development apps. Click:
1. "Advanced"
2. "Go to [app name] (unsafe)"

For production, you'll need to submit your app for Google verification.

### Error: "Access blocked: Authorization Error"

Check:
- OAuth consent screen is properly configured
- You added your email as a test user (for External apps in development)
- Required scopes are added: `userinfo.email` and `userinfo.profile`

### User Can't Be Saved / Validation Errors

Check database migrations:
```bash
bin/rails db:migrate:status
```

Make sure you have these columns in users table:
- `provider` (string)
- `uid` (string)
- `name` (string)
- `avatar_url` (string)

If missing, create a migration:
```bash
bin/rails generate migration AddOmniauthToUsers provider:string uid:string name:string avatar_url:string
bin/rails db:migrate
```

---

## Code Configuration Summary

Your app now has the following configuration:

### 1. Devise Initializer
[config/initializers/devise.rb:42-52](config/initializers/devise.rb#L42-L52)
```ruby
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

### 2. User Model
[app/models/user.rb](app/models/user.rb)
```ruby
devise :database_authenticatable, :registerable,
       :recoverable, :rememberable, :validatable,
       :omniauthable, omniauth_providers: [:google_oauth2]

def self.from_omniauth(auth)
  where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
    user.email = auth.info.email
    user.password = Devise.friendly_token[0, 20]
    user.name = auth.info.name
    user.avatar_url = auth.info.image
  end
end
```

### 3. Callbacks Controller
[app/controllers/users/omniauth_callbacks_controller.rb](app/controllers/users/omniauth_callbacks_controller.rb)
```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :google_oauth2

  def google_oauth2
    @user = User.from_omniauth(request.env['omniauth.auth'])
    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
    else
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def failure
    redirect_to root_path
  end
end
```

### 4. Routes
[config/routes.rb](config/routes.rb)
```ruby
devise_for :users, controllers: {
  omniauth_callbacks: 'users/omniauth_callbacks'
}
```

### 5. Sign-in Button
[app/views/pages/home.html.erb](app/views/pages/home.html.erb)
```erb
<%= button_to user_google_oauth2_omniauth_authorize_path,
              method: :post,
              data: { turbo: false } do %>
  Sign in with Google
<% end %>
```

---

## Important Notes

### ⚠️ Do NOT Create omniauth.rb Initializer

When using Devise with OmniAuth, do **NOT** create a separate `config/initializers/omniauth.rb` file. This will conflict with Devise's OmniAuth configuration.

All OmniAuth configuration should be in `config/initializers/devise.rb`.

### 🔒 Security Best Practices

1. **Never commit credentials** - They're stored in encrypted credentials file
2. **Keep master.key safe** - Required to decrypt credentials
3. **Use HTTPS in production** - Required for OAuth2
4. **Different credentials per environment** - Development vs Production

### 📝 Testing

To test manually:
```bash
# Start console
bin/rails console

# Test creating a user from OAuth data
auth = OmniAuth::AuthHash.new({
  provider: 'google_oauth2',
  uid: '123456',
  info: {
    email: 'test@example.com',
    name: 'Test User',
    image: 'http://example.com/image.jpg'
  }
})

user = User.from_omniauth(auth)
puts user.inspect
```

---

## References

- [Devise Wiki - OmniAuth Overview](https://github.com/heartcombo/devise/wiki/OmniAuth:-Overview)
- [omniauth-google-oauth2 Gem](https://github.com/zquestz/omniauth-google-oauth2)
- [Google OAuth2 Documentation](https://developers.google.com/identity/protocols/oauth2)

---

## Need Help?

If you still have issues:

1. Check Rails logs: `tail -f log/development.log`
2. Check browser developer console for errors
3. Verify all steps were followed exactly
4. Make sure your Google Cloud project is properly set up
5. Try with a fresh browser session (incognito mode)
