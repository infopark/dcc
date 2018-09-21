class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :set_locale
  before_filter :ensure_and_set_user, :except => [:login, :logout]

  helper_method :logged_in?

  protected

  def logged_in?
    !session[:user].blank?
  end

  private

  def set_locale
    languages = http_accept_language.user_preferred_languages || []
    # workaround for bug in http_accept_language
    languages = [] if (languages.size == 1 && !(languages.first =~ /^[-a-z]$/))
    languages << "en"
    http_accept_language.user_preferred_languages = languages.map {|l| l.split("-").first }.uniq
    I18n.locale = http_accept_language.preferred_language_from I18n.available_locales
  end

  def ensure_and_set_user
    if !Rails.application.config.need_authorization
      @current_user = DummyUser.new
      session[:user] ||= @current_user.attributes
    elsif logged_in?
      @current_user = Crm::Contact.new(session[:user].dup || {})
    else
      redirect_to login_path(:return_to => request.path)
    end
  end

  class DummyUser
    def login
      "max@muster.de"
    end

    def first_name
      "Max"
    end

    def last_name
      "Muster"
    end

    def attributes
      {"login" => "dummy"}
    end

    def to_s
      "the dummy user"
    end
  end

end
