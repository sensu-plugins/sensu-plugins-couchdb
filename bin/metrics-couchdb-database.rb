#!/usr/bin/env ruby
#
#   metrics-couchdb-database.rb
#
# DESCRIPTION:
#
# OUTPUT:
#   metrics from a database
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
#   Based on:
#     https://github.com/sensu-plugins/sensu-plugins-couchdb/blob/master/bin/metrics-couchdb.rb
#
# LICENSE:
#   Copyright 2016 Florin Andrei github.com/FlorinAndrei
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

  option :database,
         description: 'Database name',
         long: '--database DATABASE',
         short: '-d DATABASE'

  def run
    http = Net::HTTP.new(config[:host], config[:port])
    req = Net::HTTP::Get.new('/' + config[:database])

    begin
      metrics = {}
      res = http.request(req)
      json = JSON.parse(res.body)

      metrics.update(dot_it(json))
      timestamp = Time.now.to_i
      metrics.each do |k, v|
        if v.nil?
          next
        end
        unless v.is_a? Numeric
          next
        end
        output [config[:scheme] + '.databases.' + config[:database], k].join('.'), v, timestamp
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
