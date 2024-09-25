defmodule LiveXLWeb.PromptLive do
  # In Phoenix v1.6+ apps, the line is typically: use MyAppWeb, :live_view
  use Phoenix.LiveView
  require Logger

  attr :field, Phoenix.HTML.FormField
  attr :class, :string
  attr :rest, :global, include: ~w(type)
  require Logger

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

  @default_prompts """
                   A serene forest with glowing mushrooms at twilight
                   A futuristic city skyline under a neon sky
                   A vintage car parked by a tranquil beach at sunset
                   A dragon soaring over a medieval castle on a mountain
                   An astronaut exploring a vibrant alien planet filled with unusual flora
                   A magical library with floating books and a starry ceiling
                   A cozy coffee shop during a rainstorm with people reading
                   A fairy tale cottage in a lush garden at dawn
                   A steampunk-inspired airship flying above the clouds
                   A fantasy market bustling with creatures from various lore
                   An underwater city illuminated by bioluminescent creatures
                   A majestic waterfall cascading into a crystal-clear lake
                   A cute robot tending to a rooftop garden in a city
                   An ancient temple overtaken by nature, wrapped in vines
                   A whimsical carousel powered by magic in a lush meadow
                   A cat sitting on a windowsill looking out at a snowy street
                   A colorful carnival with rides and balloons in the sky
                   A hidden treehouse surrounded by fireflies at night
                   A peaceful Japanese zen garden with cherry blossoms
                   A hauntingly beautiful graveyard under a full moon
                   A medieval knight sitting by a campfire telling stories
                   A majestic phoenix rising from the ashes with flames
                   A futuristic subway station with holographic advertisements
                   A group of friends having a picnic on a sunny day
                   A mysterious, swirling portal in the middle of a forest
                   A delicate fairy perched on a giant flower
                   A bustling street in Tokyo at night with bright lights
                   A tranquil beach with turquoise water and white sand
                   A colorful street art mural in an urban setting
                   A whimsical candyland filled with giant sweets
                   An elegant ballroom dancing with ghosts in Victorian attire
                   A warm fireplace surrounded by cozy blankets in winter
                   A dramatic mountain range partially covered in fog
                   A vibrant alien market with diverse extraterrestrial beings
                   An enchanted well in a moonlit clearing
                   A historical reenactment scene from the Renaissance
                   A pirate ship sailing through a stormy sea
                   A mystical creature watching over a village from a hilltop
                   A bustling 1920s speakeasy filled with jazz music
                   An eerie abandoned amusement park overrun by nature
                   A sci-fi colony on Mars with domed habitats
                   A quiet street lined with cherry blossom trees in spring
                   A magical duel between wizards in an enchanted forest
                   A portrait of a royal family in a lavish palace
                   A lighthouse standing tall against crashing waves
                   A peaceful monastery on a mountain peak at sunrise
                   A post-apocalyptic cityscape overtaken by nature
                   A cozy cabin surrounded by snow-covered trees
                   A garden tea party with whimsical creatures
                   A sunset view from the edge of a cliff overlooking the ocean
                   A group of children playing hide and seek in a park
                   A cyberpunk neon street filled with eccentric characters
                   An underwater scene with colorful coral reefs and fish
                   A vintage train traveling through a picturesque landscape
                   A magical forest path illuminated by fireflies
                   A warm, inviting bakery filled with fresh pastries
                   A whimsical dragon flying over a quaint village
                   A futuristic robot bartender serving cocktails
                   An expansive desert with a mesmerizing starry night
                   A dark forest with a mysterious cabin in the middle
                   A serene lake reflecting a sky filled with northern lights
                   A playful kitten exploring a vibrant garden
                   A majestic unicorn galloping through a rainbow
                   An ancient stone circle surrounded by mist
                   A small fishing village at dawn with boats on the water
                   A portrait of a heroic character on a quest
                   A cozy reading nook by a window on a rainy day
                   A magical forest where the trees whisper secrets
                   A fantasy battle scene between knights and mythical beasts
                   A charming village square bustling with activity
                   A retro diner with neon signs and checkered floors
                   A mysterious fog rolling over a dark lake
                   A futuristic battle robot in a high-tech arena
                   A vintage circus poster featuring acrobats and clowns
                   An enchanting night market filled with colorful lanterns
                   A soothing hot spring surrounded by mountains in autumn
                   A fairy sitting on a mushroom in a magical glade
                   A majestic castle under a starry sky
                   A hidden beach cove with crystal-clear water
                   A vivid landscape of rolling hills and wildflowers
                   A cozy living room with a fireplace and family photos
                   A powerful wizard casting spells in an ancient library
                   A whimsical scene of a tea party with talking animals
                   A glamorous film noir detective in a smoky bar
                   A quaint bookshop filled with unique stories
                   A lively festival filled with dancers and musicians
                   A retro video game arcade bustling with players
                   A serene mountain lake surrounded by pine trees
                   A cozy farmhouse with a sprawling vegetable garden
                   A bustling urban street with food trucks and music
                   A colorful sunrise over a picturesque vineyard
                   A family of owls perched in a tree at night
                   A vibrant mural depicting a mythical creature
                   A peaceful picnic by a flowing river in autumn
                   A glamorous fashion show in a grand ballroom
                   A hidden temple in the middle of a dense jungle
                   A vintage record store filled with rare finds
                   A stunning view from a mountain peak at sunset
                   A lively aquarium filled with diverse marine life
                   A surreal landscape with floating islands and waterfalls
                   """
                   |> String.split("\n", trim: true)

  def default_prompt() do
    default_prompt = "A cinematic shot of a baby raccoon wearing an intricate italian priest robe"
    [default_prompt | @default_prompts] |> Enum.random()
  end

  def default_seed() do
    Enum.random(0..10000)
  end

  @impl true
  def mount(params, _session, socket) do
    form = %{"seed" => default_seed(), "prompt" => default_prompt()}

    if connected?(socket) do
      infer(form)
    end

    socket =
      socket
      |> assign(:image, ~p"/images/onediff_logo.png")
      |> assign(:inference_time, 0.0)
      |> assign(:e2e_time, 0.0)

    if params["mode"] == "conf" do
      auto_play_timeout =
        if t = params["auto_play_timeout"] do
          String.to_integer(t)
        else
          5_000
        end

      Process.send_after(self(), {:auto_play, auto_play_timeout}, auto_play_timeout)
    end

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

  def handle_info({:auto_play, auto_play_timeout}, socket) do
    Process.send_after(self(), {:auto_play, auto_play_timeout}, auto_play_timeout)

    form = %{"seed" => default_seed(), "prompt" => default_prompt()}

    socket =
      assign(
        socket,
        :form,
        Phoenix.Component.to_form(form)
      )

    infer(form)
    {:noreply, socket}
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
      |> Map.reject(fn
        {k, _} when is_bitstring(k) -> String.starts_with?(k, "_")
        _ -> false
      end)
      |> Map.put("saved_image", saved_image)
      |> Map.put("seed", seed)
      |> Map.put("num_inference_steps", LiveXL.Infer.lightning_num_steps())
      |> Map.put("height", 1024)
      |> Map.put("width", 1024)
      |> Map.put("guidance_scale", 0)
      |> Map.put(
        "negative_prompt",
        "blurry, blur, text, watermark, render, 3D, NSFW, nude, CGI, monochrome, B&W, cartoon, painting, smooth, plastic, blurry, low-resolution, deep-fried, oversaturated"
      )

    res =
      :timer.tc(fn -> LiveXL.Infer.run(%{action: "infer_lightning", payload: %{args: args}}) end)

    {e2e_time, inference_time, image_url} =
      case {:os.type(), res} do
        {{:unix, :darwin},
         {e2e_time,
          %{
            "error" => _
          }}} ->
          Logger.debug("args: #{inspect(args)}")

          {e2e_time, 0.0, nil}

        {_,
         {e2e_time,
          %{
            "action" => "reply",
            "payload" => "success",
            "ref" => _,
            "inference_time" => inference_time
          }}} ->
          {e2e_time, inference_time, target_image_url}

        {{:unix, :linux}, {retcode, %{"action" => "reply", "error" => error}}} when retcode > 0 ->
          Logger.error(error)
          {0.0, 0.0, ~p"/images/onediff_logo.png"}
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
