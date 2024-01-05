defmodule Paxos do

  def start(name, participants) do
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
    le = EventualLeaderDetector.start(name, participants)
    rb = EagerReliableBroadcast.start(name, participants,self())

    # create state
    state = %{
      name: name,
      participants: participants,
      bal: nil, # current ballot
      a_bal: nil,
      a_val: nil,
      # proposals: %MapSet{},
      leader: nil, # id of the leader process
      value: nil, # decided value
      inst: nil, # instance
      #instances: %MapSet{}, # map set of all instances
      hasDecided: false, # has a decision been made?
      parent_name: parent_name, # name of process that started the Paxos
      preparedQuorum: 0, # number of processes that have sent prepared
      acceptedQuorum: 0, # number of processes that have sent accepted

      ownProposal: nil, # value that process proposed
      heardProposal: nil, # value that another process has proposed
      decision: nil, # value that was decided
      allDecisions: %{}, # map of instance -> decision
    }

    run(state)
  end



  def run(state) do
    state = receive do
      {:return_decision, pid, inst, t} ->
        # return the decision for a given instance
        Map.get(state.allDecisions, inst)


      {:broadcast_proposal, value} ->
        # if a process hears another process's proposal, it will store it
        %{state | heardProposal: value}


       {:check_instance, pid, inst, value, t} ->
        # check if a decision was already made for this instance
        potentialDecision = Map.get(state.allDecisions, inst)

        # if a decision has not been made yet, then continue with proposal
        if potentialDecision == nil do
          send(self(), {:broadcast, pid, inst, value, t})
        else # if a decision has been made already, then return the decision
          potentialDecision
        end


      {:broadcast, pid, inst, value, t} ->
        # a process will store its own proposal
        %{state | ownProposal: value}

        # store the instance number
        %{state | inst: inst}

        # if a process has a proposal, it will broadcast its proposal to everyone
        Utils.beb_broadcast(state.partipants, {:broadcast_proposal, value})

        #if process is the leader, it will then broadcast prepare
        if(pid == state.leader) do
          Utils.beb_broadcast(state.participants, {:prepare, 0,pid}) # first ballot will be 0
          %{state | proposal: MapSet.put(state.proposal, value)}
        end


      {:leader_elect, p} ->
        # new leader was elected, so need to start the whole paxos algorithm again
        %{state | leader: p}

        Utils.beb_broadcast(state.participants, {:prepare, state.bal+1}) # need to increment ballot when leader changes

        state

      {:prepare, b, leader} ->
        # Check if the ballot b is greater than the current ballot
        if b > state.bal do
          # if it is, update the state
          %{state | bal: b}

          # update leader
          %{state | leader: leader}

          #  Send a prepared message to the leader with the received ballot b,
          #  the ballot 'a_bal' from the received message, and the value 'a_val' from the received message
          send(leader, {:prepared, b, state.a_bal, state.a_val})


        else
          # if it is not, send a nack message to the leader with the received ballot b
          send(leader, {:nack, b})
        end


        state

      {:prepared, b, a_bal, a_val} ->
        # increment quorum of processes who sent prepared
        %{state | preparedQuorum: state.preparedQuorum+1}

        # need to check if this process is the leader
        if(state.leader == state.name) do
          # now check if there is a quorum
          if(state.preparedQuorum > (state.partipants/2 +1)) do
            if a_val == nil do
              # If the value 'a_val' from the received message is nil, then V will be the leader's proposal (or the heard proposal if it doesnt have one)

              if state.ownProposal != nil do
                V = state.ownProposal
                %{state | value: V}
              else
                V = state.heardProposal
                %{state | value: V}
              end
            else
              # If a_val is not nil, set the state's value to a_val
              V = a_val
              %{state | value: V}
            end



            # Broadcast the message to all participants
            Utils.beb_broadcast(state.participants, {:accept, b, state.value})
          end
        end
        state

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
        else
          # If b is not greater than the current ballot,
          # send a nack message to the leader with the received ballot b
          send(state.leader, {:nack, b})
        end

        state

      {:accepted, b} ->
        %{state | acceptedQuorum: state.acceptedQuorum+1}

        # first need to check if this process is the leader
        if(state.leader == state.name) do
          if(state.acceptedQuorum > (state.partipants/2 +1)) do # check if there is a quorum of accepted

            # Update the state to show that a decision has been made
            %{state | hasDecided: true}
            # Broadcast the decision to the parent process (i.e., the process that started Paxos)
            Utils.unicast(state.parent_name, {:decision, state.value})

            # broadcast the decision all the participants
            Utils.beb_broadcast(state.partipants, {:received_decision, state.value})


            # clear the quorums as they are no longer needed
            %{state | preparedQuorum: %MapSet{}}
            %{state | acceptedQuorum: %MapSet{}}

          end
        end
        state

      {:nack, b} ->
      # Broadcast the abort message to the parent process
        Utils.unicast(state.parent_name, {:abort})

      {:timeout} ->
        # Broadcast the timeout message to the parent process
        Utils.unicast(state.parent_name, {:timeout})

      {:received_decision, v} ->
        # the process will store the decision
        %{state | decision: v}

        # store decision and instance in a map
        %{state | allDecisions: Map.put(state.allDecisions, state.inst, v)}


    end
  end



  def propose(pid, inst, value, t) do
    # take in pid, inst, value, t
    # value is proposed by each pid

    Process.send_after(self(), {:timeout}, t) # start timeout

    # need to check whether this instance has a decision
    send(self(), {:check_instance, pid, inst, value, t})

    result = receive do
      {:decision, v} ->
        IO.puts("Decision #{v}")
    end


    # {decide, v} - returned if v has been decided for the inst.
    # {abort} - returned if attempt was interrupted by another proposal with a higher ballot. Can choose to reissue the proposal with the higher ballot.
    # {timeout} - returned if the attempt was not able to be decided or aborted within the timeout speicified by t. I.e. pid has crashed

  end





  def get_decision(pid, inst, t) do
    # takes in pid, inst, t
    # returns v != nil if v has been decided for the inst
    # returns nil if v has not been decided for the inst

    send(self(), {:return_decision, pid, inst, t})


  end
end
