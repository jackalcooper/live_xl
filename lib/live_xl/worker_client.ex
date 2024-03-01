defmodule LiveXL.WorkerClient do
  require Logger

  defp jsonl(command) do
    command =
      command
      |> then(fn
        %{ref: _} = m -> m
        m -> Map.put(m, :ref, inspect(make_ref()))
      end)

    Jason.encode!(command) <> "\n"
  end

  defp normalize_cmd(command) do
    if String.ends_with?(command, "\n") do
      command
    else
      command <> "\n"
    end
  end

  def command(port_or_pool, command, opts \\ [])

  def command(port_or_pool, command, opts) when is_map(command) do
    command(port_or_pool, jsonl(command), opts)
  end

  def command(port, command, opts) when is_binary(command) and is_port(port) do
    command = normalize_cmd(command)
    receive_timeout = Keyword.get(opts, :receive_timeout, 5000)
    send(port, {self(), {:command, command}})

    receive do
      {^port, {:data, data}} ->
        try do
          Process.unlink(port)
          {Jason.decode!(data), :ok}
        rescue
          e ->
            Logger.error("fail to connect port #{inspect(e)}")
            {data, :close}
        end
    after
      receive_timeout ->
        Logger.error("[timeout] cmd: #{inspect(command)}")
        exit(:receive_timeout)
    end
  end

  def command(pool, command, opts) when is_binary(command) and is_atom(pool) do
    pool_timeout = Keyword.get(opts, :pool_timeout, 5000)

    NimblePool.checkout!(
      pool,
      :checkout,
      fn _from, {_gpu_id, port} = _client_state ->
        command(port, command, opts)
      end,
      pool_timeout
    )
  end
end
