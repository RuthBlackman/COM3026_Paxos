defmodule EventualLeaderDetector do

  def start(name, participants) do
    # edit name to include leader_election - means it won't get mixed up with other processes
    new_name = Utils.add_to_name(name, "leader_election");

    # in participants, change all the names and then save to particpants
    participants = Enum.map(participants, fn x -> Utils.add_to_name(x, "leader_election") end);

    # spawn leader election
    pid = spawn(EventualLeaderDetector, :init, [new_name, participants, name]);

    # register name
    Utils.register_name(new_name, pid);

  end



  def init(name, participants, parent_name) do
    state = %{
      name: name,
      participants: participants,
      parent_name: parent_name, # process that owns leader elector
      leader: nil,
      timeout: 1000,
      alive: %MapSet{},
    }

    Process.send_after(self(), {:timeout}, state.timeout) # start timeout

    run(state)
  end



  def run(state) do

    state = receive do
      {:timeout} ->
        # send heartbeat request to all processes
        Utils.beb_broadcast(state.participants, {:heartbeat_request, self()})

        # start restart timeout if timeout is reached
        Process.send_after(self(), {:timeout}, state.timeout)

        # elect leader from alive
        state = elect_leader(state)

        # clear alive - this is so that a process that has crashed is not stuck in alive
        %{state | alive: %MapSet{}}

      {:heartbeat_request, pid} ->
        # send heartbeat
        send(pid, {:heartbeat_reply, state.parent_name})

        state

      {:heartbeat_reply, name} ->
        #receive heartbeat reply and add process to alive
        %{state | alive: MapSet.put(state.alive, name)}


    end
    run(state)
  end


  def elect_leader(state) do
    # order alive from smallest to largest pid
    sorted_processes = Enum.sort(state.alive) # returns a list of the sorted processes

    # check if there are any processes are alive
    if(MapSet.size(state.alive) > 0) do
      first_process = Enum.at(sorted_processes, 0)

      # if process is not already leader, then make it leader
      if(first_process != state.leader) do
        Utils.unicast(state.parent_name, {:leader_elect, first_process})
        %{state | leader: first_process}
      # if process is already leader, then don't change the state
      else
        state
      end
    else
      state
    end
  end
end
