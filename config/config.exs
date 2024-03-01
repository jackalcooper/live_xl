# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :live_xl,
  namespace: LiveXL,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :live_xl, LiveXLWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LiveXLWeb.ErrorHTML, json: LiveXLWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LiveXL.PubSub,
  live_view: [signing_salt: "QvLtaMMf"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :live_xl, LiveXL.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  live_xl: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  live_xl: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

cuda_dev_ids_str =
  System.get_env("LIVE_XL_CUDA_DEVICES") ||
    if nvidia_smi = System.find_executable("nvidia-smi") do
      {output, 0} = System.cmd(nvidia_smi, ["--query-gpu=index", "--format=csv,noheader"])
      output
    end

if cuda_dev_ids_str do
  available_gpu_ids =
    cuda_dev_ids_str
    |> String.split([" ", ",", "\n"], trim: true)
    |> Enum.reduce([], fn device_str, acc ->
      case Integer.parse(device_str) do
        {num, _} -> [num | acc]
        _ -> acc
      end
    end)
    |> Enum.sort()

  config :live_xl, LiveXL.WorkerPool, available_gpu_ids: available_gpu_ids
end

if s = System.get_env("LIVE_XL_LIGHTNING_ARGS") do
  config :live_xl, LiveXL.Infer, lightning_args: String.split(s, [" ", "\n"], trim: true)
end

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
