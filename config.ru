$stdout.sync = true

require './web.rb'

%w{FACEBOOK_APP_ID FACEBOOK_SECRET COOKIE_SECRET BASE_URL APP_NAME}.each do |var|
  abort("missing env var: please set #{var}")
end

use Rack::Session::Cookie, :secret => ENV['COOKIE_SECRET']

map App.assets_prefix do
  run App.assets
end

map '/' do
  run App
end
