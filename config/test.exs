import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :live_xl, LiveXLWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "iMq3OZLjw8cPgH7kns8SzLlCbU7S9p+c+5Ifd4COP81RZUheTNH14E9LNjdQ7ipQ",
  server: false

# In test we don't send emails.
config :live_xl, LiveXL.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
