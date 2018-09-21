class UserController < ApplicationController

  def login
    if request.post?
      user = params[:user] || {}
      if @current_user = Crm::Contact.authenticate(user[:login], user[:password])
        session[:user] = @current_user.attributes
        flash[:notice] = t('user.login_successful')
        redirect
      else
        flash.now[:error] = t('user.login_failed')
      end
    end
  end

  def logout
    session[:user] = nil
    redirect
  end

  private

  def redirect
    redirect_to params[:return_to].blank? ? root_path : params[:return_to]
  end

end
