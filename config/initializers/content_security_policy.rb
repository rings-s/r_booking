# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval,
                      'https://accounts.google.com',
                      'https://unpkg.com',
                      'https://cdn.jsdelivr.net',
                      'https://tile.openstreetmap.org'
    policy.style_src   :self, :https, :unsafe_inline,
                      'https://unpkg.com',
                      'https://cdn.jsdelivr.net'
    policy.frame_src   :self, 'https://accounts.google.com'
    policy.connect_src :self, :https,
                      'https://accounts.google.com',
                      'https://tile.openstreetmap.org',
                      'https://nominatim.openstreetmap.org'
    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)

  # Report violations without enforcing the policy (good for debugging)
  config.content_security_policy_report_only = true
end
