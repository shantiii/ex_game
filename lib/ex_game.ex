defmodule ExGame do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      worker(:eg_frame, []),
      # Starts a worker by calling: ExGame.Worker.start_link(arg1, arg2, arg3)
      # worker(ExGame.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExGame.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule ExGame.Frame do
  @behaviour :wx_object

  require Logger

  def start_link() do
    :wx.new()
    frame = :wx_object.start_link({:local, __MODULE__}, __MODULE__, [:args], [])
    {:ok, :wx_object.get_pid(frame)}
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    frame = :wxFrame.new(:wx.null(), -1, 'omg a game', [size: {200, 200}])
    :wx_object.set_pid(frame, self())
    use Bitwise

    {frame, []}
  end

  def handle_event(msg, state) do
    Logger.debug "Got unexpected event #{msg}"
    {:noreply, state}
  end

  def handle_call(msg, _from, state) do
    Logger.debug "Got unexpected call #{msg}"
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    Logger.debug "Got unexpected cast #{msg}"
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug "Got unexpected info #{msg}"
    {:noreply, state}
  end

  @doc false
  def code_change(_old, _new, state), do: state

  def terminate(_reason, %{windows: %{frame: frame}}) do
    :wxFrame.destroy(frame)
  after
    :shutdown
  end
end
