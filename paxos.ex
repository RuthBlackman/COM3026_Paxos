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

  def init() do
    # create state
    state = %{
      name: name,
      participants: participants,
    }

    run(state)
  end

  def run(state) do
    # run stuff
  end

  def propose(pid, inst, value, t) do
    # do paxos stuff

    # take in pid, inst, value, t
    # value is proposed by each pid

    # {decide, v} - returned if v has been decided for the inst.
    # {abort} - returned if attempt was interrupted by another proposal with a higher ballot. Can choose to reissue the proposal with the higher ballot.
    # {timeout} - returned if the attempt was not able to be decided or aborted within the timeout speicified by t. I.e. pid has crashed


    if state.timedout do
      {:timeout}
    else
      if state.aborted do
        {:abort}
      else
        {:decide, state.decided}
      end
    end
  end

  def get_decision(pid, inst, t) do
    # takes in pid, inst, t
    # returns v != nil if v has been decided for the inst
    # returns nil if v has not been decided for the inst
  end

end