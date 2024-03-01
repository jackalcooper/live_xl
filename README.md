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
