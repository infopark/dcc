class UserController < ApplicationController

  def login
    if request.post?
      @current_user = Infopark::Crm::Contact.new(params[:user] || {:login => nil, :password => nil})
      @current_user =
          Infopark::Crm::Contact.authenticate(@current_user.login, @current_user.password)
      if @current_user
        session[:user] = @current_user.attributes
        flash[:notice] = t('user.login_successful')
        redirect_to params[:return_to].blank? ? root_path : params[:return_to]
      else
        flash.now[:error] = t('user.login_failed')
      end
    end
  rescue Infopark::Crm::Errors::AuthenticationFailed, ActiveResource::ResourceInvalid
    flash.now[:error] = t('user.login_failed')
  ensure
    @current_user.password = nil if @current_user
  end

  def logout
    session[:user] = nil
    redirect_to params[:return_to].blank? ? root_path : params[:return_to]
  end

end
