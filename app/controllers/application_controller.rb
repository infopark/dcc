class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :ensure_and_set_user, :except => [:login, :logout]

  helper_method :logged_in?

  protected

  def logged_in?
    !session[:user].blank?
  end

  private

  def ensure_and_set_user
    if !Rails.application.config.need_authorization
      # Automatically log in as thomas.witt
      @current_user ||= Infopark::Crm::Contact.find('dd19b203c0fb60519823d1a4d349ccbf')
      session[:user] ||= @current_user.attributes
    elsif logged_in?
      @current_user ||= Infopark::Crm::Contact.new(session[:user].dup || {})
    else
      redirect_to login_path(:return_to => request.path)
    end
  end

end
