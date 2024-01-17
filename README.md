- README file detailing the service API (4 marks), 
- usage instructions and any assumptions that have been made (3 marks), 
- and safety and liveness properties (3 marks): 10 marks

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
  - E.g., if an item is added or removed from the inventory, all nodes should eventually reflect this change consistently.
  
- Transactions will be isolated from each other to prevent interference.
  - Incorrect transactions should not lead to it being completed successfully.
  
- Transactions will be either fully completed or fully aborted.
  - E.g., Operations such as adding an item to the inventory or removing an item from the inventory are completed as a whole, so that the system is not left with an inconsistent state.

### Liveness ###
- The system will eventually respond to users in a timely manner.
  - E.g., Users should be able to view items, add items to the inventory and remove items from the inventory without excessive delays.
  
- The system will eventually make progress and not become deadlocked.
  - E.g., The inventory should be updated without getting stuck in a state where no further process can be made.
  
- The system will eventually reach a consensus on a value.


# Assumptions #
* The service will be run on a trusted machine.

# Usage Instructions #
1. Start iex using ```iex``` in the terminal.
2. Compile the code using ```c "paxos.ex"``` and ```c "server.ex"```
3. ```procs = Enum.to_list(1..3) |> Enum.map(fn m -> :"p#{m}" end)```
4. ```pids = Enum.map(procs, fn p -> InventoryServer.start(p, procs) end)```
5. ```a = Enum.at(pids, 0)```
6. To add an item to the inventory, use ```InventoryServer.add_to_inventory(a, 1, 10)```

7. To kill the processes use ```pids |> Enum.map(fn p -> Process.exit(p, :kill) end)```