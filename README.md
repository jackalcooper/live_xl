# LiveXL

## To start locally:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.


## To check zoombie workers

```bash
ps aux | grep $USER | grep python | grep runner
```

## Running in production

- `LIVE_XL_CUDA_DEVICES`: similar to CUDA_VISIBLE_DEVICES
- `LIVE_XL_LIGHTNING_ARGS`: arguments to run lightning script

1. Download a archive for your Linux from https://github.com/jackalcooper/live_xl/releases
2. Extract the archive to get `live_xl` directory
3. Make sure `SDXL-Lightning` and `stable-diffusion-xl-base-1.0` are in the same directory as `live_xl` (optional, if you want to configure the path, you can set `--base` and `--repo` in `LIVE_XL_LIGHTNING_ARGS`)
4. Run it with docker, example script to run the server:

```bash
#!/bin/sh
set -eu

cache_dir=$PWD/cached_pipe/gpu-@{infer_gpu_id}
LIVE_XL_LIGHTNING_ARGS="${LIVE_XL_LIGHTNING_ARGS:---base $PWD/stable-diffusion-xl-base-1.0 --repo=$PWD/SDXL-Lightning} --save_graph --load_graph --save_graph_dir=${cache_dir} --load_graph_dir=${cache_dir}"
working_dir=$PWD
cd -P -- "$(dirname -- "$0")"
docker run -it --rm --gpus all --shm-size 12g --ipc=host --security-opt seccomp=unconfined --privileged=true --name onediff-demo-$USER \
  -e LIVE_XL_CUDA_DEVICES=${LIVE_XL_CUDA_DEVICES} -e HF_HUB_OFFLINE=1 -e SECRET_KEY_BASE=V4p3Ece1NG5t50SLq3VIuS8CTVq3/UzygEGBlGWana7j2UMP73NfRS3PZLXzX8EF \
  -e LIVE_XL_LIGHTNING_ARGS="${LIVE_XL_LIGHTNING_ARGS}" \
  --network=host \
  -v $working_dir:$working_dir -w $working_dir -v $HOME/onediff:$HOME/onediff registry.cn-beijing.aliyuncs.com/oneflow/onediff:cu118 live_xl/bin/server
```
