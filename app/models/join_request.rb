# This file is part of Mconf-Web, a web application that provides access
# to the Mconf webconferencing system. Copyright (C) 2010-2012 Mconf
#
# This file is licensed under the Affero General Public License version
# 3 or later. See the LICENSE file.

class JoinRequest < ActiveRecord::Base
  include PublicActivity::Common

  # the user that is being invited
  belongs_to :candidate, :class_name => "User"
  # the person that is inviting
  belongs_to :introducer, :class_name => "User"

  # the container (event, space)
  belongs_to :group, :polymorphic => true

  belongs_to :role

  validates :email, :presence => true, :email => true

  # The request can either be an invitation ('invite') or a 'request' for membership
  validates :request_type, :presence => true

  attr_writer :processed
  before_save :set_processed_at
  before_save :add_candidate_to_group

  validates_uniqueness_of :candidate_id,
                          :scope => [ :group_id, :group_type, :processed_at ]

  validates_uniqueness_of :email,
                          :scope => [ :group_id, :group_type, :processed_at ]

  validate :candidate_is_not_introducer

  validates_length_of :comment, maximum: 255

  # Create a new activity after saving
  after_create :new_activity
  def new_activity
    parameters = { :candidate_id => candidate.id, :username => candidate.name }
    unless introducer.nil?
      parameters[:introducer_id] = introducer.id
      parameters[:introducer] = introducer.name
    end
    create_activity self.request_type, :owner => self.group, :parameters => parameters
  end

  # Has this Admission been processed?
  def processed?
    processed_at.present?
  end

  # Has this Admission been recently processed? (typically in this request)
  def recently_processed?
    @processed.present?
  end

  def role
    Role.find_by_id(self.role_id).name
  end

  def space?
    group_type == 'Space'
  end

  private

  def set_processed_at
    @processed && self.processed_at = Time.now.utc
  end

  def add_candidate_to_group
    group.add_member!(candidate, role) if accepted?
  end

  def candidate_is_not_introducer
    if candidate == introducer
      errors.add(:base, I18n.t('admission.errors.candidate_equals_introducer'))
    end
  end
end
