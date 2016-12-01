require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/multi_route'

class MyApp < Sinatra::Base
  register Sinatra::Reloader
  register Sinatra::MultiRoute

  before do
    request.body.rewind
    @request_payload = request.body.read
  end

  route :get, :post, '/request_details' do
    content_type 'text/plain'

    [
      "---- HTTP HEADERS ----",
      request_headers, "",
      "---- QUERY STRING PARAMTERS ----",
      query_params, "",
      "---- REQUEST BODY ----",
      (@request_payload.empty? ? "(None)" : @request_payload), ""
    ].flatten.join("\n")
  end

  get '/redirect' do
    if matched_redirection
      redirect to(matched_redirection), 301
    else
      erb :redirect
    end
  end

  get '/versioned' do
    content_type 'application/json'

    case request.env["HTTP_ACCEPT"].downcase
    when 'application/vnd.byu.cs462.v1+json'
      '{"version": "v1" }'
    when 'application/vnd.byu.cs462.v2+json'
      '{"version": "v2" }'
    else
      status 406
      '{"error": "Unknown version. Accept header must be either application/vnd.byu.cs462.v1+json or application/vnd.byu.cs462.v1+json" }'
    end
  end

  private

  def request_headers
    raw_headers = request.env.select { |name, value| name.start_with?("HTTP") }
    raw_headers.sort_by(&:first).map do |name, value|
      [name.sub('HTTP_', '').split("_").map(&:downcase).map(&:capitalize).join("-"), value].join(": ")
    end
  end

  def query_params
    qp = request.env['rack.request.query_hash']
    qp.any? ? qp.map { |k, v| [k,v].join(": ") } : "(None)"
  end

  def matched_redirection
    chosen_network = %w(google facebook github twitter).find { |network| params.key?(network) }

    { 
      "google" => "https://google.com",
      "facebook" => "https://facebook.com",
      "github" => "https://github.com",
      "twitter" => "https://twitter.com"
    }[chosen_network]
  end
end