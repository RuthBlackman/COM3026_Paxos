- README file detailing the service API (4 marks)
- Usage instructions and any assumptions that have been made (3 marks)
- And safety and liveness properties (3 marks): 10 marks

### Team Members ###

- Angeliki (Angelique) Baltsoukou - 6634908
- Ruth Blackman - 6623139

# About Service #

This service is a simple implementation of an inventory management system using the Paxos algorithm.
The user can view the items in the inventory, add items to the inventory, and remove items from the inventory.

# Usage of Paxos #

Paxos is used to ensure that the inventory is consistent across all replicas.
The Paxos algorithm is used to ensure that all users agree on the state of the inventory.
Each user will have their own instance of Paxos.

# Safety and Liveness Properties #

### Safety ###

- Data remains consistent even if there are failures or updates.
    - E.g., if an item is added or removed from the inventory, all nodes should eventually reflect this change
      consistently.

- Transactions will be isolated from each other to prevent interference.
    - Incorrect transactions should not lead to it being completed successfully.

- Transactions will be either fully completed or fully aborted.
    - E.g., Operations such as adding an item to the inventory or removing an item from the inventory are completed as a
      whole, so that the system is not left with an inconsistent state.

### Liveness ###

- The system will eventually respond to users in a timely manner.
    - E.g., Users should be able to view items, add items to the inventory and remove items from the inventory without
      excessive delays.

- The system will eventually make progress and not become deadlocked.
    - E.g., The inventory should be updated without getting stuck in a state where no further process can be made.

- The system will eventually reach a consensus on a value.

# Assumptions #

* The service will be run on a trusted machine.

# Usage Instructions #

## For Using a Single Client ##

1. Start running iex in the terminal

```
iex
```

2. Compile the files

```
c "paxos.ex" ; c "server.ex"
```

3. Define the processes

```
procs = Enum.to_list(1..3) |> Enum.map(fn m -> :"p#{m}" end)
```

4. Define the process ids

```
pids = Enum.map(procs, fn p -> InventoryServer.start(p, procs) end)
```

5. To add an item to the inventory

```
InventoryServer.add_to_inventory(p0, item, amount)
```

- where
    - item is replaced with the item number
    - amount is replaced with the amount of the item to be added to the inventory

6. To remove an item from the inventory

```
InventoryServer.remove_from_inventory(p0, item, amount)
```

- where
    - item is replaced with the item number
    - amount is replaced with the amount of the item to be added to the inventory

7. To end the session and kill the processes

```
pids |> Enum.map(fn p -> Process.exit(p, :kill) end)
```

## For Using Multiple Clients ##

The following steps should be repeated for each client terminal.

1. Open terminals
2. Define names for each process

```
iex --sname clientname
```

3. Connect the nodes together

```
Node.connect(:"clientname@computername")
```

- where clientname is the name of the client and computername is the name of the computer

4. Compile the files

```
c "paxos.ex" ; c "server.ex"
```

5. Define the processes - this should be done done only on one of the terminals

```
procs = Enum.to_list(1..3) |> Enum.map(fn m -> :"p#{m}" end)
```

6. Define the process ids - this should be done done only on one of the terminals

```
pids = Enum.map(procs, fn p -> InventoryServer.start(p, procs) end)
```

7. To add an item to the inventory

```
InventoryServer.add_to_inventory(a, item, amount)
```

- where
    - a is replaced with the server number (i.e., :p0, :p1, ...)
    - item is replaced with the item number
    - amount is replaced with the amount of the item to be added to the inventory

8. To remove an item from the inventory

```
InventoryServer.remove_from_inventory(a, item, amount)
```

- where
    - a is replaced with the client name
    - item is replaced with the item number
    - amount is replaced with the amount of the item to be added to the inventory

9. To end the session and kill the processes

```
pids |> Enum.map(fn p -> Process.exit(p, :kill) end)
```