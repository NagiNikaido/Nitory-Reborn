defmodule NitoryWeb.Router do
  use NitoryWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", NitoryWeb do
    pipe_through :api
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:nitory, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: NitoryWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  else
    import Phoenix.LiveDashboard.Router

    pipeline :admins_only do
      plug :admin_basic_auth
    end

    pipeline :browser do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :fetch_live_flash
      plug :protect_from_forgery
      plug :put_secure_browser_headers
    end

    scope "/" do
      pipe_through [:browser, :admins_only]
      live_dashboard "/dashboard", metrics: NitoryWeb.Telemetry
    end

    defp admin_basic_auth(conn, _opts) do
      username =
        System.get_env("AUTH_USERNAME") ||
          raise """
          environment variable AUTH_USERNAME is missing.
          For example: andy
          """

      password =
        System.get_env("AUTH_PASSWORD") ||
          raise """
          environment variable AUTH_PASSWORD is missing.
          For example: <your password here>
          """

      Plug.BasicAuth.basic_auth(conn, username: username, password: password)
    end
  end
end
