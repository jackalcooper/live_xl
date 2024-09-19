defmodule LiveXLWeb.Router do
  use LiveXLWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveXLWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :within_iframe_secure_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LiveXLWeb do
    pipe_through :browser

    get "/home", PageController, :home
  end

  scope "/", LiveXLWeb do
    pipe_through :browser
    live "/", PromptLive
    live "/:mode", PromptLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", LiveXLWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:live_xl, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LiveXLWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  defp within_iframe_secure_headers(conn, _opts) do
    delete_resp_header(conn, "x-frame-options")
  end
end
