defmodule Paxos do

  def start(name, participants) do
    # do spawn stuff
  end



  def init() do
    # create state
    state = %{
      name: name,
    }

    run(state)
  end



  def run(state)
    # run stuff
  end


  def propose(pid, inst, value, t) do
    # do paxos stuff



    if state.timedout do
      {:timeout}
    else
      if state.aborted do
        {:abort}
      else
        {:decide, state.decided}
    end
  end


  
  def get_decision(pid, inst, t) do

  end
end
