json.messages @messages do |message|
  json.extract! message, :id, :text, :created_at
  json.user message.user, :id, :username, :avatar
  json.read check_if_read(message)
end

json.page params[:page].to_i
json.total_pages @messages.total_pages