# ----------------------------------------
# Utils
# ----------------------------------------

defmodule Utils do
  def unicast(p, m) do
    case :global.whereis_name(p) do
            pid when is_pid(pid) -> send(pid, m)
            :undefined -> :ok
    end
  end

  # Best-effort broadcast of m to the set of destinations dest
  def beb_broadcast(dest, m), do: for p <- dest, do: unicast(p, m)

  def add_to_name(name, to_add), do: String.to_atom(Atom.to_string(name) <> to_add)

  def register_name(name, pid, link \\ true) do # \\ is default value
    case :global.re_register_name(name, pid) do
      :yes ->
        # Note this is running on the parent so we are linking the parent to the rb
        # so that when we close the parent the rb also dies
        if link do
          Process.link(pid)
        end

        pid

      :no ->
        Process.exit(pid, :kill)
        :error
    end
  end

  # ----------------------------------------------
  # functions for comparing ballot and process id
  # ----------------------------------------------
  def compare_ballot(left, operator, right) do
    operator.(ballot_compare(left, right),0)
  end

  defp ballot_compare(a, b) do
    diff = elem(a, 0) - elem(b, 0)
    if diff == 0, do: lexicographical_compare(elem(a, 1), elem(b, 1)), else: diff
  end

  def lexicographical_compare(a, b) do
    if a == b do
      0
    end

    if a>b do
      1
    end

    if a<b do
      -1
    end


  end

  def increment_ballot_number(ballot_tuple, leader) do
    {elem(ballot_tuple,0)+1, leader}

  end

  # # Converts a ballot reference to the raw ballot index.
  # defp ballot_ref_to_index(ballot) do
  #   elem(ballot, 1)
  # end

end
