# encoding: utf-8
require 'spec_helper'

class TestAuthenticationController < ApplicationController
  def any_target
    render text: "You got it: #{@current_user}"
  end
end

describe TestAuthenticationController do
  before do
    Rails.application.routes.draw do
      get 'test_authentication/any_target' => "test_authentication#any_target"
      get 'login' => 'user#login'
    end
  end

  after do
    Rails.application.reload_routes!
  end

  subject { get :any_target }

  context "when authentication is needed" do
    before do
      Rails.application.config.stub need_authorization: true
    end

    context "when not authenticated" do
      it { should redirect_to "/login?return_to=%2Ftest_authentication%2Fany_target" }
    end

    context "when authenticated" do
      before do
        session[:user] = "session user"
        Infopark::Crm::Contact.stub new: "crm user"
      end

      it { should be_ok }
      its(:body) { should eq "You got it: crm user" }

      it "initializes the current user with the session data" do
        Infopark::Crm::Contact.should_receive(:new).with("session user").and_return "the crm user"
        get :any_target
        assigns(:current_user).should eq "the crm user"
      end
    end
  end

  context "when authentication is not needed" do
    before do
      Rails.application.config.stub need_authorization: false
    end

    it { should be_ok }
    its(:body) { should eq "You got it: the dummy user" }

    it "sets the current and the session user to a dummy user" do
      get :any_target
      assigns(:current_user).should be_a ApplicationController::DummyUser
      session[:user].should eq({login: "dummy"})
    end
  end
end
