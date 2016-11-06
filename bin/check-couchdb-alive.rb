#! /usr/bin/env ruby
#
#  check-couchdb-alive.rb
#
# DESCRIPTION:
#   Check if a CouchDB server is alive and optionally if a database exists
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: rest-client
#
# NOTES
#   Based on:
#     https://github.com/sensu-plugins/sensu-plugins-rabbitmq/blob/master/bin/check-rabbitmq-alive.rb
#
# LICENSE:
#   Copyright 2016 Alex Enachioaie github.com/thisisjaid
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'json'
require 'rest_client'

# main plugin class

class CouchDBAlive < Sensu::Plugin::Check::CLI
  option :host,
         description: 'CouchDB host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'CouchDB port',
         long: '--port PORT',
         default: 5984

  option :database,
         description: 'CouchDB database',
         long: '--database DATABASE',
         default: ''

  def run
    res = couchdb_alive?

    if res['status'] == 'ok'
      ok res['message']
    elsif res['status'] == 'critical'
      critical res['message']
    else
      unknown res['message']
    end
  end

  def couchdb_alive?
    host       = config[:host]
    port       = config[:port]
    database   = config[:database]

    begin
      if database.nil? || database.empty?
        resource = RestClient::Resource.new("http://#{host}:#{port}/")
        # Attempt to parse response (just to trigger parse exception)
        _response = JSON.parse(resource.get) == { 'couchdb' => 'Welcome' }
        { 'status' => 'ok', 'message' => 'CouchDB server is alive' }
      else
        resource = RestClient::Resource.new("http://#{host}:#{port}/#{database}")
        _response = JSON.parse(resource.get) == { 'db_name' => "#{database}.to_s" }
        { 'status' => 'ok', 'message' => 'CouchDB server is alive and database exists' }
      end
    rescue Errno::ECONNREFUSED => e
      { 'status' => 'critical', 'message' => e.message }
    rescue => e
      { 'status' => 'unknown', 'message' => e.message }
    end
  end
end
