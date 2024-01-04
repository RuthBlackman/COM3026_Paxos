defmodule Paxos do

  def start(name, participants) do
    # do spawn stuff

    # start Paxos process
    # register in global registry under name
    # return pid
    # participants should include all processes including the one specified by name

    # Spawns a process and calls Paxos.init with the given arguments.
    pid = spawn(Paxos, :init, [name, participants, self()])

    # Register the process in the global registry under the specified name.
    :global.re_register_name(name, pid)

    # Return the pid
    pid

  end

  def init(name, participants, parent_name) do
    # Start the leader detector and reliable broadcast processes
    le = EventualLeaderDetector.start(name, participants, self())
    rb = EagerReliableBroadcast.start(name, participants, self())

    # create state
    state = %{
      name: name,
      participants: participants,
      bal: nil,
      a_bal: nil,
      a_val: nil,
      proposals: %MapSet{},
      leader: nil,
      value: nil,
      inst: nil,
      instances: %MapSet{},
      hasDecided: false,
      parent_name: parent_name,
    }

    run(state)
  end



  def run(state) do
    state = received do
      {:leader_elect, p} ->
        # new leader was elected, so need to start the whole paxos algorithm again
        %{state | leader: p}

        Utils.beb_broadcast(state.participants, {:prepare, b})

      {:prepare, b} ->
        # Check if the ballot b is greater than the current ballot
        if b > state.bal do
          # if it is, update the state
          %{state | bal: b}

          #  Send a prepared message to the leader with the received ballot b,
          #  the ballot 'a_bal' from the received message, and the value 'a_val' from the received message
          send(state.leader, {:prepared, b, a_bal, a_val})
        else do
          # if it is not, send a nack message to the leader with the received ballot b
          send(state.leader, {:nack, b})
        end

      {:prepared, b, a_bal, a_val} ->
        # first need to check if this process is the leader
        if(state.leader == state.name) do
          if a_val == nil do
            # If the value 'a_val' from the received message is nil, then
            # set the state's value to the first proposal
            %{state | value: Enum.at(state.proposals, 0)}
          else do
            # If a_val is not nil, set the state's value to a_val
            %{state | value: a_val}
          end

          # Broadcast the message to all participants
          Utils.beb_broadcast(state.participants, {:accept, b, state.value})
        end

      {:accept, b, V} ->
        # Check if the ballot b is greater than the current ballot
        if(b > state.bal) do
          # Update the ballot in state to b
          %{state | bal: b}

          # Update the state's value to V
          %{state | a_val: V}

          # Update the accepted ballot in state to b
          %{state | a_bal: b}

          # Send an accepted message to the leader with the received ballot b
          send(state.leader, {:accepted, b})
        else do
          # If b is not greater than the current ballot,
          # send a nack message to the leader with the received ballot b
          send(state.leader, {:nack, b})
        end

        # state

      {:accepted, b} ->
        # first need to check if this process is the leader
        if(state.leader == state.name) do
          # Update the state to show that a decision has been made
          %{state | hasDecided: true}
          # Broadcast the message to the parent process (i.e., the process that started Paxos)
          Utils.unicast(state.parent_name, {:decision, state.value})
        end

      {:nack, b} ->
      # Broadcast the abort message to the parent process
        Utils.unicast(state.parent_name, {:abort})

      {:timeout} ->
        # Broadcast the timeout message to the parent process
        Utils.unicast(state.parent_name, {:timeout})

    end
  end



  def propose(pid, inst, value, t) do
    # do paxos stuff

    # take in pid, inst, value, t
    # value is proposed by each pid

    Process.send_after(self(), {:timeout}, t)
    Utils.beb_broadcast(state.participants, {:prepare, b})



    %{state | proposal: MapSet.put(state.proposal, value)}



    # {decide, v} - returned if v has been decided for the inst.
    # {abort} - returned if attempt was interrupted by another proposal with a higher ballot. Can choose to reissue the proposal with the higher ballot.
    # {timeout} - returned if the attempt was not able to be decided or aborted within the timeout speicified by t. I.e. pid has crashed




    # if state.timedout do
    #   {:timeout}
    # else
    #   if state.aborted do
    #     {:abort}
    #   else
    #     {:decide, state.decided}
    #   end
    # end




  end





  def get_decision(pid, inst, t) do
    # takes in pid, inst, t
    # returns v != nil if v has been decided for the inst
    # returns nil if v has not been decided for the inst


  end

end
