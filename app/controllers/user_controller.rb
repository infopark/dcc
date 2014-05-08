class UserController < ApplicationController

  def login
    if request.post?
      user = params[:user] || {}
      @current_user = Infopark::Crm::Contact.authenticate user[:login], user[:password]
      session[:user] = @current_user.attributes
      flash[:notice] = t('user.login_successful')
      redirect
    end
  rescue Infopark::Crm::Errors::AuthenticationFailed, ActiveResource::ResourceInvalid
    flash.now[:error] = t('user.login_failed')
  ensure
    @current_user.password = nil if @current_user
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
