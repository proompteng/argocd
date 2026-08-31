#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'delivery_contract'

options = {}
OptionParser.new do |parser|
  parser.banner = 'Usage: validate_output.rb --inventory PATH --root PATH --stage NAME'
  parser.on('--inventory PATH') { |value| options[:inventory_path] = value }
  parser.on('--root PATH') { |value| options[:root] = value }
  parser.on('--stage NAME') { |value| options[:stage_name] = value }
end.parse!

required = %i[inventory_path root stage_name]
missing = required.reject { |key| options[key] }
abort "missing required options: #{missing.join(', ')}" unless missing.empty?

puts JSON.pretty_generate(DeliveryContract.validate_output(**options))
