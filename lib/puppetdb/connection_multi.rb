require 'puppetdb'

class PuppetDB::MultiConnection
  require 'rubygems'
  require 'puppetdb/parser'
  require 'uri'
  require 'puppet'
  require 'puppet/util/logging'

  include Puppet::Util::Logging

  def initialize(host = 'puppetdb', port = 443, use_ssl = true)
    @servers = [{ :host => host, :port => port, :use_ssl => use_ssl }]
  end

  def self.from_uris(uris)
    conn = allocate
    conn.instance_variable_set(:@servers, Array(uris).map do |uri|
      u = uri.is_a?(URI::Generic) ? uri : URI.parse(uri.to_s)
      { :host => u.host, :port => u.port, :use_ssl => u.scheme == 'https' }
    end)
    conn
  end

  def self.check_version
    require 'puppet/util/puppetdb'
    unless Puppet::Util::Puppetdb.config.respond_to?('server_urls')
      Puppet.warning <<-EOT
It looks like you are using a PuppetDB version < 3.0.
This version of puppetdbquery requires at least PuppetDB 3.0 to work.
Downgrade to puppetdbquery 1.x to use it with PuppetDB 2.x.
EOT
    end
  rescue LoadError
  end

  def query(endpoint, query = nil, options = {}, version = :v4)
    require 'json'

    default_options = {
      :http => nil,
      :extract => nil
    }

    if options.is_a? Hash
      options = default_options.merge options
    else
      Puppet.deprecation_warning 'Specify http object with :http key instead'
      options = default_options.merge(:http => options)
    end
    http = options[:http]

    if options[:extract]
      query = PuppetDB::ParserHelper.extract(*Array(options[:extract]), query)
    end

    req_uri = "/pdb/query/#{version}/#{endpoint}"
    req_uri += URI.escape "?query=#{query.to_json}" unless query.nil? || query.empty?

    debug("PuppetDB query: #{query.to_json}")

    headers = { 'Accept' => 'application/json' }

    if http
      resp = http.get(req_uri, headers)
      fail "PuppetDB query error: [#{resp.code}] #{resp.msg}, query: #{query.to_json}" unless resp.is_a?(Net::HTTPSuccess)
      return JSON.parse(resp.body)
    end

    require 'puppet/network/http_pool'
    last_error = nil
    @servers.each do |server|
      begin
        http = Puppet::Network::HttpPool.http_instance(server[:host], server[:port], server[:use_ssl])
        resp = http.get(req_uri, headers)
        fail "PuppetDB query error: [#{resp.code}] #{resp.msg}, query: #{query.to_json}" unless resp.is_a?(Net::HTTPSuccess)
        return JSON.parse(resp.body)
      rescue Exception => e
        last_error = e
        Puppet.debug("PuppetDB server #{server[:host]}:#{server[:port]} unavailable: #{e.message}, trying next server")
      end
    end

    raise last_error if last_error
    fail 'PuppetDB query failed: no servers configured'
  end
end
