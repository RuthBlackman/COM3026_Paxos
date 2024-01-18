defmodule InventoryServer do

  def start(name, servers) do
    pid = spawn(InventoryServer, :init, [name, servers])
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
      sequence: 0,
      pending: {0, nil},
      inventory: %{1 => 30}, # item_id -> amount
    }

    run(state)
  end

  def run(state) do
    IO.puts("In run")
    state = receive do
      {:view_inventory, client} ->
        state = receive_decisions(state, true)
        send(client, {:inventory, state.inventory})
        state
      {trans, client, item_id, amount} = t when trans == :remove_from_inventory or trans == :add_to_inventory->
        if amount <= 0 do
          send(elem(state.pending, 1), {:add_to_inventory_failed})
          state
        else
          IO.puts("waiting for paxos")
          v = Paxos.propose(state.pax_pid, state.last_instance + 1, {trans, {state.name, state.sequence}, item_id, amount}, 1000)
          IO.puts("\n\n\n\nv: #{inspect v}\n\n\n\n")
          case v do
            {:abort} ->
              send(client, {:abort})
              state

            {:timeout} ->
              send(client, {:timeout})
              state

            {:decision, v} ->
              state = %{state | pending: {state.last_instance + 1, client}}
              state = receive_decisions(state, false)
          end
        end
    end
    run(state)
  end

  def receive_decisions(state, run_again) do
    i = state.last_instance + 1
    IO.puts("state.pax_pid: #{inspect(state.pax_pid)}, state.last_instance: #{inspect(i)}")
    v = Paxos.get_decision(state.pax_pid, i, 1000)
    IO.puts("\n\n\n\nreceive_decisions #{inspect(v)}\n\n\n\n")
    case v do
      {:add_to_inventory, client, item, amount} ->
        IO.puts("inside add to inventory, client: #{inspect(client)}, item: #{inspect(item)}, amount: #{inspect(amount)}, i: #{inspect(i)}")
        IO.puts("state.pending: #{inspect(state.pending)}")
        state = cond do
          state.pending == nil -> state
          {state.name, state.sequence} == client ->
            send(elem(state.pending, 1), {:add_to_inventory_ok})
            %{state | sequence: state.sequence + 1}
          true ->
            send(elem(state.pending, 1), {:add_to_inventory_failed})
            state
        end

        state = %{state | pending: nil, inventory: Map.put(state.inventory, item, Map.get(state.inventory, item, 0) + amount)}

        IO.puts("Inventory: #{inspect(state.inventory)}")
        state = %{state | last_instance: i}
        if run_again do
          receive_decisions(state, run_again)
        else
          state
        end

      {:remove_from_inventory, client, item, amount} ->
        IO.puts("inside remove from inventory, client: #{inspect(client)}, item: #{inspect(item)}, amount: #{inspect(amount)}, i: #{inspect(i)}")
        IO.puts("state.pending: #{inspect(state.pending)}")

        state = cond do
          state.pending == nil -> state
          {state.name, state.sequence} == client ->
            if Map.get(state.inventory, item) == nil || state.inventory[item] - amount < 0 do
              # unable to remove from inventory because it either doesn't exist, or the amount would be negative
              send(elem(state.pending, 1), {:abort})
            else
              # remove from inventory
              send(elem(state.pending, 1), {:remove_from_inventory_ok})
              IO.puts("Inside remove from inventory, amount: #{inspect(Map.put(state.inventory, item, state.inventory[item]-amount))}")
            end
            %{state | sequence: state.sequence + 1}
          true ->
            send(elem(state.pending, 1), {:remove_from_inventory_failed})
            state
        end

        state = if Map.get(state.inventory, item) == nil || state.inventory[item] - amount < 0 do
          # unable to remove from inventory because it either doesn't exist, or the amount would be negative
          %{state | pending: nil}
        else
          # remove from inventory
          IO.puts("Inside remove from inventory, amount: #{inspect(Map.put(state.inventory, item, state.inventory[item]-amount))}")
          %{state | pending: nil, inventory: Map.put(state.inventory, item, state.inventory[item]-amount)}
        end

        IO.puts("Inventory: #{inspect(state.inventory)}")
        state = %{state | last_instance: i}
        if run_again do
          receive_decisions(state, run_again)
        else
          state
        end

      nil ->
       IO.puts("Inventory: #{inspect(state.inventory)}")
       state
    end
  end

  # add item to inventory
  def add_to_inventory(p, item, amount) do
    Utils.unicast(p, {:add_to_inventory, self(), item, amount})
    receive do
      {:add_to_inventory_ok} ->
        IO.puts("add_to_inventory_ok")
        :ok
      {:add_to_inventory_failed} ->
        IO.puts("add_to_inventory_failed")
        :fail
      {:abort} -> :fail
      _ -> :timeout
    after 1000 -> :timeout
    end
  end

  # remove item from inventory
  def remove_from_inventory(p, item, amount) do
    IO.puts("remove_from_inventory, item: #{inspect(item)}, amount: #{inspect(amount)}, p: #{inspect(p)}")
    Utils.unicast(p, {:remove_from_inventory, self(), item, amount})
    IO.puts("remove_from_inventory, item: #{inspect(item)}, amount: #{inspect(amount)}, p: #{inspect(p)}")
    receive do
      {:remove_from_inventory_ok} ->
        IO.puts("remove_from_inventory_ok")
        :ok
      {:remove_from_inventory_failed} ->
        IO.puts("remove_from_inventory_failed")
        :fail
      {:abort} -> :fail
      _ -> :timeout
      after 1000 -> :timeout
    end
  end

  # view the inventory
  def view_inventory(p) do
    Utils.unicast(p, {:view_inventory, self()})
    receive do
      {:inventory, inventory} -> inventory
      _ -> :timeout
    after 1000 -> :timeout
    end
  end
end