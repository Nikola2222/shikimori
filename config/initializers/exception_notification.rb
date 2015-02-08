require 'exception_notification/rails'
require 'exception_notification/sidekiq'

ExceptionNotification.configure do |config|
  # Ignore additional exception types.
  # ActiveRecord::RecordNotFound, AbstractController::ActionNotFound and ActionController::RoutingError are already added.
  config.ignored_exceptions += %w{NotFound Unauthorized Forbidden ActionController::InvalidAuthenticityToken ActionController::UnknownFormat CanCan::AccessDenied}
  # config.ignored_exceptions += %w{ActionView::TemplateError CustomError}

  config.ignore_if do |exception, options|
    !Rails.env.production? && !Rails.env.staging?
  end

  config.add_notifier :email,
    sender_address: %{"ExceptionNotification" <exceptions@shikimori.org>},
    exception_recipients: %w{takandar@gmail.com},
    delivery_method: :smtp

  config.add_notifier :slack,
    webhook_url: 'https://hooks.slack.com/services/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',
    channel: '#exceptions',
    additional_parameters: {
      icon_url: 'http://beta.shikimori.org/favicons/favicon-72x72.png'
    }
end
