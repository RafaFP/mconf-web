# This file is part of Mconf-Web, a web application that provides access
# to the Mconf webconferencing system. Copyright (C) 2010-2012 Mconf
#
# This file is licensed under the Affero General Public License version
# 3 or later. See the LICENSE file.

require "spec_helper"

describe Event do

  let(:event) { FactoryGirl.create(:event) }

  it "should not validate an event with wrong date range" do
  end

  it "creates a new instance given valid attributes" do
    FactoryGirl.build(:event).should be_valid
  end

  # it { should validate_presence_of(:name) }
  # it { should validate_presence_of(:permalink) }

  it { should have_many(:participants).dependent(:destroy) }

  it { should respond_to(:mails) }
  it { should respond_to(:"mails=") }

  it { should respond_to(:ids) }
  it { should respond_to(:"ids=") }

  it { should respond_to(:notification_ids) }
  it { should respond_to(:"notification_ids=") }

  it { should respond_to(:invite_msg) }
  it { should respond_to(:"invite_msg=") }

  it { should respond_to(:invit_introducer_id) }
  it { should respond_to(:"invit_introducer_id=") }

  it { should respond_to(:notif_sender_id) }
  it { should respond_to(:"notif_sender_id=") }

  it { should respond_to(:notify_msg) }
  it { should respond_to(:"notify_msg=") }

  it { should respond_to(:edit_date_action) }
  it { should respond_to(:"edit_date_action=") }

  it "#set_author_as_organizer"
  it "sets the author as organizer when the event is saved"
  it "doesn't set the author as organizer twice when the event is saved"
  it "doesn't set the author as organizer if there's no author set"

  describe ".within" do
    let(:today) { Time.now }

    before(:each) do
      e1 = FactoryGirl.create(:event, #:author => user, :space => space,
                              :start_date => today + 1.day, :end_date => today + 3.day)
      e2 = FactoryGirl.create(:event, #:author => user, :space => space,
                              :start_date => today, :end_date => today + 2.day)
    end

    it { Event.within(today, today + 2.day).should_not be_empty }
    it { Event.within(today + 1.day, today + 2.day).should_not be_empty }
    it { Event.within(today + 4.day, today + 5.day).should be_empty }
  end

  describe "abilities", :abilities => true do
    subject { ability }
    let(:ability) { Abilities.ability_for(user) }
    let(:target) { FactoryGirl.create(:event) }

    context "when is the event author" do
      let(:user) { target.author }
      it { should_not be_able_to_do_anything_to(target).except([:read, :edit, :update, :destroy]) }
    end

    context "when is an anonymous user" do
      let(:user) { User.new }

      context "and the event is in a public space" do
        before { target.space.update_attributes(:public => true) }
        it { should_not be_able_to_do_anything_to(target).except(:read) }
      end

      context "and the event is in a private space" do
        before { target.space.update_attributes(:public => false) }
        it { should_not be_able_to_do_anything_to(target) }
      end

    end

    context "when is a registered user" do
      let(:user) { FactoryGirl.create(:user) }

      context "that's a member of the space the event is in" do
        before { target.space.add_member!(user) }
        it { should_not be_able_to_do_anything_to(target).except([:read, :create]) }
      end

      context "that's not a member of the private space the event is in" do
        before { target.space.update_attributes(:public => false) }
        it { should_not be_able_to_do_anything_to(target) }
      end

      context "that's not a member of the public space the event is in" do
        before { target.space.update_attributes(:public => true) }
        it { should_not be_able_to_do_anything_to(target).except(:read) }
      end
    end

    context "when is a superuser" do
      let(:user) { FactoryGirl.create(:superuser) }
      it { should be_able_to(:manage, target) }
    end
  end

end
