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
      match 'test_authentication/any_target' => "test_authentication#any_target"
      match 'login' => 'user#login'
    end
  end

  after do
    Rails.application.reload_routes!
  end

  subject { get :any_target }

  context "when authentication is needed" do
    before do
      allow(Rails.application.config).to receive_messages need_authorization: true
    end

    context "when not authenticated" do
      it { is_expected.to redirect_to "/login?return_to=%2Ftest_authentication%2Fany_target" }
    end

    context "when authenticated" do
      before do
        session[:user] = "session user"
        allow(Infopark::Crm::Contact).to receive_messages new: "crm user"
      end

      it { is_expected.to be_ok }
      its(:body) { is_expected.to eq "You got it: crm user" }

      it "initializes the current user with the session data" do
        expect(Infopark::Crm::Contact).to receive(:new).with("session user").and_return "the crm user"
        get :any_target
        expect(assigns(:current_user)).to eq "the crm user"
      end
    end
  end

  context "when authentication is not needed" do
    before do
      allow(Rails.application.config).to receive_messages need_authorization: false
    end

    it { is_expected.to be_ok }
    its(:body) { is_expected.to eq "You got it: the dummy user" }

    it "sets the current and the session user to a dummy user" do
      get :any_target
      expect(assigns(:current_user)).to be_a ApplicationController::DummyUser
      expect(session[:user]).to eq({login: "dummy"})
    end
  end
end
