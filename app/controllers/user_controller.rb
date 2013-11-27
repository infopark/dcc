class UserController < ApplicationController

  def login
    if request.post?
      if Rails.env == 'development'
        # Automatically log in as thomas in development mode
        @user = Infopark::Crm::Contact.find('dd19b203c0fb60519823d1a4d349ccbf')
      else
        @user = Infopark::Crm::Contact.new(params[:user] ||
                                           {:login => nil, :password => nil})
        @user = Infopark::Crm::Contact.authenticate(@user.login, @user.password)
      end
      if @user
        flash[:notice] = t('user.login_successful')
        @current_user = session[:user] = @user.attributes
        redirect_to params[:return_to].blank? ?
          root_path : params[:return_to]
      else
        flash.now[:error] = t('user.login_failed')
      end
    end
  rescue Infopark::Crm::Errors::AuthenticationFailed, ActiveResource::ResourceInvalid
    flash.now[:error] = t('user.login_failed')
  ensure
    @user.password = nil if @user
  end

  def logout
    session[:user] = nil
    redirect_to params[:return_to].blank? ? root_path : params[:return_to]
  end

end
