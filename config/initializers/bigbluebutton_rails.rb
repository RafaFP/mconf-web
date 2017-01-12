# This file is part of Mconf-Web, a web application that provides access
# to the Mconf webconferencing system. Copyright (C) 2010-2015 Mconf.
#
# This file is licensed under the Affero General Public License version
# 3 or later. See the LICENSE file.

Rails.application.config.to_prepare do

  # Monkey-patches to add support for guest users in bigbluebutton_rails.
  # TODO: This is not standard in BBB yet, so this should be temporary and might
  #       be moved to bigbluebutton_rails in the future.
  BigbluebuttonRoom.instance_eval do
    @guest_support = true
    class << self; attr_reader :guest_support; end
  end
  BigbluebuttonRoom.class_eval do
    # Copy of the default Bigbluebutton#join_url with support to :guest
    def join_url(username, role, key=nil, options={})
      require_server

      case role
      when :moderator
        r = self.server.api.join_meeting_url(self.meetingid, username, self.moderator_api_password, options)
      when :attendee
        r = self.server.api.join_meeting_url(self.meetingid, username, self.attendee_api_password, options)
      when :guest
        params = { :guest => true }.merge(options)
        r = self.server.api.join_meeting_url(self.meetingid, username, self.attendee_api_password, params)
      else
        r = self.server.api.join_meeting_url(self.meetingid, username, map_key_to_internal_password(key), options)
      end

      r.strip! unless r.nil?
      r
    end

    # Returns whether the `user` created the current meeting on this room
    # or not. Has to be called after a `fetch_meeting_info`, otherwise will always
    # return false.
    def user_created_meeting?(user)
      meeting = get_current_meeting()
      unless meeting.nil?
        meeting.created_by?(user)
      else
        false
      end
    end

    # Currently room is public only if belonging to a public space
    def public?
      owner_type == "Space" && Space.where(:id => owner_id, :public => true).present?
    end

    def invitation_url
      Rails.application.routes.url_helpers.join_webconf_url(self, host: Site.current.domain_with_protocol)
    end

    def dynamic_metadata
      meta = {
        "mconfweb-url" => Rails.application.routes.url_helpers.root_url(host: Site.current.domain_with_protocol),
        "mconfweb-room-type" => self.try(:owner).try(:class).try(:name)
      }

      institution = self.try(:owner).try(:institution)
      if institution.present?
        name = institution.try(:name) || ""
        acronym = institution.try(:acronym) || ""
        meta.merge!({ "mconfweb-institution-name" => name, "mconfweb-institution-acronym" => acronym })
      end

      meta
    end

    # Selects always the default server, but sets on it the shared secret of the institution that
    # owns this room, if any.
    def select_server(api_method=nil)
      server = BigbluebuttonServer.default

      meeting = self.get_current_meeting
      if meeting.present? && !meeting.server_secret.blank? && !meeting.ended?
        Rails.logger.info "#select_server: selected the secret from the meeting for #{self.meetingid}, #{self.create_time}"
        server.secret = meeting.server_secret
      elsif self.owner && self.owner.institution && !self.owner.institution.secret.blank?
        Rails.logger.info "#select_server: selected the secret from the institution for #{self.meetingid}, #{self.create_time}"
        server.secret = self.owner.institution.secret
      else
        Rails.logger.info "#select_server: selected the secret from the server for #{self.meetingid}, #{self.create_time}"
      end

      server
    end
  end

  BigbluebuttonServer.instance_eval do

    # The server used on Mconf-Web is always the first one. We add this method
    # to wrap it and make it easier to change in the future.
    def default
      self.first
    end

  end

  BigbluebuttonMeeting.instance_eval do
    include PublicActivity::Model

    tracked only: [:create], owner: :room,
      recipient: -> (ctrl, model) { model.room.owner },
      params: {
        creator_id: -> (ctrl, model) {
          model.try(:creator_id)
        },
        creator_username: -> (ctrl, model) {
          id = model.try(:creator_id)
          user = User.find_by(id: id)
          user.try(:username)
        }
      }
  end

  BigbluebuttonRecording.instance_eval do
    include UpdateInstitutionRecordingsDisk
  end

  BigbluebuttonRecording.class_eval do

    # Search recordings based on a list of words
    scope :search_by_terms, -> (words) {
      query = joins(:room).includes(:room)

      if words.present?
        words ||= []  
        words = [words] unless words.is_a?(Array)
        query_strs = []
        query_params = []
        query_orders = []

        words.reject(&:blank?).each do |word|
          str  = "bigbluebutton_recordings.name LIKE ? OR bigbluebutton_recordings.description LIKE ?"
          str += " OR bigbluebutton_recordings.recordid LIKE ? OR bigbluebutton_rooms.name LIKE ?"
          query_strs << str
          query_params += ["%#{word}%", "%#{word}%"]
          query_params += ["%#{word}%", "%#{word}%"]
          query_orders += [
            "CASE WHEN bigbluebutton_recordings.name LIKE '%#{word}%' THEN 1 ELSE 0 END + \
             CASE WHEN bigbluebutton_recordings.description LIKE '%#{word}%' THEN 1 ELSE 0 END + \
             CASE WHEN bigbluebutton_recordings.recordid LIKE '%#{word}%' THEN 1 ELSE 0 END + \
             CASE WHEN bigbluebutton_rooms.name LIKE '%#{word}%' THEN 1 ELSE 0 END"
          ]
        end
        query = query.where(query_strs.join(' OR '), *query_params.flatten).order(query_orders.join(' + ') + " DESC")
     
      end

      query
    }

    # The default ordering for search methods
    scope :search_order, -> {
      order("bigbluebutton_recordings.start_time DESC")
    }

    # Filters a query to return only recordings that have at least one playback format
    scope :has_playback, -> {
      where(id: BigbluebuttonPlaybackFormat.select(:recording_id).distinct)
    }

    # Filters a query to return only recordings that have no playback format
    scope :no_playback, -> {
      where.not(id: BigbluebuttonPlaybackFormat.select(:recording_id).distinct)
    }
  end
end
