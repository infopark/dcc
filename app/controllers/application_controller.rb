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
    if logged_in?
      user_session = session[:user].dup
      @current_user ||= Infopark::Crm::Contact.new(user_session || {})
    else
      redirect_to login_path(:return_to => request.path)
    end
  end

end
