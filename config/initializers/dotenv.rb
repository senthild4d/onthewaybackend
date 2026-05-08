if defined?(Dotenv)
  env_files = [
    Rails.root.join('.env'),
    Rails.root.join(".env.#{Rails.env}")
  ]

  Dotenv.load(*env_files.select { |path| File.exist?(path) })
end
