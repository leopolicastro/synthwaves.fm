require "aws-sdk-s3"

class DatabaseBackupService
  DEFAULT_RETENTION = 7
  DEFAULT_PREFIX = "backups/db/"

  def self.call(retention: DEFAULT_RETENTION, prefix: DEFAULT_PREFIX)
    new(retention: retention, prefix: prefix).call
  end

  def initialize(retention: DEFAULT_RETENTION, prefix: DEFAULT_PREFIX)
    @retention = retention
    @prefix = prefix.end_with?("/") ? prefix : "#{prefix}/"
  end

  def call
    Dir.mktmpdir("db_backup") do |tmpdir|
      backup_path = File.join(tmpdir, "backup.sqlite3")
      gz_path = "#{backup_path}.gz"

      create_backup(backup_path)
      compress(backup_path, gz_path)
      key = upload(gz_path)
      prune_old_backups

      { key: key, size: File.size(gz_path) }
    end
  end

  private

  def create_backup(dest_path)
    source_db = SQLite3::Database.new(db_path)
    dest_db = SQLite3::Database.new(dest_path)

    backup = SQLite3::Backup.new(dest_db, "main", source_db, "main")
    backup.step(-1)
    backup.finish

    dest_db.close
    source_db.close
  end

  def compress(source_path, gz_path)
    Zlib::GzipWriter.open(gz_path) do |gz|
      File.open(source_path, "rb") do |f|
        IO.copy_stream(f, gz)
      end
    end
  end

  def upload(gz_path)
    key = "#{@prefix}production-#{Time.current.iso8601}.sqlite3.gz"

    s3_client.put_object(
      bucket: bucket,
      key: key,
      body: File.open(gz_path, "rb")
    )

    key
  end

  def prune_old_backups
    response = s3_client.list_objects_v2(bucket: bucket, prefix: @prefix)
    return if response.contents.nil? || response.contents.empty?

    sorted = response.contents
      .select { |obj| obj.key.end_with?(".sqlite3.gz") }
      .sort_by(&:last_modified)
      .reverse

    return if sorted.size <= @retention

    sorted[@retention..].each do |obj|
      s3_client.delete_object(bucket: bucket, key: obj.key)
    rescue Aws::S3::Errors::NoSuchKey
      # Object already gone, skip
    end
  end

  def db_path
    ActiveRecord::Base.connection_db_config.database
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      access_key_id: credentials[:access_key_id],
      secret_access_key: credentials[:secret_access_key],
      region: credentials[:region],
      endpoint: credentials[:endpoint]
    )
  end

  def bucket
    credentials[:bucket]
  end

  def credentials
    @credentials ||= Rails.application.credentials.linode
  end
end
