namespace :setup do
  desc "Create initial admin user (configurable via ADMIN_EMAIL and ADMIN_PASSWORD env vars)"
  task admin: :environment do
    admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
    admin_password = ENV.fetch("ADMIN_PASSWORD", "abc123")

    User.find_or_create_by!(email_address: admin_email) do |u|
      u.password = admin_password
      u.admin = true
    end

    puts "Admin user: #{admin_email}"
  end
end
