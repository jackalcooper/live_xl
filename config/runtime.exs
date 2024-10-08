import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/live_xl start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :live_xl, LiveXLWeb.Endpoint, server: true
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  phx_port = System.get_env("PHX_PORT")
  scheme = System.get_env("PHX_SCHEME")
  check_origin = System.get_env("PHX_CHECK_ORIGIN") in ~w{1 true True}
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :live_xl, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  if host = System.get_env("PHX_HOST") do
    config :live_xl, LiveXLWeb.Endpoint,
      url: [host: host || "example.com", port: phx_port || 443, scheme: scheme || "https"]
  end

  config :live_xl, LiveXLWeb.Endpoint,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    check_origin: check_origin,
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :live_xl, LiveXLWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :live_xl, LiveXLWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :live_xl, LiveXL.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

cuda_dev_ids_str =
  case System.get_env("LIVE_XL_CUDA_DEVICES") do
    nil -> nil
    "" -> nil
    devices -> devices
  end ||
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

config :live_xl, LiveXL.Infer,
  lightning_num_steps: String.to_integer(System.get_env("LIVE_XL_LIGHTNING_NUM_STEPS", "2"))
