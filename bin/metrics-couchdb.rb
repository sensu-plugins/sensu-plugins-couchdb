#! /usr/bin/env ruby
#
#   metrics-couchdb.rb
#
# DESCRIPTION:
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: net
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Docs: https://wiki.apache.org/couchdb/Runtime_Statistics
#   Based on:
#     https://github.com/sensu-plugins/sensu-plugins-mongodb/blob/master/bin/metrics-mongodb.rb
#     https://github.com/sensu-plugins/sensu-plugins-http/blob/master/bin/check-http-json.rb
#     http://stackoverflow.com/a/17452062/49330
#
# LICENSE:
#   Copyright 2015 Florin Andrei github.com/FlorinAndrei
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'json'
require 'net/http'

#
# CouchDB
#

class CouchDB < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         description: 'CouchDB host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'CouchDB port',
         long: '--port PORT',
         default: 5984

  option :scheme,
         description: 'Metric naming scheme',
         long: '--scheme SCHEME',
         short: '-s SCHEME',
         default: "#{Socket.gethostname}.couchdb"

  def run
    http = Net::HTTP.new(config[:host], config[:port])
    req = Net::HTTP::Get.new('/_stats')

    begin
      metrics = {}
      res = http.request(req)
      json = JSON.parse(res.body)

      metrics.update(dot_it(json))
      timestamp = Time.now.to_i
      metrics.each do |k, v|
        if k.end_with? '.description'
          next
        end
        if v.nil?
          next
        end
        output [config[:scheme], k].join('.'), v, timestamp
      end
      ok
    rescue
      exit(1)
    end
  end

  def dot_it(object, prefix = nil)
    if object.is_a? Hash
      object.map do |key, value|
        if prefix
          dot_it value, "#{prefix}.#{key}"
        else
          dot_it value, key.to_s
        end
      end.reduce(&:merge)
    else
      { prefix => object }
    end
  end
end
