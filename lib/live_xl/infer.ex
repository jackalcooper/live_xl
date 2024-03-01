defmodule LiveXL.Infer do
  def start_py(opts \\ []) do
    args = opts[:args] || []
    env = opts[:env] || []
    python3 = System.find_executable("python3")
    script = Application.app_dir(:live_xl, ["priv", "runner.py"])

    Port.open({:spawn_executable, python3}, [
      :binary,
      :nouse_stdio,
      :exit_status,
      args: ["-u", script] ++ args,
      env: env
    ])
  end

  @doc """
  sync a pool to unsure python side is ready for receiving actions
  """
  def sync(port, msg) when is_port(port) do
    ref = inspect(self())

    script_start_timeout = 50 * 60 * 1000

    {%{"ref" => ^ref}, :ok} =
      LiveXL.WorkerClient.command(port, %{action: "echo", ref: ref, payload: msg},
        receive_timeout: script_start_timeout
      )

    port
  end

  def run(msg) do
    LiveXL.WorkerClient.command(PythonWorkerPool, msg)
  end
end
