defmodule LiveXLWeb.PromptLive do
  # In Phoenix v1.6+ apps, the line is typically: use MyAppWeb, :live_view
  use Phoenix.LiveView

  attr :field, Phoenix.HTML.FormField
  attr :class, :string
  attr :rest, :global, include: ~w(type)

  def form_input(assigns) do
    assigns = assigns |> Map.put_new(:type, nil)

    ~H"""
    <input
      class={"flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 " <> @class}
      id={@field.id}
      name={@field.name}
      value={@field.value}
      phx-debounce="250"
      {@rest}
    />
    """
  end

  use Phoenix.VerifiedRoutes,
    router: LiveXLWeb.Router,
    endpoint: LiveXLWeb.Endpoint,
    statics: ~w(images generated)

  @impl true
  def mount(_params, _session, socket) do
    default_prompt = "A cinematic shot of a baby raccoon wearing an intricate italian priest robe"

    form = %{"seed" => 1, "prompt" => default_prompt}

    if connected?(socket) do
      infer(form)
    end

    socket =
      socket
      |> assign(:image, ~p"/images/onediff_logo.png")
      |> assign(:inference_time, 0.0)
      |> assign(:e2e_time, 0.0)

    socket =
      socket
      |> assign(:form, Phoenix.Component.to_form(form))

    {:ok, socket}
  end

  @impl true
  def handle_event("update", form = %{"prompt" => _prompt, "seed" => _seed}, socket) do
    infer(form)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_socket, f}, socket) do
    {:noreply, f.(socket)}
  end

  defp do_infer(form) do
    args = form
    f = make_ref() |> inspect |> then(&Regex.scan(~r/\d+/, &1)) |> to_string

    seed =
      case form["seed"] do
        s when is_integer(s) ->
          s

        s when is_bitstring(s) ->
          {i, _} = Integer.parse(s)
          i
      end

    f = "#{f}#{seed}.jpeg"
    target_image_url = ~p"/generated/#{f}"
    saved_image = Path.join(Application.app_dir(:live_xl, ["priv", "static", "generated"]), f)

    args =
      args
      |> Map.put("saved_image", saved_image)
      |> Map.put("seed", seed)
      |> Map.put("num_inference_steps", 2)
      |> Map.put("height", 1024)
      |> Map.put("width", 1024)
      |> Map.put("guidance_scale", 0)
      |> Map.put("negative_prompt", "blurry, blur, text, watermark, render, 3D, NSFW, nude, CGI, monochrome, B&W, cartoon, painting, smooth, plastic, blurry, low-resolution, deep-fried, oversaturated")
|> dbg
    res =
      :timer.tc(fn -> LiveXL.Infer.run(%{action: "infer_lightning", payload: %{args: args}}) end)

    {e2e_time, inference_time, image_url} =
      case {:os.type(), res} do
        {{:unix, :darwin},
         {e2e_time,
          %{
            "error" => _
          }}} ->
          {e2e_time, 0.0, ~p"/images/onediff_logo.png"}

        {_,
         {e2e_time,
          %{
            "action" => "reply",
            "payload" => "success",
            "ref" => _,
            "inference_time" => inference_time
          }}} ->
          {e2e_time, inference_time, target_image_url}
      end

    form = form |> Phoenix.Component.to_form()

    fn socket ->
      socket
      |> assign(:form, form)
      |> assign(:inference_time, inference_time)
      |> assign(:e2e_time, e2e_time)
      |> assign(:image, image_url)
    end
  end

  def infer(form) do
    this = self()

    spawn(fn ->
      socket_updater = do_infer(form)
      send(this, {:update_socket, socket_updater})
    end)
  end
end
