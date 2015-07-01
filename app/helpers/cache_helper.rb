module CacheHelper
  def self.cache_settings
    {
      cache_path: proc { "#{params[:controller]}_#{params[:action]}_#{I18n.locale}" +
        Digest::MD5.hexdigest("#{request.path}|#{params.to_json}|#{cookies[ShikimoriController::COOKIE_AGE_OVER_18].to_json}") +
        "_#{json?}_#{request.xhr?}_#{turbolinks_request?}_#{request.host}" },
      unless: proc { user_signed_in? },
      expires_in: 2.days
    }
  end

  def russian_names_key
    if user_signed_in? && current_user.preferences.russian_names? && I18n.russian?
      'rus'
    else
      "eng_#{I18n.locale}"
    end
  end

  def russian_genres_key
    if user_signed_in? && current_user.preferences.russian_genres? && I18n.russian?
      'rus'
    else
      "eng_#{I18n.locale}"
    end
  end

  def social_key
    !user_signed_in? || current_user.preferences.show_social_buttons? ? 'social' : 'no_social'
  end
end
