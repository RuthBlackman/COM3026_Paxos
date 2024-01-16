# Task 2
# API where paxos will be connected to the application server
defmodule ShopServer do

  def start(name, paxos_proc) do
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
      stock: 0,
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

  # Check if item is in stock
  def check_stock(r) do
    send(r, {:get_stock, self()})
    receive do
      {:stock, sto} -> sto
      after 1000 -> :timeout
    end
  end

  # Add to cart
  def add_to_cart(r, item) do
    if item < 0, do: raise("add_to_cart failed: item must be positive")
    send(r, {:add_to_cart, self(), item})
    case wait_for_reply(r, 5) do
      {:add_to_cart_ok} -> :ok
      {:add_to_cart_failed} -> :fail
      {:abort} -> :fail
      _ -> :timeout
    end
  end

  # Remove from cart
  def remove_from_cart(r, item) do
    if item < 0, do: raise("remove_from_cart failed: item must be positive")
    send(r, {:remove_from_cart, self(), item})
    case wait_for_reply(r, 5) do
      {:remove_from_cart_ok} -> :ok
      {:remove_from_cart_failed} -> :fail
      {:abort} -> :fail
      _ -> :timeout
    end
  end

  def run(state) do
    # Run stuff
    state = receive do
      {trans, client, _ } = t when trans = :add_to_cart or trans = :remove_from_cart ->
        state = poll_for_decisions(state)
        if Paxos.propose(state.pax_pid, state.last_instance + 1, t, 1000) == {:abort} do
          send(client, {:abort})
        else
          %{state | pending: {state.last_instance + 1, client}}
        end

      {get_stock, client} ->
        state = poll_for_decisions(state)
        send(client, {:stock, state.stock})
        state

      {:poll_for_decisions} ->
        poll_for_decisions(state)
        _ -> state

    end
    run(state)
  end

  # Poll for decisions
  def poll_for_decisions(state) do
    case Paxos.get_decision(state.pax_pid, i = state.last_instance) do
       {add_to_cart, item} ->
       state = case state.pending do
         {i, client} ->
           send(client, {:add_to_cart, item})
           %{state | pending: {i+1, nil}}
         _ -> state
       end
       poll_for_decisions(%{state | last_instance: i})

       {remove_from_cart, item} ->
        state = case state.pending do
          {i, client} ->
            send(client, {:remove_from_cart, item})
            %{state | pending: {i+1, nil}}
          _ -> state
        end

        state = %{state | stock: (if (sto = state.stock - item) < 0, do: 0, else: sto)}
        poll_for_decisions(%{state | last_instance: i+1})
    end
  end
end