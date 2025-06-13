defmodule ChatDemoWeb.Router do
  use ChatDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ChatDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ChatDemoWeb do
    pipe_through :browser

    live "/", ChatLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", ChatDemoWeb do
  #   pipe_through :api
  # end
end