require 'sinatra/base'
require 'httparty'
require 'mongoid'
require 'rack/ssl'
Mongoid.load! 'mongoid.yml'

class User
  include Mongoid::Document

  field :id, type: String
  field :access_token, type: String
  field :profile_photo, type: String
  field :name, type: String
  field :home_city, type: String
end

class FoursquareApp < Sinatra::Base
  use Rack::SSL if ENV['HEROKU']

  # We're storing our client secret and other config in environment variables
  AUTH_URL = "https://foursquare.com/oauth2/authenticate?client_id=#{ ENV['FS_CLIENT_ID' ]}&response_type=code&redirect_uri=#{ ENV['FS_REDIR_URI' ]}".freeze
  ACCESS_TOKEN_URL = "https://foursquare.com/oauth2/access_token?client_id=#{ ENV['FS_CLIENT_ID' ]}&client_secret=#{ ENV['FS_CLIENT_SECRET' ]}&grant_type=authorization_code&redirect_uri=#{ ENV['FS_REDIR_URI' ]}".freeze
  API_VERSION = '20161201'.freeze

  enable :sessions
  before do
    @current_user = User.find_by(id: session[:id]) if session[:id]
  end

  get '/' do
    @users = User.all
    erb :index
  end

  get '/login' do
    redirect AUTH_URL
  end

  get '/accepted' do
    token_request = HTTParty.get(ACCESS_TOKEN_URL + "&code=#{ params[:code ]}")
    user_details = foursquare_api_request('users/self', token_request['access_token'], %w(response user))

    user = User.find_or_create_by(id: user_details['id']) do |user|
      # This block only runs for a new user
      user.name = [user_details['firstName'], user_details['lastName']].join(' ')
      user.profile_photo = [user_details['photo']['prefix'], 256, user_details['photo']['suffix']].join
      user.home_city = user_details['homeCity']
    end
    user.update(access_token: token_request['access_token'])

    session[:id] = user.id

    redirect to("/profile/#{ user.id }")
  end

  get '/logout' do
    session[:id] = nil
    redirect to('/')
  end

  get '/profile/:id' do
    @user = User.find_by!(id: params[:id])

    @checkins = foursquare_api_request("users/#{ @user.id }/checkins", @user.access_token, %w(response checkins items))

    @is_mine = @current_user && @current_user.id == @user.id
    @checkins = @checkins.first(1) unless @is_mine

    erb :profile
  end

  private

  def foursquare_api_request(endpoint, token, target_fields)
    base_url = "https://api.foursquare.com/v2/"

    response = HTTParty.get(base_url + endpoint, query: { oauth_token: token, v: API_VERSION })
    response.to_h.dig(*target_fields)
  end
end