defmodule SamplePhoenixWeb.JobHTML do
  use SamplePhoenixWeb, :html

  embed_templates "job_html/*"

  @doc """
  Renders a job form.

  The form is defined in the template at
  job_html/job_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def job_form(assigns)
end
