# -*- coding: utf-8 -*-
# This file is part of Mconf-Web, a web application that provides access
# to the Mconf webconferencing system. Copyright (C) 2010-2015 Mconf.
#
# This file is licensed under the Affero General Public License version
# 3 or later. See the LICENSE file.

class InvitationSenderWorker < BaseWorker

  # Finds the target notification and sends it. Marks it as notified.
  def self.perform(invitation_id)
    invitation = Invitation.find(invitation_id)
    if !invitation.sent?
      result = invitation.send_invitation
      invitation.update_attributes(sent: true, result: result)
    end
  end

end
