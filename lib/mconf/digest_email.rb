# This file is part of Mconf-Web, a web application that provides access
# to the Mconf webconferencing system. Copyright (C) 2010-2012 Mconf
#
# This file is licensed under the Affero General Public License version
# 3 or later. See the LICENSE file.

module Mconf
  class DigestEmail
    def self.send_daily_digest
      User.where(:receive_digest => User::RECEIVE_DIGEST_DAILY).each do |user|
        now = Time.zone.now
        from = now - 1.day
        send_digest(user, from, now)
      end
    end

    def self.send_weekly_digest
      User.where(:receive_digest => User::RECEIVE_DIGEST_WEEKLY).each do |user|
        now = Time.zone.now
        from = now - 7.day
        send_digest(user, from, now)
      end
    end

    def self.send_digest(to, date_start, date_end)
      posts, news, attachments, events, inbox = get_activity(to, date_start, date_end)

      unless posts.empty? && news.empty? && attachments.empty? && events.empty? && inbox.empty?
        ApplicationMailer.digest_email(to.id, posts, news, attachments, events, inbox).deliver
      end
    end

    def self.get_activity(user, date_start, date_end)
      user_spaces = user.spaces.map{ |s| s.id }
      filter = lambda do |model|
        model.where('space_id IN (?)', user_spaces).
        where("updated_at >= ?", date_start).
        where("updated_at <= ?", date_end).
        order('updated_at desc').map { |x| x.id }
      end

      posts = filter.call(Post)
      news = filter.call(News)
      attachments = filter.call(Attachment)

      # Events that started or finished in the period
      # TODO: review and improve this with MwebEvents
      if Mconf::Modules.mod_enabled?('events')
        events = MwebEvents::Event.
          where(:owner_id => user_spaces, :owner_type => "Space").
          within(date_start, date_end).
          order('updated_at desc').map { |x| x.id }
      else
        events = []
      end

      # Unread messages in the inbox
      inbox = PrivateMessage.where(:checked => [false, nil]).inbox(user)

      [ posts, news, attachments, events, inbox ]
    end

  end
end
