# encoding: utf-8
require 'spec_helper'

describe UserController do
  let(:return_to) { nil }

  before do
    allow(Rails.application.config).to receive_messages need_authorization: true
  end

  shared_examples_for "redirecting" do
    context "when a return_to url is specified" do
      let(:return_to) { "/rome" }

      it { is_expected.to redirect_to "/rome" }
    end

    context "when no return_to url is specified" do
      let(:return_to) { nil }

      it { is_expected.to redirect_to "/" }
    end
  end

  describe "#login POST" do
    context "when good credentials are given" do
      let(:the_crm_user) do
        Crm::Contact.new("login" => "me")
      end

      before do
        allow(Crm::Contact).to receive(:authenticate).with("me", "and my pass").and_return the_crm_user
        post :login, params: {user: {login: "me", password: "and my pass"}, return_to: return_to}
      end

      it "assigns the current user" do
        expect(assigns(:current_user)).to eq the_crm_user
      end

      it "sets the session user to the user's attributes" do
        expect(session[:user]).to eq({"login" => "me"})
      end

      it "flashes a notice" do
        expect(flash[:notice]).not_to be_nil
      end

      it_behaves_like "redirecting"
    end

    context "when bad credentials are given" do
      before do
        allow(Crm::Contact).to receive(:authenticate).with("me", "and my pass").and_return(nil)
        post :login, params: {user: {login: "me", password: "and my pass"}}
      end

      it "flashes an error" do
        expect(flash[:error]).not_to be_nil
      end

      it "does not redirect" do
        expect(response).to be_ok
      end
    end
  end

  describe "#logout" do
    context "when logged in" do
      before do
        session[:user] = {login: "me"}
        post :logout, params: {return_to: return_to}
      end

      it "sets the session user to nil" do
        expect(session[:user]).to be_nil
      end

      it_behaves_like "redirecting"
    end

    context "when not logged in" do
      before do
        session[:user] = nil
        post :logout, params: {return_to: return_to}
      end

      it "keeps the session user at nil" do
        expect(session[:user]).to be_nil
      end

      it_behaves_like "redirecting"
    end
  end
end
