# ----------------------------
# Paxos
# ----------------------------
defmodule Paxos do

  def log(msg) do
    if false do
      IO.puts(msg)
    end
  end

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
      #bal: 0, # current ballot
      bal: {0, name}, #ballot number, process id
      a_bal: nil, # {bal_num, proc_id}
      a_val: nil, # could be any type
   #   a_val_list: [], # [{a_bal, a_val}]
      a_bal_max: nil, # {bal_num, proc_id}
      a_val_max: nil,
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
      parent_pid: nil,
      action: nil,
    }

    run(state)
  end



  def run(state) do
    state = receive do
      {:check_instance, pid, inst, value, action} ->
        log("#{inspect(state.name)} proposes inst #{inspect(inst)} with value #{inspect(value)}")

        state = %{state | parent_name: pid, parent_pid: pid,}

        # check if a decision was already made for this instance
        potentialDecision = Map.get(state.allDecisions, inst)

        # log("Checking if a decision was already made for the instance #{inst}")
        log("Decision for inst #{inspect(inst)} is #{inspect(potentialDecision)}")

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
          if action == :increase_ballot_number do
            log("#{state.name} increasing ballot number")

            send(pid, {:timeout});

            %{state| bal: Utils.increment_ballot_number(state.bal, state.name)}
          else


            log("checking if instance #{inspect(inst)} is in map of instances")
            # decision has not been made yet, so check if instance is in map of instances -> proposals
            Utils.beb_broadcast(state.participants, {:update_instances_map, inst, pid, [value]})
            # state= if(Map.has_key?(state.instances, inst)) do
            #   log("#{inspect(state.name)} has inst #{inspect(inst)} in map")
            #   # if in map, need to add proposal to list of proposals in this map
            #    #%{state | instances: Map.replace(state.instances, inst, Map[inst]++[value])}

            #    Utils.beb_broadcast(state.participants, {:update_instances_map, inst, pid, [value]})
            #   # %{state | instances: Map.put(state.instance, inst, Tuple.append(Map[inst], value))}
            #   state
            # else
            #   log("#{inspect(state.name)} does not have inst #{inspect(inst)} in map")
            #   Utils.beb_broadcast(state.participants, {:update_instances_map, inst, pid, [value]})
            #   # not in map, so add inst, pid and propsal to map
            #   # %{state | instances: Map.put(state.instances, inst, {pid, [value]})}
            #   state
            # end
            # now need to check if state.inst is nil
            # if it is, then we can broadcast
            # if not, then inst already running so wait

            state = if(state.inst == nil) do
              log("#{inspect(state.name)} has state.inst as nil, so send broadcast for inst #{inspect(inst)} as not running an inst yet")

              send(self(), {:broadcast, pid, inst, value})
              %{state | inst: inst}
            else
              state
            end

            %{state | action: action}
          end
        end


        # if a decision has not been made, then check if in map of instances -> proposals
        # if in map, then add proposal to list of proposals
        # if not, then add to map

        # if state.inst is nil, then start broadcast
        # if not, then paxos is already running for an instance so just wait

        # state

      {:update_instances_map, inst, pid, [proposals]} ->
        if(Map.has_key?(state.instances, inst)) do
          log("#{inspect(state.name)} already has inst #{inst} on instances map: #{inspect(state.instances)}")
          state
        else
          state = %{state | instances: Map.put(state.instances, inst, {pid, [proposals]})}
          log("#{inspect(state.name)} instances map is now #{inspect(state.instances)}")
          state
        end


      {:return_decision, pid, inst} ->
        # return the decision for a given instance


        inst_decision = Map.get(state.allDecisions, inst)
        #log("Decision for instance: #{inspect(inst_decision)}")

        send(pid, {:return_decision, inst_decision })
        state


      {:broadcast_proposal, value, inst} ->
        # if a process hears another process's proposal, it will store it
        log("#{state.name} Heard the proposal, #{inspect(value)} and the inst #{inst}")
        state = %{state | heardProposal: value, inst: inst}

        # if leader, send prepare
        if state.name == state.leader do
          Utils.beb_broadcast(state.participants, {:prepare, Utils.increment_ballot_number(state.bal, state.name),state.name, state.inst })
          state
        end

        state


      {:broadcast, pid, inst, value} ->
        log("#{state.name} is starting broadcast state...")
        # a process will store its own proposal and the instance number
        state = %{state | ownProposal: value, inst: inst}

        log("#{state.name} is storing its own proposal #{inspect(value)} and inst number #{inst}")

        # if a process has a proposal, it will broadcast its proposal to everyone
        Utils.beb_broadcast(state.participants, {:broadcast_proposal, value, inst})

        #if process is the leader, it will then broadcast prepare
        log("#{inspect(state.name)} broadcast: the leader is #{inspect(state.leader)}")
        if(state.name == state.leader) do #TODO Fix it - may call propose twice oops fix
          log("#{inspect(pid)} is the leader, so it will broadcast prepare")
      #    Utils.beb_broadcast(state.participants, {:prepare, state.bal + 1, state.name, state.inst}) # first ballot will be 0
          Utils.beb_broadcast(state.participants, {:prepare, Utils.increment_ballot_number(state.bal, state.name),state.name, state.inst })
          state
         # %{state | proposal: MapSet.put(state.proposal, value), bal: 0}
        else
          state
        end

      {:leader_elect, p} ->
        log("#{state.name} - #{p} is elected as the leader, so send prepare to all processes with bal ...")

        if(state.name == p) do
          # leader already has proposals
          if(state.ownProposal != nil || state.heardProposal != nil) do
            log("#{inspect(p)}: new leader, already has proposals, instance: #{inspect(state.inst)} ")
            #Utils.beb_broadcast(state.participants, {:prepare, state.bal+1,p, state.inst })
            Utils.beb_broadcast(state.participants, {:prepare, Utils.increment_ballot_number(state.bal, p),p, state.inst })
            state
          end

        end


        # new leader was elected, so need to start the whole paxos algorithm again
        %{state | leader: p, bal: state.bal}

      {:prepare, b, leader, inst} ->
        if state.inst == inst do
          log("#{inspect(state.name)} prepare: own ballot #{inspect(state.bal)}, incoming ballot #{inspect(b)}, inst #{inspect(inst)}")

          # Check if the ballot b is greater than the current ballot
          #if b > state.bal do
          # log("bal is #{inspect(b)}")
          # log("state.bal is #{inspect(state.bal)}")
          # log("#{inspect(state.name)}: compare ballot comparison in prepare: #{inspect(Utils.compare_ballot(b, &>/2, state.bal))}")
          if Utils.compare_ballot(b, &>/2, state.bal) do

            log("#{inspect(state.name)}: b #{inspect(b)} is greater than state.bal #{inspect(state.bal)}, so update bal for inst #{inspect(inst)} and send #{inspect(leader)} prepared")

            #  Send a prepared message to the leader with the received ballot b,
            #  the ballot 'a_bal' from the received message, and the value 'a_val' from the received message
            Utils.unicast(leader, {:prepared, b, state.a_bal, state.a_val, state.inst})

            # set a_val_max and a_bal_max to be nil and update the bal and the leader in state
            %{state | bal: b, leader: leader, a_bal_max: nil, a_val_max: nil}


          else
            # if it is not, send a nack message to the leader with the received ballot b
            log("#{inspect(state.name)} sent nack to the leader #{inspect(state.leader)}, ballot is #{inspect(b)}")
            Utils.unicast(leader, {:nack, b, inst})
            state
          end
          state
        else
          state
        end


      {:prepared, b, a_bal, a_val, inst} ->
        # log("inst coming in is #{inspect(inst)}, but state inst is #{inspect(state.inst)}")
        if inst == state.inst do
          # log("prepared #{inspect(state.name)} for inst #{inspect(inst)}")
          # increment quorum of processes who sent prepared
          state = %{state | preparedQuorum: state.preparedQuorum+1}

          # update a_bal_max and a_val_max
          state= if a_bal == nil and a_val == nil do
            state
          else
            if state.a_bal_max == nil do
                %{state | a_bal_max: a_bal, a_val_max: a_val}
            else
              if a_bal > state.a_bal_max do
                %{state | a_bal_max: a_bal, a_val_max: a_val}
              else
                state
              end

            end
          end

          # need to check if this process is the leader
          if(state.leader == state.name) do
            # now check if there is a quorum
            log("#{inspect(state.leader)} is checking if there is a quorum for prepared: #{inspect(state.preparedQuorum)}")
            if(state.preparedQuorum >= (floor(length(state.participants)/2) +1)) do
              log("reached quorum for prepared")

              state= if state.a_val_max == nil do
                # If the value 'a_val' from the received message is nil, then V will be the leader's proposal (or the heard proposal if it doesnt have one)
                # log("#{state.name} own proposal: #{inspect(state.ownProposal)}")
                # log("#{state.name} heard proposal: #{inspect(state.heardProposal)}")

                if state.ownProposal != nil do
                  log("leader #{inspect(state.leader)} is using own proposal, which is #{inspect(state.ownProposal)}")
                  v = state.ownProposal
                  %{state | value: v}

                else
                  v = state.heardProposal
                  log("leader #{inspect(state.leader)} is using heard proposal, which is #{inspect(state.heardProposal)}")
                  %{state | value: v}
                end
              else
                log("leader #{state.leader} is using a_val, which is #{inspect(state.a_val_max)}")
                # If a_val is not nil, set the state's value to a_val
                v = state.a_val_max
                %{state | value: v}

              end

              # Broadcast the message to all participants
              log("broadcast accept to participants, #{inspect(state.value)}")
              Utils.beb_broadcast(state.participants, {:accept, b, state.value, state.name, inst})
              state
            end
          end
          state
        else
          state
        end
        # log("not the right state, ignore: inst #{inspect(inst)}")
        # state


      {:accept, b, v, sender, inst} ->
        if inst == state.inst do
          # Check if the ballot b is greater than the current ballot
          # log("in accept, b is #{inspect(b)} and state.bal is #{inspect(state.bal)}")
         # if(b >= state.bal) do
          if Utils.compare_ballot(b, &>=/2, state.bal) do
            log("#{inspect(state.name)} in accept, b>state.bal, so update bal, a_val, and a_bal")

            # Send an accepted message to the leader with the received ballot b
            Utils.unicast(sender, {:accepted, b, inst})

            # log("a_val is #{inspect(v)}, a_bal is #{inspect(b)}")

                      # Update the ballot, a_val, and a_bal
            %{state | bal: b, a_val: v, a_bal: b}
          else
            # If b is not greater than the current ballot,
            # send a nack message to the leader with the received ballot b

            log("#{inspect(state.name)}: in accept, b < state.bal, so send nack to the leader #{state.leader}")
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

            log("in accepted, there is a quorum, so leader #{state.leader} sends decision to parent and participants")
         #   log("in accepted, the value is #{inspect(state.a_val)} and the instance is #{inspect(state.inst)}")

              if state.action == :kill_before_decision do
                log("#{state.name} going to kill my self because of your actions")
                Process.exit(self(), :kill)
              end
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
            log("no quorum reached for accepted yet")
            state
          end

          state
        else
          state
        end

        # state


      {:nack, b, inst} ->
        # Broadcast the abort message to the parent process
        log("#{inspect(elem(b,0))} and #{inspect(elem(state.bal, 0))}")
        if state.inst == inst  do
          log("#{inspect(state.name)} NACK for bal #{inspect(b)}")
          # check if process is the leader and has the same ballot number
          if state.leader == state.name do
          #  log("#{inspect(state.name)} ready to abort")
            # if the process has a parent pid, then send the abort to it
            if state.parent_pid != nil do
              send(state.parent_pid, {:abort})
              log("#{inspect(state.name)} broadcasting abort to parent for inst #{inspect(inst)}")
              Utils.beb_broadcast(state.participants, {:abort, b, inst})
            end
              # process doesn't have a parent pid to inform, so just broadcast to the participants
              log("#{inspect(state.name)} doesnt have a parent pid, so broadcast abort to the participants")
              Utils.beb_broadcast(state.participants, {:abort, b, inst})
          end
        end

        state

      # {:timeout} ->
      #   # Broadcast the timeout message to the parent process
      #   Utils.unicast(state.parent_name, {:timeout})
      #   log("broadcasting timeout to parent")
      #   state

      {:abort, b, inst} ->
        if state.inst == inst do
          log("#{inspect(state.name)} reached the abort event for ballot #{inspect(b)}")
          if state.parent_pid != nil do
            send(state.parent_pid, {:abort})
            log("#{inspect(state.name)} broadcasting abort to parent for inst #{inspect(inst)}")
            Utils.beb_broadcast(state.participants, {:abort, b, inst})
          end
        end
        state



      {:received_decision, v, inst} ->
        # store decision and instance in a map

        # instance now done, so also need to remove instance from map of instances -> proposals, and set inst to nil
        log("#{state.name} attempting to remove inst #{inst} from state.instances, which has value #{inspect(state.instances)}")
        state= %{state | decision: v, allDecisions: Map.put(state.allDecisions, inst, v), instances: Map.delete(state.instances, inst), inst: nil}
        log("#{state.name} new instance map value is #{inspect(state.instances)}")

         # clear the quorums as they are no longer needed and update hasDecided
         state = %{state |
           # bal: 0, # current ballot
            bal: {0, state.name},
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
            parent_pid: nil,

            action: nil,
        }

        # now need to check if there are any instances in instance map
        # if there are, then start broadcast

      #  log("all decisions is #{inspect(state.allDecisions)}")
     #   log("instances map is #{inspect(state.instances)}")
        foundInstance = Enum.at(Map.keys(state.instances), 0)
        foundInstanceProposal = Map.get(state.instances, foundInstance)
        # log("first key in instances is #{inspect(Enum.at(Map.keys(state.instances), 0))},
        # the tuple is #{inspect(Map.get(state.instances, foundInstance))},
        # the pid is #{inspect(Enum.at(Map.get(state.instances, foundInstance), 0))}
        # and the value is #{inspect(Enum.at(Map.get(state.instances, foundInstance), 1))}")



        # check if there is another instance in instances
        if(foundInstance != nil) do
          # if there is, then call broadcast for that instance
          log("starting broadcast for new instance")
          {pid, proposals} = foundInstanceProposal
          if state.name == state.leader do
            send(self(), {:broadcast, pid, foundInstance, Enum.at(proposals, 0)})
          end
       #   log("instance, #{inspect(foundInstance)} ")
        #  log("pid is #{inspect(pid)}")
         # log("proposal is #{inspect(Enum.at(proposals, 0))}")
          #%{state | inst: foundInstance, value: Enum.at(proposals, 0)}
        # else
        #   state
        end

        state


       # Enum.at(Map.keys(state.instance), 0)




    end
    run(state)
  end



  # ----------------------------------
  # Application functions
  # ----------------------------------
  def propose(pid, inst, value, t, action \\ nil) do
    # take in pid, inst, value, t
    # value is proposed by each pid

    Process.send_after(self(), {:timeout}, t) # start timeout

    # need to check whether this instance has a decision
    send(pid, {:check_instance, self(), inst, value, action})



    result = receive do
      {:decision, v} ->
        log("Decision #{inspect(v)}")
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
        #log("get_decision got a decision #{inspect(v)}")
          v
      {:timeout} ->
        nil
    end

  end
end
