#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'
require 'yaml'
require_relative '../scripts/delivery_contract'

class DeliveryContractTest < Minitest::Test
  INVENTORY = File.expand_path('../contract/inventory.yaml', __dir__)
  DIGEST = "sha256:#{'a' * 64}"

  def test_inventory_is_valid
    inventory = DeliveryContract.validate_inventory(INVENTORY)
    assert_equal 19, inventory.dig('spec', 'stages').length
  end

  def test_valid_generated_output
    with_output do |root|
      report = DeliveryContract.validate_output(inventory_path: INVENTORY, root: root, stage_name: 'proompteng')
      assert_equal 1, report.fetch('objects')
      assert_equal 1, report.fetch('selectedImages')
    end
  end

  def test_ignores_git_worktree_metadata
    with_output do |root|
      File.write(File.join(root, '.git'), "gitdir: /tmp/example\n")
      report = DeliveryContract.validate_output(inventory_path: INVENTORY, root: root, stage_name: 'proompteng')
      assert_equal 1, report.fetch('objects')
    end
  end

  def test_rejects_namespace
    with_output(kind: 'Namespace') do |root|
      error = assert_raises(DeliveryContract::ContractError) do
        DeliveryContract.validate_output(inventory_path: INVENTORY, root: root, stage_name: 'proompteng')
      end
      assert_includes error.message, 'Namespace objects are forbidden'
    end
  end

  def test_rejects_unselected_manifest_image
    with_output(manifest_digest: "sha256:#{'b' * 64}") do |root|
      error = assert_raises(DeliveryContract::ContractError) do
        DeliveryContract.validate_output(inventory_path: INVENTORY, root: root, stage_name: 'proompteng')
      end
      assert_includes error.message, 'is not present in rendered output'
    end
  end

  def test_rejects_nonempty_native_secret
    with_output(kind: 'Secret', extra: { 'data' => { 'token' => 'c2VjcmV0' } }) do |root|
      error = assert_raises(DeliveryContract::ContractError) do
        DeliveryContract.validate_output(inventory_path: INVENTORY, root: root, stage_name: 'proompteng')
      end
      assert_includes error.message, 'nonempty native Secret'
    end
  end

  private

  def with_output(kind: 'Deployment', manifest_digest: DIGEST, extra: {})
    Dir.mktmpdir('delivery-contract') do |root|
      FileUtils.mkdir_p(File.join(root, '.kargo'))
      FileUtils.mkdir_p(File.join(root, 'apps', 'proompteng'))
      provenance = {
        'schemaVersion' => 1,
        'stage' => 'proompteng',
        'applications' => ['proompteng'],
        'freight' => {
          'collectionID' => 'c' * 40,
          'items' => [{
            'origin' => { 'kind' => 'Warehouse', 'name' => 'proompteng' },
            'name' => 'd' * 40,
            'commits' => [{
              'repoURL' => 'https://github.com/proompteng/lab.git',
              'branch' => 'main',
              'id' => 'e' * 40,
            }],
            'images' => [{
              'repoURL' => 'registry.example.test/lab/proompteng',
              'digest' => DIGEST,
            }],
          }],
        },
      }
      object = {
        'apiVersion' => kind == 'Deployment' ? 'apps/v1' : 'v1',
        'kind' => kind,
        'metadata' => { 'name' => 'proompteng', 'namespace' => 'proompteng' },
      }.merge(extra)
      if kind == 'Deployment'
        object['spec'] = {
          'template' => {
            'spec' => {
              'containers' => [{
                'name' => 'proompteng',
                'image' => "registry.example.test/lab/proompteng@#{manifest_digest}",
              }],
            },
          },
        }
      end
      File.write(File.join(root, '.kargo', 'freight.yaml'), YAML.dump(provenance))
      File.write(File.join(root, 'apps', 'proompteng', 'manifest.yaml'), YAML.dump(object))
      yield root
    end
  end
end
