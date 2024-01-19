- README file detailing the service API?
- any assumptions that have been made

### Team Members ###

- Angeliki (Angelique) Baltsoukou - 6634908
- Ruth Blackman - 6623139

# About Service #

This service is a simple implementation of a distributed inventory management system using the Paxos consensus
algorithm. The server handles transactions such as adding or removing items from the inventory, as well as viewing the
inventory by initiating a Paxos process to achieve consensus among distributed nodes. Functions on the client interface
allow for external processes to interact with the server, sending requests and receiving responses. The Paxos algorithm
ensures consistent and fault-tolerant decision-making in a distributed environment.

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


* Assumes that the client has reliable behaviour.
* Assumes that the timeout values allow for enough time to wait for Paxos decisions and client responses.

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
InventoryServer.add_to_inventory(:p1, item, amount)
```

- where
    - item is replaced with the item number
    - amount is replaced with the amount of the item to be added to the inventory

6. To remove an item from the inventory

```
InventoryServer.remove_from_inventory(:p1, item, amount)
```

- where
    - item is replaced with the item number
    - amount is replaced with the amount of the item to be added to the inventory

7. To view the inventory

```
InventoryServer.view_inventory(:p1)
```

- where
    - a is replaced with the client name

8. To end the session and kill the processes

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

- where
    - clientname is the name of the client
    - computername is the name of the computer

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
InventoryServer.add_to_inventory(:a, item, amount)
```

- where
    - a is replaced with the server number (i.e., :p1, :p2, ...)
    - item is replaced with the item number
    - amount is replaced with the amount of the item to be added to the inventory

8. To remove an item from the inventory

```
InventoryServer.remove_from_inventory(:a, item, amount)
```

- where
    - a is replaced with the client name
    - item is replaced with the item number
    - amount is replaced with the amount of the item to be added to the inventory

9. To view the inventory

```
InventoryServer.view_inventory(:a)
```

- where
    - a is replaced with the client name

9. To end the session and kill the processes

```
pids |> Enum.map(fn p -> Process.exit(p, :kill) end)
```