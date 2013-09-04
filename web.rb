require "bundler"
Bundler.setup(:default)
Bundler.require

Mongoid.load!("mongoid.yml")

# See https://developers.facebook.com/docs/reference/api/permissions/
# for a full list of permissions
FACEBOOK_SCOPE = 'email,publish_actions,publish_stream'

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
end

configure do
	enable :sessions

	set :appname, "AppCasts"

  set :public_dir, File.dirname(__FILE__) + '/public'
  set :static, true

  set :haml, { :format => :html5, :escape_html => true }
  set :scss, { :style => :compact, :debug_info => false }

  Compass.add_project_configuration(File.join(Sinatra::Application.root, 'config', 'compass.rb'))
end

configure :production do
	set :raise_errors, false
	set :show_exceptions, false
end

before do
  # HTTPS redirect
  if settings.environment == :production && request.scheme != 'https'
    redirect "https://#{request.env['HTTP_HOST']}"
  end
end

helpers do
  def host
    request.env['HTTP_HOST']
  end

  def scheme
    request.scheme
  end

  def url_no_scheme(path = '')
    "//#{host}#{path}"
  end

  def url(path = '')
    "#{scheme}://#{host}#{path}"
  end

  def authenticator
    @authenticator ||= Koala::Facebook::OAuth.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"], url("/auth/facebook/callback"))
  end

  # allow for javascript authentication
  def access_token_from_cookie
    authenticator.get_user_info_from_cookies(request.cookies)['access_token']
  rescue => err
    warn err.message
  end

  def access_token
  	if session and session[:access_token]
  		return session[:access_token]
  	end
  	access_token_from_cookie
  end
end

class User
	include Mongoid::Document

	has_many :appcasts

	field :email, type: String
	field :fullName, type: String
	field :callingName, type: String
	field :picture, type: String

	index({ email: 1 }, { unique: true })
end

class Appcast
    include Mongoid::Document

		belongs_to :user
    embeds_many :items

    field :name, type: String
    field :url, type: String
    field :description, type: String
    field :language, type: String, default: 'en'

    index({ name: 1 }, { unique: true })
end

class Item
		include Mongoid::Document

		embedded_in :appcast

		field :title, type: String
		field :description, type: String
		field :minimumSystemVersion, type: String
		field :pubDate, type: Time, default: -> { Time.now }
		field :url, type: String
		field :versionNumber, type: Integer
		field :versionString, type: String
		field :size, type: Integer
end

# the facebook session expired! reset ours and restart the process
error(Koala::Facebook::APIError) do
  session[:access_token] = nil
  redirect "/auth/facebook"
end

get '/stylesheets/:name.css' do
  content_type 'text/css', :charset => 'utf-8'
  scss(:"stylesheets/#{params[:name]}" )
end

get '/' do
	haml :index
end

get '/dashboard' do
	redirect '/' if not access_token or session[:user_id].nil?
	user = User.find(session[:user_id])
	appcast = Appcast.find(user.appcast_ids[0])
	haml :dashboard, :locals => {:user => user, :appcast => appcast}
end

# Allows for direct oauth authentication
get "/auth/facebook" do
  session[:access_token] = nil
  redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
end

get '/auth/facebook/callback' do
  session[:access_token] = authenticator.get_access_token(params[:code])
  redirect '/auth/success'
end

get '/auth/success' do
	# Get base API Connection
	@graph  = Koala::Facebook::API.new(access_token)

	profile = @graph.get_object("me")

	user = User.where(email: profile[:email]).first
	if not user
		picture = @graph.get_picture("me")
		user = User.create!(email: profile[:email], fullName: profile[:name], callingName: profile[:first_name], picture: picture)
	end
	if not user.appcasts.exists?
		user.appcasts.push(Appcast.new(name: "Awesome Appcast"))
	end
	session[:user_id] = user._id
	redirect '/dashboard'
end

['/appcasts/*', '/appcasts'].each do |path|
	before path do
	  halt 401, "Not authorized\n" if not access_token
	end
end

get '/appcasts' do
	content_type :json
	appcasts = Appcast.all
	appcasts.to_json
end

post '/appcasts' do
	content_type :json
	Appcast.create!(params).to_json
end

put '/appcasts/:id' do |id|
	content_type :json
	data = JSON.parse(request.body.read)
	appcast = Appcast.find(id)
	if appcast.update_attributes(data)
		Appcast.find(id).to_json
	else
		appcast.to_json
	end
end

get '/appcasts/:id' do |id|
	content_type :json
	Appcast.find(id).to_json
end

post '/appcasts/:id/items' do |id|
	content_type :json
	Appcast.find(id).items.push(Item.new(params)).to_json
end

get '/appcasts/:id/items' do |id|
	content_type :json
	Appcast.find(id).items.to_json
end

get '/appcasts/:id/feed' do |id|
	content_type :xml
	erb :appcast, :locals => { :appcast => Appcast.find(id) }
end

get '/appcasts/:id/download/latest' do |id|
	content_type :xml
	erb :appcast, :locals => { :appcast => Appcast.find(id) }
end
