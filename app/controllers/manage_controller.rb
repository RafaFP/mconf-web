# -*- coding: utf-8 -*-
# This file is part of Mconf-Web, a web application that provides access
# to the Mconf webconferencing system. Copyright (C) 2010-2012 Mconf
#
# This file is licensed under the Affero General Public License version
# 3 or later. See the LICENSE file.

class ManageController < ApplicationController
  authorize_resource :class => false

  def users
    name = params[:q]
    partial = params.delete(:partial) # otherwise the pagination links in the view will include this param

    if current_user.superuser?
      query = User.with_disabled
    else
      query = current_user.institution.users
    end
    query = query.joins(:profile).includes(:profile).order("profiles.full_name")
    if name.present?
      query = query.where("profiles.full_name like ? OR users.username like ? OR users.email like ?", "%#{name}%", "%#{name}%", "%#{name}%")
    end
    @users = query.paginate(:page => params[:page], :per_page => 20)

    if partial
      render :partial => 'users_list', :layout => false
    else
      render :layout => 'no_sidebar'
    end
  end

  def spaces
    name = params[:q]
    partial = params.delete(:partial) # otherwise the pagination links in the view will include this param

    if current_user.superuser?
      query = Space.with_disabled
    else
      query = current_user.institution.spaces
    end
    query = query.order("name")
    if name.present?
      query = query.where("name like ?", "%#{name}%")
    end
    @spaces = query.paginate(:page => params[:page], :per_page => 20)

    if partial
      render :partial => 'spaces_list', :layout => false, :locals => { :spaces => @spaces }
    else
      render :layout => 'no_sidebar'
    end
  end

  def institutions
    @institutions = Institution.find(:all, :order => "name").paginate(:page => params[:page], :per_page => 20)
    render :layout => 'no_sidebar'
  end

  def spam
    @spam_posts = Post.where(:spam => true).all
    render :layout => 'no_sidebar'
  end

end
