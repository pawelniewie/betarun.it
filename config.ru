$stdout.sync = true

require './web.rb'

%w{FACEBOOK_APP_ID FACEBOOK_SECRET COOKIE_SECRET BASE_URL APP_NAME MANDRILL_KEY}.each do |var|
  abort("missing env var: please set #{var}") unless ENV[var]
end

if ENV['GOOGLE_ANALYTICS']
	# Google Analytics: UNCOMMENT IF DESIRED, THEN ADD YOUR OWN ACCOUNT INFO HERE!
	require 'rack/google-analytics'
	use Rack::GoogleAnalytics, :tracker => ENV['GOOGLE_ANALYTICS']
end

use Rack::Session::Cookie, :secret => ENV['COOKIE_SECRET']

map App.assets_prefix do
  run App.assets
end

map '/' do
  run App
end
