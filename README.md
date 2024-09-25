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

1. Download a archive for your compatible Linux distribution from https://github.com/jackalcooper/live_xl/releases
2. Extract the archive to get `live_xl` directory
3. Make sure `SDXL-Lightning` and `stable-diffusion-xl-base-1.0` are in the same directory as `live_xl` (optional, if you want to configure the path, you can set `--base` and `--repo` in `LIVE_XL_LIGHTNING_ARGS`)
4. Run it with docker with `live_xl/bin/docker_server`
