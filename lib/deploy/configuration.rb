class Configuration

  def initialize(config_bucket_name)
    @config_bucket_name = config_bucket_name
  end

  def verify!
    unless config_bucket.exists? && objects.count > 0
      fail "Configuration bucket #{@config_bucket_name} not found or empty."
    end
    enforce_valid_app_paths!
    @verified = true
  end

  def apps
    fail "Asked for app list without verifying. It will be wrong." if !@verified
    @apps ||= apps_list
  end

  def created_folders
    @created_folders ||= []
  end

  private

  def config_bucket
    @config_bucket ||=
      call_with_error_handling { Aws::S3::Bucket.new(@config_bucket_name) }
  end

  def objects
    @objects ||= call_with_error_handling { config_bucket.objects }
  end

  def client
    @client ||= call_with_error_handling { Aws::S3::Client.new }
  end

  def enforce_valid_app_paths!
    # check folders in our config bucket, recreate any missing folders
    object_names = objects.map(&:key)
    file_names = object_names.select { |name| !name.end_with?('/') }
    max_depth = object_names.map { |name| name.count('/') }.max
    possible_object_names = (1..max_depth).reduce([]) { |list, depth|
      list += object_names.map { |name| name.split('/').first(depth).join('/') }
    }
    folder_names = possible_object_names.uniq - file_names
    path_names = folder_names.map { |folder| folder + '/' }

    # Make the folder if needed
    folders_to_create = path_names.sort_by { |name| name.count('/') }
    folders_to_create.each do |folder|
      create_folder!(folder)
    end

    @created_folders = folders_to_create
  end

  def create_folder!(folder)
    call_with_error_handling do
      client.put_object(
        acl: 'private',
        body: nil,
        bucket: config_bucket.name,
        key: folder
      ) unless config_bucket.object(folder).exists?
    end
  end

  def apps_list
    call_with_error_handling do
      objects.select do |o|
        !o.key.empty?        &&
        o.key.end_with?('/') &&
        o.key.count('/') == 1
      end
    end
  end

  def call_with_error_handling
    yield
  rescue Aws::Errors::MissingCredentialsError => e
    # Missing or incorrect AWS keys
    fail "Missing AWS credentials. Error thrown by AWS: #{e}"
  rescue Aws::S3::Errors::ServiceError => e
    # rescues all errors returned by Amazon Simple Storage Service
    fail "Error thrown by AWS S3: #{e}"
  end
end