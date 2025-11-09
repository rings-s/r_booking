class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # I18n locale handling
  before_action :configure_locale

  def configure_locale
    I18n.locale = params[:locale] || session[:locale] || extract_locale_from_accept_language_header || I18n.default_locale
    session[:locale] = I18n.locale
  end

  def set_locale
    locale = params[:locale]&.to_sym
    if locale && I18n.available_locales.include?(locale)
      session[:locale] = locale
      I18n.locale = locale
      flash[:success] = I18n.t('common.language_changed')
    else
      flash[:error] = I18n.t('common.invalid_language')
    end

    # Redirect back to the previous page but force the new locale param
    redirect_to safe_redirect_with_locale(locale)
  end

  def safe_redirect_with_locale(locale)
    referer = request.referer
    return root_path(locale: locale) if referer.blank?

    begin
      uri = URI.parse(referer)
      # Merge/override locale in the query params
      query_params = Rack::Utils.parse_nested_query(uri.query).merge("locale" => locale.to_s)
      uri.query = query_params.to_query.presence
      uri.to_s
    rescue URI::InvalidURIError
      root_path(locale: locale)
    end
  end

  def default_url_options
    { locale: I18n.locale }
  end

  private

  def extract_locale_from_accept_language_header
    return unless request.env['HTTP_ACCEPT_LANGUAGE']

    request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first&.to_sym
  end
end
