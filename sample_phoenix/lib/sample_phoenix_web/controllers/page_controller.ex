defmodule SamplePhoenixWeb.PageController do
  use SamplePhoenixWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
