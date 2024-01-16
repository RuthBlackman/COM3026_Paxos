# About Service #
This service is a simple implementation of an inventory management system using the Paxos algorithm.
The user can view the items in the inventory, add items to the inventory, and remove items from the inventory.

# Usage of Paxos #
Paxos is used to ensure that the inventory is consistent across all replicas. 
The Paxos algorithm is used to ensure that all users agree on the state of the inventory.
Each user will have their own instance of Paxos.

# Safety and Liveness Properties #
### Safety ###
* Data remain consistent even if there are failures or updates
  * E.g., if a product is added to the shopping cart, all nodes should eventually reflect this change consistently.

* Transactions will be isolated from each other to prevent interference
  * E.g., Two users attempting to purchase the last item in stock simultaneously should not lead to both transactions being processed successfully.

* Transactions will be either fully completed or fully aborted
  * E.g., Operations such as placing an order or updating inventory are completed as a whole, so that the system is not left with an inconsistent state

### Liveness ###
* The system will eventually respond to users in a timely manner
  * E.g., Users should be able to view products, add items to their cart without excessive delays

* The system will eventually make progress and not become deadlocked
  * E.g., Orders should be processed and inventory updated without getting stuck in a state where no further process can be made

* The system will eventually eventually reach a consensus on a value.

# Assumptions #
* The service will be run on a trusted machine.

# Usage Instructions #
### How to set up ###


### How to run ###

