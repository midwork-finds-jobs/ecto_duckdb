defmodule SamplePhoenixWeb.JobController do
  use SamplePhoenixWeb, :controller

  alias SamplePhoenix.Jobs
  alias SamplePhoenix.Jobs.Job

  def index(conn, _params) do
    jobs = Jobs.list_jobs()
    render(conn, :index, jobs: jobs)
  end

  def new(conn, _params) do
    changeset = Jobs.change_job(%Job{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"job" => job_params}) do
    case Jobs.create_job(job_params) do
      {:ok, _job} ->
        conn
        |> put_flash(:info, "Job created successfully.")
        |> redirect(to: ~p"/jobs")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
