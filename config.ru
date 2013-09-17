$stdout.sync = true

require './web.rb'

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
end

unless ENV['COOKIE_SECRET']
	abort("missing env var: please set COOKIE_SECRET")
end

unless ENV['BASE_URL']
	abort("missing env var: please set BASE_URL")
end

use Rack::Session::Cookie, :secret => ENV['COOKIE_SECRET']

map App.assets_prefix do
  run App.assets
end

map '/' do
  run App
end
