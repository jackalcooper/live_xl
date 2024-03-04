defmodule LiveXLWeb.PyRunTest do
  alias LiveXL.WorkerPool
  use ExUnit.Case, async: true

  test "py pool" do
    msg = %{
      action: :echo,
      ref: "cat",
      payload: %{"prompt" => "dog", "seed" => 44}
    }

    res = LiveXL.Infer.run(msg)

    assert res["action"] == "reply"
    assert res["payload"] == msg.payload
    assert res["ref"] == msg.ref

    Task.async_stream(
      0..1000,
      fn seed ->
        ref = inspect(make_ref())

        res =
          LiveXL.Infer.run(%{msg | payload: %{msg.payload | "seed" => seed}, ref: ref})

        %{"payload" => %{"seed" => ^seed}, "ref" => ^ref} = res
      end
    )
    |> Enum.to_list()
  end

  test "checkout timeout" do
    available_gpu_ids = 0..3
    pool = SlowStart

    child =
      {NimblePool,
       worker:
         {WorkerPool,
          {:python_runner, args: ~w{--mock_sleep_seconds=2}, available_gpu_ids: available_gpu_ids}},
       name: pool,
       pool_size: Enum.count(available_gpu_ids)}

    {:ok, _} = Supervisor.start_link([child], strategy: :one_for_one)

    msg = %{
      action: :echo,
      ref: inspect(make_ref()),
      payload: %{"prompt" => "dog", "seed" => 44}
    }

    assert catch_exit(
             LiveXL.WorkerClient.command(pool, %{msg | payload: %{msg.payload | "seed" => 0}},
               pool_timeout: 500
             )
           ) ==
             {:timeout, {NimblePool, :checkout, [pool]}}
  end

  test "crash restart" do
    available_gpu_ids = 0..3
    pool = CrashRestart

    child =
      {NimblePool,
       worker: {WorkerPool, {:python_runner, available_gpu_ids: available_gpu_ids}},
       name: pool,
       pool_size: Enum.count(available_gpu_ids)}

    {:ok, _} = Supervisor.start_link([child], strategy: :one_for_one)

    msg = %{
      action: :echo,
      ref: inspect(make_ref()),
      payload: %{"prompt" => "dog", "seed" => 44}
    }

    for _ <- 0..10 do
      crash_msg = %{msg | action: :crash}

      assert catch_exit(LiveXL.WorkerClient.command(pool, crash_msg, receive_timeout: 300)) ==
               :receive_timeout
    end

    for _ <- 0..10 do
      assert %{"prompt" => "dog", "seed" => 44} ==
               LiveXL.WorkerClient.command(pool, msg)["payload"]
    end
  end
end
