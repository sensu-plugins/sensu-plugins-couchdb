#! /usr/bin/env ruby
#
#  check-couchdb-cluster.rb
#
# DESCRIPTION:
#   Checks the health, size and version of a CouchDB cluster
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
#     https://github.com/sensu-plugins/sensu-plugins-couchbase/blob/master/bin/check-couchbase-cluster.rb
#
# LICENSE:
#   Copyright 2017 Pieter Vogelaar
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'json'
require 'rest_client'

# main plugin class

class CouchDBCluster < Sensu::Plugin::Check::CLI
  option :user,
         description: 'CouchDB API auth username',
         short: '-u USERNAME',
         long: '--user USERNAME'

  option :password,
         description: 'CouchDB API auth password',
         short: '-P PASSWORD',
         long: '--password PASSWORD'

  option :host,
         description: 'CouchDB host / Load balancer DNS name',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'CouchDB port',
         short: '-p PORT',
         long: '--port PORT',
         default: 5984

  option :cluster_size,
         description: 'Cluster size expected',
         short: '-c CLUSTER_SIZE',
         long: '--cluster-size CLUSTER_SIZE',
         proc: proc(&:to_i)

  option :couchdb_version,
         description: 'CouchDB version expected',
         short: '-v VERSION',
         long: '--version VERSION'

  def run
    begin
      resource = '/_membership'
      response = RestClient::Request.execute(
          method: :get,
          url: "http://#{config[:host]}:#{config[:port]}/#{resource}",
          user: config[:user],
          password: config[:password],
          headers: { accept: :json, content_type: :json }
      )
      result = JSON.parse(response.to_str, symbolize_names: true)
    rescue Errno::ECONNREFUSED
      unknown 'Connection refused'
    rescue RestClient::ResourceNotFound
      unknown "Resource not found: #{resource}"
    rescue RestClient::RequestFailed
      unknown 'Request failed'
    rescue RestClient::RequestTimeout
      unknown 'Connection timed out'
    rescue RestClient::Unauthorized
      unknown 'Missing or incorrect CouchDB API credentials'
    rescue JSON::ParserError
      unknown 'CouchDB API returned invalid JSON'
    end

    # Get information about each node
    nodes = {}
    result[:all_nodes].each do |node|
      node_parts = node.split('@')
      nodes[node_parts[1]] = get_node(node_parts[1], config[:port], config[:user], config[:password])
    end

    # Collect node CouchDB versions
    node_versions = []
    nodes.each do |fqdn, node|
      node_versions << node[:version]
    end

    # Check CouchDB version consistency
    if node_versions.uniq.length > 1
      critical 'Different couchdb versions found on nodes in the cluster'
    end

    # Check CouchDB version compliancy
    if config[:couchdb_version]
      nodes_version = nodes.select { |fqdn, node| node[:version].to_s != config[:couchdb_version].to_s }
      critical "Unexpected couchdb's version on nodes: #{nodes_version.map { |fqdn, node| fqdn }}" if nodes_version.size > 0 # rubocop:disable ZeroLengthPredicate
    end

    # Check unhealthy nodes
    nodes_unhealthy = nodes.select { |fqdn, node| node[:couchdb] != 'Welcome' }
    critical "These nodes are not 'healthy': #{nodes_unhealthy.map { |fqdn, node| fqdn }}" if nodes_unhealthy.size > 0 # rubocop:disable ZeroLengthPredicate

    # Check unactive nodes
    nodes_unactive = []
    result[:cluster_nodes].each do |node|
      if !result[:all_nodes].include?(node)
        nodes_unactive << node
      end
    end

    critical "These nodes are not 'active' in the cluster: #{nodes_unactive.join(', ')}" if nodes_unactive.size > 0 # rubocop:disable ZeroLengthPredicate

    # Check cluster's size
    critical "Cluster's size is #{result[:cluster_nodes].size}, #{config[:cluster_size]} expected" if config[:cluster_size] && result[:cluster_nodes].size != config[:cluster_size]

    # Everything is okay
    ok "Nodes: #{result[:all_nodes].size}"
  end

  def get_node(host, port, user, password)
    begin
      response = RestClient::Request.execute(
          method: :get,
          url: "#{host}:#{port}",
          user: user,
          password: password,
          headers: { accept: :json, content_type: :json }
      )
      result = JSON.parse(response.to_str, symbolize_names: true)
    rescue Errno::ECONNREFUSED
      unknown "[#{host}] Connection refused"
    rescue RestClient::ResourceNotFound
      unknown "[#{host}] Resource not found: #{resource}"
    rescue RestClient::RequestFailed
      unknown "[#{host}] Request failed"
    rescue RestClient::RequestTimeout
      unknown "[#{host}] Connection timed out"
    rescue RestClient::Unauthorized
      unknown "[#{host}] Missing or incorrect CouchDB API credentials"
    rescue JSON::ParserError
      unknown "[#{host}] CouchDB API returned invalid JSON"
    end

    return result
  end
end
