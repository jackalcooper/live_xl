defmodule LiveXL.WorkerPool do
  require Logger
  @behaviour NimblePool

  defmodule State do
    @type t :: %__MODULE__{gpus: %{integer() => :stopped | :starting}}
    defstruct gpus: %{}, opts: []

    def occupy_slot(%__MODULE__{gpus: gpus} = state) do
      i =
        Enum.find_value(gpus, nil, fn
          {id, :stopped} -> id
          _ -> nil
        end)

      case i do
        nil ->
          {:error, :full, state}

        i when is_integer(i) ->
          gpus = Map.put(gpus, i, :starting)
          {:ok, i, %__MODULE__{state | gpus: gpus}}
      end
    end

    def release_slot(%__MODULE__{gpus: gpus}, i) do
      gpus = Map.put(gpus, i, :stopped)
      %__MODULE__{gpus: gpus}
    end
  end

  def available_gpu_ids() do
    with {:ok, v} <- Application.fetch_env(:live_xl, __MODULE__),
         true <- Keyword.has_key?(v, :available_gpu_ids) do
      v[:available_gpu_ids]
    else
      _ -> 0..1
    end
  end

  @impl NimblePool
  def init_pool(:python_runner) do
    init_pool({:python_runner, []})
  end

  def init_pool({:python_runner, opts}) do
    opts = opts |> Keyword.put_new(:args, [])
    available_gpu_ids = opts[:available_gpu_ids] || available_gpu_ids()
    gpus = Map.new(available_gpu_ids, &{&1, :stopped})
    {:ok, %State{gpus: gpus, opts: opts}}
  end

  @impl NimblePool
  def init_worker(%State{opts: opts} = pool_state) do
    {:ok, gpu_id, pool_state} = State.occupy_slot(pool_state)

    {:async,
     fn ->
       port =
         LiveXL.Infer.start_py(
           args:
             LiveXL.Infer.lightning_args() ++
               opts[:args],
           env: [{~c"CUDA_VISIBLE_DEVICES", ~c"#{gpu_id}"}]
         )
         |> LiveXL.Infer.sync("[gpu##{gpu_id}] syncing script start")

       {gpu_id, port}
     end, pool_state}
  end

  @impl NimblePool
  # Transfer the port to the caller
  def handle_checkout(:checkout, {pid, _}, {_gpu_id, port} = worker_state, pool_state) do
    try do
      Port.connect(port, pid)
      client_state = worker_state
      {:ok, client_state, worker_state, pool_state}
    rescue
      e ->
        Logger.error("worker down #{inspect(worker_state)} #{inspect(e)}")
        {:remove, inspect(e), pool_state}
    end
  end

  @impl NimblePool
  # We got it back
  def handle_checkin(:ok, _from, port, pool_state) do
    {:ok, port, pool_state}
  end

  def handle_checkin(:close, _from, _port, pool_state) do
    {:remove, :closed, pool_state}
  end

  @impl NimblePool
  # On terminate, effectively close it
  def terminate_worker(reason, {id, port}, pool_state) do
    Logger.info("terminating worker ##{id}, reason: #{reason}")
    Port.close(port)
    Logger.info("worker terminated")
    {:ok, State.release_slot(pool_state, id)}
  end
end
