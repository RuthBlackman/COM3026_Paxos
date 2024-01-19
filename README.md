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
* Assumes that the timeout values allow for enough time to wait for Paxos decisions and client responses.
* Assumes that a client enters one request at a time.

# Server Implementation #

## Considerations ##

- A process will only recieve an ```:ok``` message when its inventory is up to date and the request has been completed.
- Therefore, a ```:timeout``` or ```:fail``` may appear as an update is in progress.
- This may require the client to make the request again, until it receives an ```:ok``` message.

## Viewing the Inventory ## 

- The client sends the ```view_inventory``` request to the server.
- The server will call ```receive_decisions()```
- Paxos will call ```get_decisions()``` for the instance.
- If the decision returns nil then the inventory of the client is up to date and therefore can be returned to the
  client.
- If the decision is not nil, then the server will either add or remove the item to the inventory based on the decision
  made by Paxos.
- A decision made by Paxos is displayed as ```{:add_to_inventory, {:p1, 0}, 2, 10}```, for example.
    - The first element is the operation to be performed.
    - The second element is a tuple of the process and instance of the request.
    - The third element is the item id.
    - The fourth element is the item quantity.
- The server will then call ```receive_decisions()``` until the server retrieves a nil decision, meaning that the
  client's
  inventory is up to date.
- The server will then return the inventory to the client.

## Adding or Removing an Item to the Inventory ##

- The client sends the ```add_to_inventory``` or ```remove_from_inventory``` request to the server.
- The server checks the amount being proposed is greater than 0.
- If it is not greater than 0, the server will then return a failure message to the client.
- If it is greater, the server will then initiate a Paxos proposal.
- When a decision has been made by Paxos, ```receive_decisions()``` will be called.
- Paxos will get the decision for the instance.
- Depending on the decision, the server will add or remove the item to the inventory.
- If the decision returned by Paxos matches the request made by the client, then a success message will be returned to
  the client.
- If the decision returned by Paxos does not match the request made by the client, then a failure message will be
  returned to the client, because Paxos returned a differnt decision.
    - This will happen if :p1 makes a request (e.g. to add an item to the inventory) before the client made its request.
    - Therefore, the client's inventory was not up to date, so Paxos returned an old decision that was then applied to
      the
      client's inventory.
    - The client will then have to make the request again, which will only be successful if its inventory is up to date
      (i.e there are no more decisions to update the inventory with).

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

