#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'delivery_contract'

root = File.expand_path('..', __dir__)
inventory = File.join(root, 'contract', 'inventory.yaml')

DeliveryContract.validate_inventory(inventory)
puts 'delivery contract valid: 19 stages, 20 applications'
