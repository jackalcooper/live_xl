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

  def lightning_args(id) do
    with {:ok, v} <- Application.fetch_env(:live_xl, __MODULE__),
         true <- Keyword.has_key?(v, :lightning_args) do
      v[:lightning_args]
    else
      _ ->
        ~w[--base /share_nfs/hf_models/stable-diffusion-xl-base-1.0 --repo /share_nfs/hf_models/SDXL-Lightning --cpkt sdxl_lightning_2step_unet.safetensors --save_graph --load_graph --save_graph_dir=cached_pipe@{infer_process_id} --load_graph_dir=cached_pipe@{infer_process_id}]
    end
    |> Enum.map(&String.replace(&1, "@{infer_process_id}", "#{id}"))
  end

  def lightning_num_steps() do
    with {:ok, v} <- Application.fetch_env(:live_xl, __MODULE__),
         true <- Keyword.has_key?(v, :lightning_num_steps) do
      v[:lightning_num_steps]
    else
      _ ->
        2
    end
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
