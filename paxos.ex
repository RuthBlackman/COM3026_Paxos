defmodule Paxos do

  def start(name, participants) do
    # start Paxos process
    # register in global registry under name
    # return pid
    # participants should include all processes including the one specified by name

    # Spawns a process and calls Paxos.init with the given arguments.
    pid = spawn(Paxos, :init, [name, participants])

    # Register the process in the global registry under the specified name.
    :global.re_register_name(name, pid)

    # Return the pid
    pid

  end

  def init(name, participants) do
    # Start the leader detector and reliable broadcast processes
    le = EventualLeaderDetector.start(name, participants)

    # create state
    state = %{
      name: name,
      participants: participants,
      bal: 0, # current ballot
      #bal: {bal num, proc}
      a_bal: nil,
      a_val: nil,
      # proposals: %MapSet{},
      leader: nil, # id of the leader process
      value: nil, # decided value
      inst: nil, # instance
      #instances: %MapSet{}, # map set of all instances
      parent_name: nil, # name of process that started the Paxos
      preparedQuorum: 0, # number of processes that have sent prepared
      acceptedQuorum: 0, # number of processes that have sent accepted

      ownProposal: nil, # value that process proposed
      heardProposal: nil, # value that another process has proposed
      decision: nil, # value that was decided
      allDecisions: %{}, # map of instance -> decision

      instances: %{}, #instance -> {pid, [proposal 1, proposal 2]}
      pid_parent: nil,
    }

    run(state)
  end



  def run(state) do
    state = receive do
      {:check_instance, pid, inst, value} ->
        IO.puts("#{inspect(state.name)} proposes inst #{inspect(inst)} with value #{inspect(value)}")

        state = %{state | parent_name: pid, pid_parent: pid,}

        # check if a decision was already made for this instance
        potentialDecision = Map.get(state.allDecisions, inst)

        IO.puts("Checking if a decision was already made for the instance #{inst}")
        IO.puts("Decision for inst #{inspect(inst)} is #{inspect(potentialDecision)}")

        # if a decision has not been made yet, then continue with proposal
        # if potentialDecision == nil do
        #   send(self(), {:broadcast, pid, inst, value})
        # else # if a decision has been made already, then return the decision
        #   potentialDecision
        # end

        # if a decision has already been made, then just return decision
        if potentialDecision != nil do
          send(state.parent_name, {:decision, potentialDecision})
          state

        else
          IO.puts("checking if instance #{inspect(inst)} is in map of instances")
          # decision has not been made yet, so check if instance is in map of instances -> proposals
          Utils.beb_broadcast(state.participants, {:update_instances_map, inst, pid, [value]})
          # state= if(Map.has_key?(state.instances, inst)) do
          #   IO.puts("#{inspect(state.name)} has inst #{inspect(inst)} in map")
          #   # if in map, need to add proposal to list of proposals in this map
          #    #%{state | instances: Map.replace(state.instances, inst, Map[inst]++[value])}

          #    Utils.beb_broadcast(state.participants, {:update_instances_map, inst, pid, [value]})
          #   # %{state | instances: Map.put(state.instance, inst, Tuple.append(Map[inst], value))}
          #   state
          # else
          #   IO.puts("#{inspect(state.name)} does not have inst #{inspect(inst)} in map")
          #   Utils.beb_broadcast(state.participants, {:update_instances_map, inst, pid, [value]})
          #   # not in map, so add inst, pid and propsal to map
          #   # %{state | instances: Map.put(state.instances, inst, {pid, [value]})}
          #   state
          # end
          # now need to check if state.inst is nil
          # if it is, then we can broadcast
          # if not, then inst already running so wait

          if(state.inst == nil) do
            IO.puts("#{inspect(state.name)} has state.inst as nil, so send broadcast for inst #{inspect(inst)} as not running an inst yet")

            send(self(), {:broadcast, pid, inst, value})
            %{state | inst: inst}
          end
          state
        end


        # if a decision has not been made, then check if in map of instances -> proposals
        # if in map, then add proposal to list of proposals
        # if not, then add to map

        # if state.inst is nil, then start broadcast
        # if not, then paxos is already running for an instance so just wait

        # state

      {:update_instances_map, inst, pid, [proposals]} ->
        if(Map.has_key?(state.instances, inst)) do
          IO.puts("#{inspect(state.name)} already has inst #{inst} on instances map: #{inspect(state.instances)}")
          state
        else
          state = %{state | instances: Map.put(state.instances, inst, {pid, [proposals]})}
          IO.puts("#{inspect(state.name)} instances map is now #{inspect(state.instances)}")
          state
        end


      {:return_decision, pid, inst} ->
        # return the decision for a given instance


        inst_decision = Map.get(state.allDecisions, inst)
        #IO.puts("Decision for instance: #{inspect(inst_decision)}")

        send(pid, {:return_decision, inst_decision })
        state


      {:broadcast_proposal, value, inst} ->
        # if a process hears another process's proposal, it will store it
        IO.puts("#{state.name} Heard the proposal, #{inspect(value)} and the inst #{inst}")
        %{state | heardProposal: value, inst: inst}


      {:broadcast, pid, inst, value} ->
        IO.puts("#{state.name} is starting broadcast state...")
        # a process will store its own proposal and the instance number
        state = %{state | ownProposal: value, inst: inst}

        IO.puts("process #{state.name} is storing its own proposal #{inspect(value)} and inst number #{inst}")

        # if a process has a proposal, it will broadcast its proposal to everyone
        Utils.beb_broadcast(state.participants, {:broadcast_proposal, value, inst})

        #if process is the leader, it will then broadcast prepare
        IO.puts("#{inspect(state.name)} broadcast: the leader is #{inspect(state.leader)}")
        if(state.name == state.leader) do #TODO Fix it - may call propose twice oops fix
          IO.puts("#{inspect(pid)} is the leader, so it will broadcast prepare, with b as 0")
          Utils.beb_broadcast(state.participants, {:prepare, state.bal + 1, state.name, state.inst}) # first ballot will be 0
          state
         # %{state | proposal: MapSet.put(state.proposal, value), bal: 0}
        else
          state
        end

      {:leader_elect, p} ->


        IO.puts("#{state.name} - #{p} is elected as the leader, so send prepare to all processes with bal #{state.bal+1}")

        if(state.name == p) do
          # leader already has proposals
          if(state.ownProposal != nil || state.heardProposal != nil) do
            IO.puts("#{inspect(p)}: new leader, already has proposals, instance: #{inspect(state.inst)} ")
            Utils.beb_broadcast(state.participants, {:prepare, state.bal+1,p, state.inst })
            state
          end

        end


        # new leader was elected, so need to start the whole paxos algorithm again
        %{state | leader: p, bal: state.bal}

      {:prepare, b, leader, inst} ->
        if state.inst == inst do
          IO.puts("prepare #{state.name} for inst #{inspect(inst)}")

          # Check if the ballot b is greater than the current ballot
          if b > state.bal do


            IO.puts("#{inspect(state.name)}: b is greater than state.bal, so update bal #{b} for inst #{inspect(inst)} and send #{inspect(leader)} prepared")

            #  Send a prepared message to the leader with the received ballot b,
            #  the ballot 'a_bal' from the received message, and the value 'a_val' from the received message
            Utils.unicast(leader, {:prepared, b, state.a_bal, state.a_val, state.inst})

                      # if it is, update the bal and the leader in state
            %{state | bal: b, leader: leader}


          else
            # if it is not, send a nack message to the leader with the received ballot b
            IO.puts("nack was sent #{b}")
            send(leader, {:nack, b})
            state
          end
          state
        else
          state
        end


      {:prepared, b, a_bal, a_val, inst} ->
        IO.puts("inst coming in is #{inspect(inst)}, but state inst is #{inspect(state.inst)}")
        if inst == state.inst do
          IO.puts("prepared #{inspect(state.name)} for inst #{inspect(inst)}")
          # increment quorum of processes who sent prepared
          state = %{state | preparedQuorum: state.preparedQuorum+1}

          # need to check if this process is the leader
          if(state.leader == state.name) do
            # now check if there is a quorum
            IO.puts("#{inspect(state.leader)} is checking if there is a quorum for prepared: #{inspect(state.preparedQuorum)}")
            if(state.preparedQuorum >= (floor(length(state.participants)/2) +1)) do
              IO.puts("reached quorum for prepared")
              state= if a_val == nil do
                # If the value 'a_val' from the received message is nil, then V will be the leader's proposal (or the heard proposal if it doesnt have one)
                IO.puts("#{state.name} own proposal: #{inspect(state.ownProposal)}")
                IO.puts("#{state.name} heard proposal: #{inspect(state.heardProposal)}")

                if state.ownProposal != nil do
                  IO.puts("leader #{inspect(state.leader)} is using own proposal, which is #{inspect(state.ownProposal)}")
                  v = state.ownProposal
                  %{state | value: v}

                else
                  v = state.heardProposal
                  IO.puts("leader #{inspect(state.leader)} is using heard proposal, which is #{inspect(state.heardProposal)}")
                  %{state | value: v}
                end
              else
                IO.puts("leader #{state.leader} is using a_val, which is #{inspect(a_val)}")
                # If a_val is not nil, set the state's value to a_val
                v = a_val
                %{state | value: v}

              end

              # Broadcast the message to all participants
              IO.puts("broadcast accept to participants, #{inspect(state.value)}")
              Utils.beb_broadcast(state.participants, {:accept, b, state.value, state.name, inst})
              state
            end
          end
          state
        else
          state
        end
        # IO.puts("not the right state, ignore: inst #{inspect(inst)}")
        # state


      {:accept, b, v, sender, inst} ->
        if inst == state.inst do
          # Check if the ballot b is greater than the current ballot
          IO.puts("in accept, b is #{inspect(b)} and state.bal is #{inspect(state.bal)}")
          if(b >= state.bal) do
            IO.puts("in accept, b>state.bal, so update bal, a_val, and a_bal")

            # Send an accepted message to the leader with the received ballot b
            Utils.unicast(sender, {:accepted, b, inst})

            IO.puts("a_val is #{inspect(v)}, a_bal is #{inspect(b)}")

                      # Update the ballot, a_val, and a_bal
            %{state | bal: b, a_val: v, a_bal: b}
          else
            # If b is not greater than the current ballot,
            # send a nack message to the leader with the received ballot b

            IO.puts("in accept, b < state.bal, so send nack to the leader #{state.leader}")
            Utils.unicast(sender, {:nack, b, inst})
            state
          end
        else
          state
        end
        # state


        #state

      {:accepted, b, inst} ->
        if inst == state.inst do
          state = %{state | acceptedQuorum: state.acceptedQuorum+1}

          # first need to check if this process is the leader
          if(state.leader == state.name) do
            if(state.acceptedQuorum >= (floor(length(state.participants)/2) +1)) do # check if there is a quorum of accepted

            IO.puts("in accepted, there is a quorum, so leader #{state.leader} sends decision to parent and participants")
            IO.puts("in accepted, the value is #{inspect(state.a_val)} and the instance is #{inspect(state.inst)}")

              # Broadcast the decision to the parent process (i.e., the process that started Paxos)
              # send(state.parent_name, {:decision, state.a_val})

              # check if parent_name exists, if it does, then send decision. if it doesnt exist, then there was no proposal so ignore it
              if state.parent_name != nil do
                send(state.parent_name, {:decision, state.a_val})
              end

              # broadcast the decision all the participants
              Utils.beb_broadcast(state.participants, {:received_decision, state.a_val, inst})

              state

            end
          else
            IO.puts("no quorum reached for accepted yet")
            state
          end

          state
        else
          state
        end

        # state


      {:nack, b} ->
      # Broadcast the abort message to the parent process
        Utils.unicast(state.parent_name, {:abort})
        IO.puts("broadcasting abort to parent")
        state

      # {:timeout} ->
      #   # Broadcast the timeout message to the parent process
      #   Utils.unicast(state.parent_name, {:timeout})
      #   IO.puts("broadcasting timeout to parent")
      #   state

      {:received_decision, v, inst} ->
        # store decision and instance in a map

        # instance now done, so also need to remove instance from map of instances -> proposals, and set inst to nil
        IO.puts("#{state.name} attempting to remove inst #{inst} from state.instances, which has value #{inspect(state.instances)}")
        state= %{state | decision: v, allDecisions: Map.put(state.allDecisions, inst, v), instances: Map.delete(state.instances, inst), inst: nil}
        IO.puts("#{state.name} new instance map value is #{inspect(state.instances)}")

         # clear the quorums as they are no longer needed and update hasDecided
         state = %{state |
            bal: 0, # current ballot
            #bal: {bal num, proc}
            a_bal: nil,
            a_val: nil,
            # proposals: %MapSet{},
            value: nil, # decided value
            inst: nil, # instance
            #instances: %MapSet{}, # map set of all instances
            preparedQuorum: 0, # number of processes that have sent prepared
            acceptedQuorum: 0, # number of processes that have sent accepted

            ownProposal: nil, # value that process proposed
            heardProposal: nil, # value that another process has proposed
            decision: nil, # value that was decided
            pid_parent: nil,
        }

        # now need to check if there are any instances in instance map
        # if there are, then start broadcast

        IO.puts("all decisions is #{inspect(state.allDecisions)}")
        IO.puts("instances map is #{inspect(state.instances)}")
        foundInstance = Enum.at(Map.keys(state.instances), 0)
        foundInstanceProposal = Map.get(state.instances, foundInstance)
        # IO.puts("first key in instances is #{inspect(Enum.at(Map.keys(state.instances), 0))},
        # the tuple is #{inspect(Map.get(state.instances, foundInstance))},
        # the pid is #{inspect(Enum.at(Map.get(state.instances, foundInstance), 0))}
        # and the value is #{inspect(Enum.at(Map.get(state.instances, foundInstance), 1))}")



        # check if there is another instance in instances
        if(foundInstance != nil) do
          # if there is, then call broadcast for that instance
          IO.puts("starting broadcast for new instance")
          {pid, proposals} = foundInstanceProposal
          if state.name == state.leader do
            send(self(), {:broadcast, pid, foundInstance, Enum.at(proposals, 0)})
          end
          IO.puts("instance, #{inspect(foundInstance)} ")
          IO.puts("pid is #{inspect(pid)}")
          IO.puts("proposal is #{inspect(Enum.at(proposals, 0))}")
          #%{state | inst: foundInstance, value: Enum.at(proposals, 0)}
        # else
        #   state
        end

        state


       # Enum.at(Map.keys(state.instance), 0)




    end
    run(state)
  end



  def propose(pid, inst, value, t) do
    # take in pid, inst, value, t
    # value is proposed by each pid

    Process.send_after(self(), {:timeout}, t) # start timeout

    # need to check whether this instance has a decision
    send(pid, {:check_instance, self(), inst, value})



    result = receive do
      {:decision, v} ->
        IO.puts("Decision #{inspect(v)}")
        {:decision,v}
      {:abort} ->
        {:abort}
    after
      t -> {:timeout}
    end


    # {decide, v} - returned if v has been decided for the inst.
    # {abort} - returned if attempt was interrupted by another proposal with a higher ballot. Can choose to reissue the proposal with the higher ballot.
    # {timeout} - returned if the attempt was not able to be decided or aborted within the timeout speicified by t. I.e. pid has crashed

  end





  def get_decision(pid, inst, t) do
    # takes in pid, inst, t
    # returns v != nil if v has been decided for the inst
    # returns nil if v has not been decided for the inst

    Process.send_after(self(), {:timeout}, t) # start timeout


    send(pid, {:return_decision, self(), inst})
    result = receive do
      {:return_decision, v } ->
        #IO.puts("get_decision got a decision #{inspect(v)}")
          v
      {:timeout} ->
        nil
    end

  end
end
