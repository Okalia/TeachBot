class ApiController < ApplicationController
  require 'net/http'
  include ApiHelper::Facebook

  before_action :require_guest, only: [:facebook_oauth]
  before_action :require_user, only: [:conversations, :conversation_messages]

  def bot
    bot = TeachBot::Commands.new(request)
    render :json => bot.generate_response, status: bot.status
  end

  def facebook_oauth

    return fb_validation_error unless code_exist?(request[:code])

    access_token = get_access_token request[:code]

    return fb_validation_error unless valid_access_token?(access_token['access_token'])

    fb_user = get_user_data(access_token['access_token'])

    begin
      user = create_or_initialize_user(fb_user)
    rescue StandardError => e
      return fb_validation_error(e.message)
    end

    log_in user

    redirect_to root_path
  end

  def subscriptions_pagination
    user = get_from_cache(User, params[:user_id])
    subscriptions = user.subscriptions.page(params[:page]).per(1)
    render :partial => 'courses/pagination', locals: {subscriptions: subscriptions}
  end

  def user_courses_pagination
    @user = get_from_cache(User, params[:user_id])
    @courses = @user.courses.page(params[:page]).per(1)
  end

  def subscribers
    @course = Course.find(params[:id])
  end

  def find_user_by_username
    if params[:username]
      users = User.select(:id, :username, :avatar).where('username LIKE ?', "%#{params[:username]}%").limit(10)
      render :json => {users: users}
    end
  end

  def conversations
    @chats = current_user.chats.includes(:users).distinct
  end

  def conversation_messages

    chat = Chat.find(params[:id])
    unless current_user_related_to_chat(chat)
      error_message(['Forbidden'], 403)
    end

    @messages = chat.messages.reverse_order.page(params[:page]).per(2)
  end


  private

  def fb_validation_error(error = 'Something went wrong. Try login with facebook again')
    redirect_to root_path, flash: {danger_notice: error}
  end

  def current_user_related_to_chat(chat)
    return true if chat.id == 1 # public_chat
    chat.users.include?(current_user)
  end
end
