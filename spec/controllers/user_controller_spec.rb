# encoding: utf-8
require 'spec_helper'

describe UserController do
  let(:return_to) { nil }

  before do
    Rails.application.config.stub need_authorization: true
  end

  shared_examples_for "redirecting" do
    context "when a return_to url is specified" do
      let(:return_to) { "/rome" }

      it { should redirect_to "/rome" }
    end

    context "when no return_to url is specified" do
      let(:return_to) { nil }

      it { should redirect_to "/" }
    end
  end

  describe "#login POST" do
    context "when good credentials are given" do
      let(:the_crm_user) do
        Infopark::Crm::Contact.new(login: "me", password: "and my pass")
      end

      before do
        Infopark::Crm::Contact.stub(:authenticate).with("me", "and my pass").and_return the_crm_user
        post :login, user: {login: "me", password: "and my pass"}, return_to: return_to
      end

      it "assigns the current user" do
        assigns(:current_user).should eq the_crm_user
      end

      it "sets the session user to the user's attributes with nil password" do
        session[:user].should eq({"login" => "me", "password" => nil})
      end

      it "flashes a notice" do
        flash[:notice].should_not be_nil
      end

      it_behaves_like "redirecting"
    end

    context "when bad credentials are given" do
      before do
        Infopark::Crm::Contact.stub(:authenticate).with("me", "and my pass").and_raise(
            Infopark::Crm::Errors::AuthenticationFailed.new "go away")
        post :login, user: {login: "me", password: "and my pass"}
      end

      it "flashes an error" do
        flash[:error].should_not be_nil
      end

      it "does not redirect" do
        response.should be_ok
      end
    end
  end

  describe "#logout" do
    context "when logged in" do
      before do
        session[:user] = {login: "me"}
        post :logout, return_to: return_to
      end

      it "sets the session user to nil" do
        session[:user].should be_nil
      end

      it_behaves_like "redirecting"
    end

    context "when not logged in" do
      before do
        session[:user] = nil
        post :logout, return_to: return_to
      end

      it "keeps the session user at nil" do
        session[:user].should be_nil
      end

      it_behaves_like "redirecting"
    end
  end
end
