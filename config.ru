$stdout.sync = true

require './web.rb'

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
end

map App.assets_prefix do
  run App.assets
end

map '/' do
  run App
end
