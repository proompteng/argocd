# frozen_string_literal: true

require 'pathname'
require 'yaml'

module DeliveryContract
  class ContractError < StandardError; end

  NAME = /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/.freeze
  SHA = /\A[0-9a-f]{40}\z/.freeze
  DIGEST = /\Asha256:[0-9a-f]{64}\z/.freeze
  TRACKING_ANNOTATION = 'argocd.argoproj.io/tracking-id'
  SENTINEL_SECRET = ['torghut', 'torghut-notebooks-hub'].freeze
  SENTINEL_KEYS = [
    'hub.config.ConfigurableHTTPProxy.auth_token',
    'hub.config.CryptKeeper.keys',
    'hub.config.JupyterHub.cookie_secret',
    'values.yaml',
  ].freeze

  module_function

  def load_yaml(path)
    value = YAML.load_file(path)
    raise ContractError, "#{path}: expected a YAML mapping" unless value.is_a?(Hash)

    value
  rescue Psych::SyntaxError => error
    raise ContractError, "#{path}: invalid YAML: #{error.message}"
  end

  def validate_inventory(path)
    inventory = load_yaml(path)
    expect(inventory['apiVersion'] == 'delivery.proompteng.ai/v1alpha1', path, 'unexpected apiVersion')
    expect(inventory['kind'] == 'DeliveryInventory', path, 'unexpected kind')

    spec = mapping(inventory['spec'], path, 'spec')
    expect(spec['sourceRepository'] == 'https://github.com/proompteng/lab.git', path, 'unexpected sourceRepository')
    expect(spec['outputRepository'] == 'https://github.com/proompteng/argocd.git', path, 'unexpected outputRepository')
    expect(spec['branchPrefix'] == 'kargo/', path, 'branchPrefix must be kargo/')
    expect(spec['provenancePath'] == '.kargo/freight.yaml', path, 'unexpected provenancePath')
    expect(spec['manifestPathTemplate'] == 'apps/%{application}/manifest.yaml', path, 'unexpected manifestPathTemplate')

    stages = array(spec['stages'], path, 'stages')
    stage_names = stages.map { |stage| mapping(stage, path, 'stage').fetch('name') }
    applications = stages.flat_map { |stage| array(stage.fetch('applications'), path, 'applications') }

    expect(stage_names.length == spec['expectedStageCount'], path, 'expectedStageCount does not match stages')
    expect(applications.length == spec['expectedApplicationCount'], path, 'expectedApplicationCount does not match applications')
    expect(stage_names.uniq.length == stage_names.length, path, 'stage names must be unique')
    expect(applications.uniq.length == applications.length, path, 'application names must be unique')
    (stage_names + applications).each { |name| expect(NAME.match?(name), path, "invalid name #{name.inspect}") }

    expected_special = {
      'arc-runner' => ['arc'],
      'hermes-toolchain' => ['hermes'],
      'symphony' => ['symphony', 'symphony-jangar'],
    }
    stages.each do |stage|
      name = stage.fetch('name')
      apps = stage.fetch('applications')
      expected = expected_special.fetch(name, [name])
      expect(apps == expected, path, "stage #{name} must map to #{expected.inspect}")
    end

    inventory
  rescue KeyError => error
    raise ContractError, "#{path}: missing required key #{error.key.inspect}"
  end

  def validate_output(inventory_path:, root:, stage_name:)
    inventory = validate_inventory(inventory_path)
    spec = inventory.fetch('spec')
    stage = spec.fetch('stages').find { |candidate| candidate.fetch('name') == stage_name }
    raise ContractError, "unknown stage #{stage_name.inspect}" unless stage

    applications = stage.fetch('applications')
    root_path = Pathname.new(root).expand_path
    expected_paths = [spec.fetch('provenancePath')] + applications.map do |application|
      format(spec.fetch('manifestPathTemplate'), application: application)
    end
    actual_paths = Dir.glob(File.join(root_path, '**', '*'), File::FNM_DOTMATCH).select { |path| File.file?(path) }.map do |path|
      Pathname.new(path).relative_path_from(root_path).to_s
    end.reject { |path| path == '.git' || path.start_with?('.git/') }.sort
    expect(actual_paths == expected_paths.sort, root, "unexpected files: expected #{expected_paths.sort.inspect}, got #{actual_paths.inspect}")

    provenance_path = root_path.join(spec.fetch('provenancePath')).to_s
    provenance = load_yaml(provenance_path)
    validate_provenance(provenance, provenance_path, stage_name, applications)

    raw_manifests = String.new
    identities = {}
    object_count = 0
    external_tagged_images = []
    applications.each do |application|
      relative = format(spec.fetch('manifestPathTemplate'), application: application)
      path = root_path.join(relative).to_s
      raw = File.read(path)
      expect(!raw.strip.empty?, path, 'manifest must not be empty')
      documents = YAML.load_stream(raw).compact
      expect(!documents.empty?, path, 'manifest must contain at least one object')
      documents.each do |document|
        validate_object(document, path, identities, external_tagged_images)
        object_count += 1
      end
      raw_manifests << raw
    rescue Psych::SyntaxError => error
      raise ContractError, "#{path}: invalid YAML: #{error.message}"
    end

    selected_images = provenance.fetch('freight').fetch('items').flat_map { |item| item.fetch('images') }
    selected_images.each do |image|
      reference = "#{image.fetch('repoURL')}@#{image.fetch('digest')}"
      rendered_reference = /#{Regexp.escape(image.fetch('repoURL'))}(?::[^\s@]+)?@#{Regexp.escape(image.fetch('digest'))}/
      expect(rendered_reference.match?(raw_manifests), root, "selected image #{reference} is not present in rendered output")
    end

    {
      'stage' => stage_name,
      'applications' => applications,
      'objects' => object_count,
      'selectedImages' => selected_images.length,
      'externalTaggedImages' => external_tagged_images.uniq.sort,
    }
  end

  def validate_provenance(provenance, path, stage_name, applications)
    expect(provenance.keys.sort == %w[applications freight schemaVersion stage], path, 'unexpected provenance keys')
    expect(provenance['schemaVersion'] == 1, path, 'schemaVersion must be 1')
    expect(provenance['stage'] == stage_name, path, 'stage does not match branch')
    expect(provenance['applications'] == applications, path, 'applications do not match inventory')
    freight = mapping(provenance['freight'], path, 'freight')
    expect(SHA.match?(freight['collectionID'].to_s), path, 'invalid collectionID')
    items = array(freight['items'], path, 'freight.items')
    expect(!items.empty?, path, 'freight.items must not be empty')
    items.each do |item|
      item = mapping(item, path, 'freight item')
      expect(SHA.match?(item['name'].to_s), path, 'invalid Freight name')
      origin = mapping(item['origin'], path, 'origin')
      expect(origin['kind'] == 'Warehouse' && NAME.match?(origin['name'].to_s), path, 'invalid Freight origin')
      commits = array(item['commits'], path, 'commits')
      images = array(item['images'], path, 'images')
      expect(!commits.empty?, path, 'Freight item must include a source commit')
      expect(!images.empty?, path, 'Freight item must include a selected image')
      commits.each do |commit|
        expect(commit.keys.sort == %w[branch id repoURL], path, 'unexpected commit keys')
        expect(commit['repoURL'].to_s.start_with?('https://'), path, 'commit repoURL must use HTTPS')
        expect(SHA.match?(commit['id'].to_s), path, 'invalid source commit')
        expect(!commit['branch'].to_s.empty?, path, 'commit branch must not be empty')
      end
      images.each do |image|
        allowed_keys = %w[annotations digest repoURL tag]
        expect((image.keys - allowed_keys).empty?, path, 'unexpected image keys')
        expect(!image['repoURL'].to_s.empty?, path, 'image repoURL must not be empty')
        expect(DIGEST.match?(image['digest'].to_s), path, 'selected image must use a sha256 digest')
        annotations = image['annotations'] || {}
        expect(annotations.is_a?(Hash), path, 'image annotations must be a mapping')
        expect(annotations.values.all? { |value| value.is_a?(String) }, path, 'image annotations must be strings')
      end
    end
  end

  def validate_object(document, path, identities, external_tagged_images)
    expect(document.is_a?(Hash), path, 'every YAML document must be a mapping')
    api_version = document['apiVersion'].to_s
    kind = document['kind'].to_s
    metadata = mapping(document['metadata'], path, 'metadata')
    name = metadata['name'].to_s
    namespace = metadata['namespace'].to_s
    expect(!api_version.empty? && !kind.empty? && !name.empty?, path, 'object identity is incomplete')
    expect([api_version, kind, namespace, name].none? { |value| value.include?('{{') || value.include?('${{') }, path, 'object identity contains an unresolved template expression')
    expect(kind != 'Namespace', path, 'Namespace objects are forbidden')
    annotations = metadata['annotations'] || {}
    expect(!annotations.key?(TRACKING_ANNOTATION), path, "generated output must not persist #{TRACKING_ANNOTATION}")

    identity = [api_version, kind, namespace, name].join('|')
    expect(!identities.key?(identity), path, "duplicate object identity #{identity}")
    identities[identity] = path

    validate_secret(document, path) if kind == 'Secret' && api_version == 'v1'
    collect_images(document).each do |image|
      expect(!image.include?('{{') && !image.include?('${{'), path, 'container image contains an unresolved template expression')
      external_tagged_images << image unless image.include?('@sha256:')
    end
  end

  def validate_secret(secret, path)
    metadata = secret.fetch('metadata')
    data = secret['data'] || {}
    string_data = secret['stringData'] || {}
    expect(data.is_a?(Hash) && string_data.is_a?(Hash), path, 'Secret data must be mappings')
    return if data.empty? && string_data.empty?

    identity = [metadata['namespace'], metadata['name']]
    expect(identity == SENTINEL_SECRET, path, "nonempty native Secret #{identity.join('/')} is forbidden")
    expect(string_data.empty?, path, 'sentinel Secret must not contain stringData')
    expect(SENTINEL_KEYS.sort == data.keys.sort, path, 'sentinel Secret has unexpected keys')
    SENTINEL_KEYS.each do |key|
      expect(data[key] == '++++++++', path, "sentinel #{key} changed")
    end
  end

  def collect_images(value, images = [])
    case value
    when Hash
      value.each do |key, child|
        images << child if key == 'image' && child.is_a?(String)
        collect_images(child, images)
      end
    when Array
      value.each { |child| collect_images(child, images) }
    end
    images
  end

  def mapping(value, path, field)
    raise ContractError, "#{path}: #{field} must be a mapping" unless value.is_a?(Hash)

    value
  end

  def array(value, path, field)
    raise ContractError, "#{path}: #{field} must be an array" unless value.is_a?(Array)

    value
  end

  def expect(condition, path, message)
    raise ContractError, "#{path}: #{message}" unless condition
  end
end
