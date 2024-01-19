defmodule InventoryServer do

  # start the server
  def start(name, servers) do
    # spawn a new process using the init function from the InventoryServer module
    pid = spawn(InventoryServer, :init, [name, servers])
    # attempt to re-register the global name for the process
    pid = case :global.re_register_name(name, pid) do
      :yes -> pid
      :no -> nil
    end
    IO.puts(if pid, do: "registered #{name}", else: "failed to register #{name}")
    # return the pid of the spawned process
    pid
  end

  # initialise the server
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

  # Function to continuously run the system, handling different types of requests
  def run(state) do
    IO.puts("In run")
    # receive a request from a client
    state = receive do
      {:view_inventory, client} ->
        state = receive_decisions(state, true)
        send(client, {:inventory, state.inventory})
        state
      {trans, client, item_id, amount} = t when trans == :remove_from_inventory or trans == :add_to_inventory->
        # handle transactions
        if amount <= 0 do
          # if the amount is invalid, notify the client and return the current state
          send(elem(state.pending, 1), {:add_to_inventory_failed})
          state
        else
          IO.puts("waiting for paxos")
          # propose the transaction to Paxos
          v = Paxos.propose(state.pax_pid, state.last_instance + 1, {trans, {state.name, state.sequence}, item_id, amount}, 1000)
          IO.puts("\n\n\n\nv: #{inspect v}\n\n\n\n")

          # handle the response from Paxos
          case v do
            {:abort} ->
              # If Paxos decides to abort, notify the client and return the current state
              send(client, {:abort})
              state

            {:timeout} ->
              # If the proposal times out, notify the client and return the current state
              send(client, {:timeout})
              state

            {:decision, v} ->
              # If Paxos reaches a decision, update the pending transaction and handle the decision
              state = %{state | pending: {state.last_instance + 1, client}}
              state = receive_decisions(state, false)
          end
        end
    end
    # recursively call the run function to continue processing requests
    run(state)
  end

  # Function to receive decisions from Paxos and update the state accordingly
  def receive_decisions(state, run_again) do
    # increment the instance
    i = state.last_instance + 1
    IO.puts("state.pax_pid: #{inspect(state.pax_pid)}, state.last_instance: #{inspect(i)}")

    # get the decision from Paxos
    v = Paxos.get_decision(state.pax_pid, i, 1000)
    IO.puts("\n\n\n\nreceive_decisions #{inspect(v)}\n\n\n\n")

    # update the state based on the decision
    case v do
      {:add_to_inventory, client, item, amount} ->
        IO.puts("inside add to inventory, client: #{inspect(client)}, item: #{inspect(item)}, amount: #{inspect(amount)}, i: #{inspect(i)}")
        IO.puts("state.pending: #{inspect(state.pending)}")

        # check if there is a pending transaction
        state = cond do
          state.pending == nil -> state
          {state.name, state.sequence} == client ->
          # notify the client of success or failure
            send(elem(state.pending, 1), {:add_to_inventory_ok})
            %{state | sequence: state.sequence + 1}
          true ->
            send(elem(state.pending, 1), {:add_to_inventory_failed})
            state
        end

        # update the inventory and clear the pending transaction
        state = %{state | pending: nil, inventory: Map.put(state.inventory, item, Map.get(state.inventory, item, 0) + amount)}

        # Update the instance counter and recursively call the function if run_again is true
        state = %{state | last_instance: i}
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

        # check if there is a pending transaction
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

        # update the inventory and clear the pending transaction
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
      # if there is no decision, return the state
       IO.puts("Inventory: #{inspect(state.inventory)}")
       state
    end
  end

  # add item to inventory
  def add_to_inventory(p, item, amount) do
    # send request to add item to inventory
    Utils.unicast(p, {:add_to_inventory, self(), item, amount})
    # wait to receive the response from the process
    receive do
      # if the item can successfully be added to the inventory, return :ok
      {:add_to_inventory_ok} ->
        IO.puts("add_to_inventory_ok")
        :ok
      # if the item cannot be added to the inventory, return :fail
      {:add_to_inventory_failed} ->
        IO.puts("add_to_inventory_failed")
        :fail
      # if the paxos process aborts, return :fail
      {:abort} -> :fail
      _ -> :timeout
    after
      # if no response within 1000 ms, timeout
      1000 -> :timeout
    end
  end

  # remove item from inventory
  def remove_from_inventory(p, item, amount) do
    IO.puts("remove_from_inventory, item: #{inspect(item)}, amount: #{inspect(amount)}, p: #{inspect(p)}")
    # send request to remove item from inventory
    Utils.unicast(p, {:remove_from_inventory, self(), item, amount})
    IO.puts("remove_from_inventory, item: #{inspect(item)}, amount: #{inspect(amount)}, p: #{inspect(p)}")
    # wait to receive the response from the process
    receive do
      # if the item can successfully be removed from the inventory, return :ok
      {:remove_from_inventory_ok} ->
        IO.puts("remove_from_inventory_ok")
        :ok
      # if the item cannot be removed from the inventory, return :fail
      {:remove_from_inventory_failed} ->
        IO.puts("remove_from_inventory_failed")
        :fail
      # if the paxos process aborts, return :fail
      {:abort} -> :fail
      _ -> :timeout
      after
      # if no response within 1000 ms, timeout
      1000 -> :timeout
    end
  end

  # view the inventory
  def view_inventory(p) do
    # send request to view inventory
    Utils.unicast(p, {:view_inventory, self()})
    # wait to receive the response from the process
    receive do
      # if the response is {:inventory, inventory}, return the inventory
      {:inventory, inventory} -> inventory
      # else return a timeout
      _ -> :timeout
    after
      # if no response within 1000 ms, timeout
      1000 -> :timeout
    end
  end
end