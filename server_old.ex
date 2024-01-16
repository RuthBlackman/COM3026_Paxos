# Task 2
# API where paxos will be connected to the application server
defmodule ShopServer do

  def start(name, servers) do
    pid = spawn(ShopServer, :init, [name, servers])
    pid = case :global.re_register_name(name, pid) do
      :yes -> pid
      :no -> nil
    end
    IO.puts(if pid, do: "registered #{name}", else: "failed to register #{name}")
    pid
  end

  def init(name, servers) do
    # Start the paxos process
    paxos = Paxos.start(Utils.add_to_name(name, "_pax"), Enum.map(servers, fn s -> Utils.add_to_name(s, "_pax") end))

    state = %{
      name: name,
      pax_pid: paxos,
      last_instance: 0,
      pending: {0, nil},
      stock: 0,
      inventory: %{}, # item_id -> amount
    }

    run(state)
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

  # Check if item is in the inventory
  def check_inventory(r) do
    send(r, {:get_inventory, self()})
    receive do
      {:inventory, inv} -> inv
      after 1000 -> :timeout
    end
  end

  # TODO: might have to change this a bit
  # Add to cart
  def add_to_cart(p, item, amount) do
    if amount < 0, do: raise("add_to_cart failed: item must be positive")
    IO.puts("in add_to_cart")
    send(p, {:add_to_cart, self(), item, amount})
    case wait_for_reply(r, 5) do
      {:add_to_cart_ok} ->:ok
      {:add_to_cart_failed} -> :fail
      {:abort} -> :fail
      _ -> :timeout
    end
  end

  # TODO: might have to change this a bit
  # Remove from cart
  def remove_from_cart(r, item, amount) do
    if item < 0, do: raise("remove_from_cart failed: item must be positive")
    send(r, {:remove_from_cart, self(), item, amount})
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
      {trans, client, _ } = t when trans == :add_to_cart or trans == :remove_from_cart ->
      IO.puts("state = receive")
        state = poll_for_decisions(state)
        if Paxos.propose(state.pax_pid, state.last_instance + 1, t, 1000) == {:abort} do
          send(client, {:abort})
        else
          %{state | pending: {state.last_instance + 1, client}}
        end

      {:get_stock, client} ->
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
    IO.puts("in poll_for_decisions")
    case Paxos.get_decision(state.pax_pid, i = state.last_instance + 1, 1000) do
       {:add_to_cart, client ,item , amount} ->
       IO.puts("add_to_cart")
         state = case state.pending do
           {^i, client} ->
             send(elem(state.pending, 1), {:add_to_cart_ok})
             IO.puts("state.inventory = #{inspect(Map.put(state.inventory, item, amount))}")
             %{state | pending: {0, nil}, inventory: Map.put(state.inventory, item, amount)}
           {^i, _} ->
             send(elem(state.pending, 1), {:add_to_cart_failed})
             %{state | pending: {0, nil}, stock: state.stock + amount}
           _ ->
             %{state | stock: state.stock + amount}
         end
       poll_for_decisions(%{state | last_instance: i})

       {:remove_from_cart, client, item, amount} ->
         state = case state.pending do
           {^i, client} ->
             if state.stock - amount < 0 do
               send(elem(state.pending, 1), {:out_of_stock})
               %{state | pending: {0, nil}}
             else
               send(elem(state.pending, 1), {:remove_from_cart_ok})
               %{state | pending: {0, nil}}
             end
           {^i, _} ->
             send(elem(state.pending, 1), {:remove_from_cart_failed})
             %{state | pending: {0, nil}}
           _ -> state
         end
        state = %{state | stock: (if (sto = state.stock - item) < 0, do: 0, else: sto)}
        poll_for_decisions(%{state | last_instance: i+1})
        nil -> state
    end
  end
end