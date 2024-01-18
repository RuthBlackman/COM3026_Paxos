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
    pending: {0, nil},
    inventory: %{1 => 30}, # item_id -> amount
    }

    run(state)
  end

  def run(state) do
    IO.puts("In run")
    state = receive do
      {trans, client, _, _} = t when trans == :remove_from_inventory or trans == :add_to_inventory ->
        IO.puts("waiting for paxos")
        v = Paxos.propose(state.pax_pid, state.last_instance + 1, t, 1000)
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
            state = receive_decisions(state)
        end
    end
    run(state)
  end

  def receive_decisions(state) do
    i = state.last_instance + 1
    IO.puts("state.pax_pid: #{inspect(state.pax_pid)}, state.last_instance: #{inspect(i)}")
    v = Paxos.get_decision(state.pax_pid, i, 1000)
    IO.puts("\n\n\n\nreceive_decisions #{inspect(v)}\n\n\n\n")
    case v do
      {:add_to_inventory, client, item, amount} ->
        IO.puts("inside add to inventory, client: #{inspect(client)}, item: #{inspect(item)}, amount: #{inspect(amount)}, i: #{inspect(i)}")
        IO.puts("state.pending: #{inspect(state.pending)}")
        state = if amount > 0 do
          state = case state.pending do
            {^i, client} ->
              send(elem(state.pending, 1), {:add_to_inventory_ok})

              # check if item already exists in inventory
              if Map.get(state.inventory, item) do
                # item exists, add amount to inventory
                IO.puts("Item already exists in inventory")
                IO.puts("Inventory before adding: #{inspect(state.inventory)}")
                %{state | pending: {amount, nil}, inventory: Map.put(state.inventory, item, state.inventory[item]+amount )}
              else
                # item does not exist, add item to inventory
                IO.puts("Item does not exist in inventory")
                %{state | pending: {amount, nil}, inventory: Map.put(state.inventory, item, amount )}
              end

            {^i, _ } ->
              send(elem(state.pending, 1), {:add_to_inventory_failed})
              %{state | pending: {amount, nil}}

            _ -> state
          end
        else
          send(elem(state.pending, 1), {:add_to_inventory_failed})
          %{state | pending: {amount, nil}}
        end
        IO.puts("Inventory: #{inspect(state.inventory)}")
        state
        %{state | last_instance: i}

      {:remove_from_inventory, client, item, amount} ->
        IO.puts("inside remove from inventory, client: #{inspect(client)}, item: #{inspect(item)}, amount: #{inspect(amount)}, i: #{inspect(i)}")
        IO.puts("state.pending: #{inspect(state.pending)}")

        state = if amount > 0 do
          state = case state.pending do
            {^i, client} ->
              if Map.get(state.inventory, item) == nil || state.inventory[item] - amount < 0 do
                # unable to remove from inventory because it either doesn't exist, or the amount would be negative
                send(elem(state.pending, 1), {:abort})
                %{state | pending: {amount, nil}}
              else
                # remove from inventory
                send(elem(state.pending, 1), {:remove_from_inventory_ok})
                IO.puts("Inside remove from inventory, amount: #{inspect(Map.put(state.inventory, item, state.inventory[item]-amount))}")
                %{state | pending: {amount, nil}, inventory: Map.put(state.inventory, item, state.inventory[item]-amount)}
              end

            {^i, _} ->
              send(elem(state.pending, 1), {:remove_from_inventory_failed})
              %{state | pending: {amount, nil}}

            _ -> state
          end
        else
          send(elem(state.pending, 1), {:remove_from_inventory_failed})
          %{state | pending: {amount, nil}}
        end

        IO.puts("Inventory: #{inspect(state.inventory)}")
        state
        %{state | last_instance: i}

      nil ->
       IO.puts("Inventory: #{inspect(state.inventory)}")
       state
    end
  end

  # add item to inventory
  def add_to_inventory(p, item, amount) do
#    if amount <= 0 do
#      raise("add_to_inventory failed: item must be positive")
#    end
    Utils.unicast(p, {:add_to_inventory, self(), item, amount})
    receive do
      {:add_to_inventory_ok} ->:ok
      {:add_to_inventory_failed} -> :fail
      {:abort} -> :fail
      _ -> :timeout
    after 1000 -> :timeout
    end
  end

  # remove item from inventory
  def remove_from_inventory(p, item, amount) do
#    if amount <= 0 do
#      IO.puts("remove_from_inventory failed: item must be positive")
#    end
    IO.puts("remove_from_inventory, item: #{inspect(item)}, amount: #{inspect(amount)}, p: #{inspect(p)}")
    Util.unicast(p, {:remove_from_inventory, self(), item, amount})
    IO.puts("remove_from_inventory, item: #{inspect(item)}, amount: #{inspect(amount)}, p: #{inspect(p)}")
    receive do
      {:remove_from_inventory_ok} -> :ok
      {:remove_from_inventory_failed} -> :fail
      {:abort} -> :fail
      _ -> :timeout
      after 1000 -> :timeout
    end
  end
end