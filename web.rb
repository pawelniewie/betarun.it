require "bundler"
Bundler.setup(:default)
Bundler.require

Mongoid.load!("mongoid.yml")

class User
	include Mongoid::Document

	has_many :appcasts

	field :email, type: String
	field :fullName, type: String
	field :callingName, type: String
	field :picture, type: String
	field :facebookToken, type: String
	field :facebookTokenExpires, type: Time

	index({ email: 1 }, { unique: true })
end

class Appcast
    include Mongoid::Document

		belongs_to :user
    embeds_many :versions

    field :name, type: String
    field :url, type: String
    field :description, type: String
    field :language, type: String, default: 'en'

    index({ name: 1 }, { unique: true })
end

class Version
		include Mongoid::Document

		embedded_in :appcast

		field :title, type: String, default: "Version 1"
		field :description, type: String
		field :minimumSystemVersion, type: String
		field :pubDate, type: Time, default: -> { Time.now }
		field :url, type: String
		field :versionNumber, type: Integer
		field :versionString, type: String
		field :size, type: Integer
		field :draft, type: Boolean, default: true
end

class App < Sinatra::Base
	set :root, File.dirname(__FILE__)
	set :assets, Sprockets::Environment.new(root)
	set :precompile,    [ /\w+\.(?!js|css).+/, /application.(css|js)$/ ]
	set :assets_prefix, "/assets"
	set :digest_assets, true
	set(:assets_path)   { File.join public_folder, assets_prefix }

	register Sinatra::CompassSupport
	register Sinatra::Contrib
	register Sinatra::Namespace

	helpers Sinatra::ContentFor

	# See https://developers.facebook.com/docs/reference/api/permissions/
	# for a full list of permissions
	FACEBOOK_SCOPE = 'email,publish_actions,publish_stream'

	configure do
		set :appname, "AppCasts"

	  set :public_dir, File.dirname(__FILE__) + '/public'
	  set :assets, Sprockets::Environment.new

	  %w{javascripts stylesheets images}.each do |type|
      assets.append_path "assets/#{type}"
    end

    %w{vendor/angularjs-drag-drop-upload vendor/bower_components/angular-filters/build vendor/ng-time-relative/dist}.each do |dir|
    	assets.append_path dir
  	end

    Sprockets::Helpers.configure do |config|
      config.environment = assets
      config.prefix      = assets_prefix
      config.digest      = digest_assets
      config.public_path = public_folder
      config.debug       = true if development?
    end

	  set :haml, { :format => :html5, :escape_html => true }
	  set :scss, { :style => :compact, :debug_info => false }

	  Compass.add_project_configuration(File.join(Sinatra::Application.root, 'config', 'compass.rb'))
	end

	configure :production, :development do
    enable :logging
  end

	configure :production do
		set :raise_errors, false
		set :show_exceptions, false

		assets.js_compressor = Closure::Compiler.new
		assets.css_compressor = YUI::CssCompressor.new
		uid = Digest::MD5.hexdigest(File.dirname(__FILE__))[0,8]
		assets.cache = Sprockets::Cache::FileStore.new("/tmp/sinatra-#{uid}")
	end

	before do
		expires 500, :public, :must_revalidate

	  # HTTPS redirect
	  if settings.environment == :production && request.scheme != 'https'
	    redirect "https://#{request.env['HTTP_HOST']}"
	  end
	end

	helpers do
		include Sprockets::Helpers

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

	  def user_id
	  	return session[:user_id]
	  end

	  def upload(filename, file)
	    s3 = AWS::S3.new(
	      :access_key_id     => ENV['AWS_ACCESS_KEY_ID'],
	      :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
	    )
	    obj = s3.buckets[ENV['S3_BUCKET_NAME']].objects[filename].write(file)
	    return obj.public_url({:secure => true})
	  end
	end

	# the facebook session expired! reset ours and restart the process
	error(Koala::Facebook::APIError) do
	  session[:access_token] = nil
	  redirect "/auth/facebook"
	end

	get '/' do
		redirect '/dashboard' if user_id
		haml :index
	end

	get '/partials/versions' do
		redirect '/' if not user_id
		haml :versions, {:layout => false}
	end

	get '/partials/edit-version' do
		redirect '/' if not user_id
		haml :editVersion, {:layout => false}
	end

	get '/dashboard' do
		redirect '/' if not user_id
		user = User.find(user_id)
		appcast = Appcast.find(user.appcast_ids[0])
		haml :dashboard, :locals => {:user => user, :appcast => appcast}
	end

	# Allows for direct oauth authentication
	get "/auth/facebook" do
	  session[:access_token] = nil
	  session[:user_id] = nil
	  redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
	end

	get '/auth/facebook/callback' do
	  session[:access_token] = authenticator.get_access_token(params[:code])

	  # Get base API Connection
	  graph  = Koala::Facebook::API.new(access_token)

	  profile = graph.get_object("me")
	  if not profile
	  	redirect '/'
	  	return nil
	  end

	  profile = profile.with_indifferent_access

	  user = User.where(email: profile[:email]).first
	  if not user
	  	logger.info("User was not found " + profile[:email])
	  	picture = graph.get_picture("me")
	  	user = User.create!(email: profile[:email], fullName: profile[:name], callingName: profile[:first_name], picture: picture)
	  end
	  if not user.facebookToken
	  	logger.info("Facebook token was not found " + profile[:email])
	  	new_access_info = authenticator.exchange_access_token_info(access_token).with_indifferent_access
	  	user.facebookToken = new_access_info[:access_token]
	  	user.facebookTokenExpires = DateTime.now + new_access_info[:expires].to_i.seconds
	  	user.save
	  else
	  	logger.info("Facebook token was found " + profile[:email])
	  end
	  if not user.appcasts.exists?
	  	user.appcasts.push(Appcast.new(name: "Awesome Appcast"))
	  end
	  session[:user_id] = user._id.to_s
	  redirect '/dashboard'
	end

	['/appcasts/*', '/appcasts'].each do |path|
		before path do
		  halt 401, "Not authorized\n" if not user_id
		end
	end

	get '/appcasts' do
		content_type :json
		appcasts = Appcast.all
		appcasts.to_json
	end

	post '/appcasts' do
		content_type :json
		Appcast.create!(params.slice(Appcast.fields.keys)).to_json
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

	post '/appcasts/:id/versions' do |id|
		content_type :json
		appcast = Appcast.find(id)
		version = Version.new(params.slice(Version.fields.keys))
		appcast.versions.push(version)
		if (!params[:file][:filename].nil? and !params[:file][:tempfile].nil?)
			url = upload(appcast._id.to_s + "/" + version._id.to_s + File.extname(params[:file][:filename]), params['file'][:tempfile])
			version.url = url
			version.size = File.size(params[:file][:tempfile])
			version.save()
		end
		version.to_json
	end

	get '/appcasts/:appcastId/versions/:versionId' do |appcastId, versionId|
		content_type :json
		Appcast.find(appcastId).versions.find(versionId).to_json
	end

	put '/appcasts/:appcastId/versions/:versionId' do |appcastId, versionId|
		content_type :json
		data = JSON.parse(request.body.read)
		version = Appcast.find(appcastId).versions.find(versionId)
		if version.update_attributes(data)
			Appcast.find(appcastId).versions.find(versionId).to_json
		else
			version.to_json
		end
	end

	get '/appcasts/:id/versions' do |id|
		content_type :json
		Appcast.find(id).versions.to_json
	end

	get '/appcasts/:id/feed' do |id|
		content_type :xml
		erb :appcast, :locals => { :appcast => Appcast.find(id) }
	end

	get '/appcasts/:id/download/latest' do |id|
		content_type :xml
		erb :appcast, :locals => { :appcast => Appcast.find(id) }
	end
end