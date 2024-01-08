# Task 2
# API where paxos will be connected to the application server
defmodule ShopServer do
  def start(name, paxos_proc) do
    # Start stuff
    pid = spawn(ShopServer, :init, [name, paxos_proc])
    pid = case :global.re_register_name(name, pid) do
      :yes -> pid
      :no -> nil
    end
    IO.puts(if pid, do: "registered #{name}", else: "failed to register #{name}")
    pid
  end

  def init(name, paxos_proc) do
    # Init stuff
    state = %{
      name: name,
      pax_pid: get_paxos_pid(paxos_proc),
      last_instance: 0,
      pending: {0, nil},
    }

    run(state)
  end

  # Get pid of a Paxos instance to connect to
  defp get_paxos_pid(paxos_proc) do
    case :global.whereis_name(paxos_proc) do
      pid when is_pid(pid) -> pid
      :undefined -> raise(Atom.to_string(paxos_proc))
    end
  end

  defp wait_for_reply(_, 0), do: nil
  defp wait_for_reply(r, attempt) do
    # Wait for reply
    msg = receive do
      msg -> msg
      after 1000 ->
        send(r, {:poll_for_decisions})
        nil
    end
    if msg, do: msg, else: wait_for_reply(r, attempt - 1)
  end

  # functions for shop functionality
  # i.e. add to cart, remove from cart, checkout, etc.
  # Add to cart
  def add_to_cart(r, item) do

  end

  # Remove from cart
  def remove_from_cart(r, item) do

  end

  # Checkout
  def checkout(r) do

  end

  def run(state) do
    # Run stuff

  end

  # Poll for decisions
  def poll_for_decisions(r) do
#    {add_to_cart, item} ->
#    {remove_from_cart, item} ->
  end


end