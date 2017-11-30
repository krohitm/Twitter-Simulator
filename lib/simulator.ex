#module for the separate client node OS process
defmodule Simulator do
  use GenServer
  def start(numClients) do
    nodeFullName = "simulator@127.0.0.1"
    Node.start (String.to_atom(nodeFullName))
    Node.set_cookie :twitter
    #state = :running
    IO.puts "spawning clients"
    #initiate :users table that will hold usernames, userPids, and followers' PIDs
    :ets.new(:usersSimulator, [:set, :public, :named_table])
    actorsPid = spawnClientActors(numClients, [])
  end

  #subscribe users to random users
  #def subscribe(actorsPid) do
  #  Enum.each(actorsPid, fn(clientPid) ->
  #    usersToSub = Enum.take_random(actorsPid--[clientPid], 5)
  #    usernamesToSub = Enum.map(usersToSub, fn(userPids) ->
  #      Simulator.getUsername(userPids)
  #    end)
  #    GenServer.cast(clientPid, {:subscribe, usernamesToSub})
  #  end)
  #end

  def subscribe(actorsPid) do
    usersCount = length(actorsPid)
    mostSubscribers = usersCount-1
    factor = 1
    subscribe(actorsPid, usersCount-1, mostSubscribers, factor)
  end
  def subscribe(_, -1, _, _) do
    true
  end
  def subscribe(actorsPid, index, mostSubscribers, factor) do
    clientPid = Enum.at(actorsPid, index)
    numSubscribers = (mostSubscribers/factor) |> round
    numSubscribers = cond do 
      numSubscribers == 0 ->
        1
      true ->
        numSubscribers
    end
    #IO.inspect ["no. of users subscribed", numSubscribers]
    usersToSub = Enum.take_random(actorsPid--[clientPid], numSubscribers)
    usernamesToSub = Enum.map(usersToSub, fn(userPids) ->
      Simulator.getUsername(userPids)
    end)
    GenServer.cast(clientPid, {:subscribe, usernamesToSub})
    subscribe(actorsPid, index-1, mostSubscribers, factor+1)
  end

  #function to send tweets
  def sendTweet(actorsPid) do
    IO.puts "sending tweets"
    Enum.each(actorsPid, fn(client) ->
      mention = selectRandomMention(actorsPid, client)
                |> Simulator.getUsername
      tweetText = "tweet@"<>mention<>getHashtag()
      #IO.inspect :ets.lookup(:usersSimulator, client)
      userName = Simulator.getUsername(client)
      send client, {:tweet_subscribers, tweetText, userName, client}
      #GenServer.cast(client, {:tweet_subscribers, tweetText, userName})
    end)
  end

  @doc """
  Asks client to get tweets of users subscribed to
  """
  def searchTweets(actorsPid) do
    Enum.each(actorsPid, fn(client) ->
      userName = Simulator.getUsername(client)
      GenServer.cast(client, {:search, userName})
    end)
  end
  
  @doc """
  Asks client to get tweets of users subscribed to at a regular interval
  """
  def searchTweets(actorsPid, :interval) do
    Enum.each(actorsPid, fn(client) ->
      userName = Simulator.getUsername(client)
      send client, {:search, userName, client}
    end)
  end
  
  @doc """
  Asks client to get tweets of random hashtags subscribed to
  """
  def searchHashtags(actorsPid) do
    Enum.each(actorsPid, fn(client) ->
      userName = Simulator.getUsername(client)
      hashtag_list = Simulator.getHashtag()
      GenServer.cast(client, {:search_hashtag, userName, hashtag_list})
    end)
  end

  def searchMentions(actorsPid) do
    Enum.each(actorsPid, fn(client) ->
      userName = Simulator.getUsername(client)
      GenServer.cast(client, {:search_mentions, userName})
    end)
  end

  @doc """
  Returns the username, given a pid
  """
  @spec getUsername(pid) :: String.t
  def getUsername(pid) do
    #IO.inspect pid
    #IO.inspect :ets.lookup(:usersSimulator, pid)
    [{_, userName, _}] = :ets.lookup(:usersSimulator, pid)
    userName
  end

  def selectRandomMention(actorsPid, clientPid) do
    mention = Enum.random(actorsPid)
    cond do
      mention == clientPid ->
        selectRandomMention(actorsPid, clientPid)
      true ->
        mention
    end
  end

  def getHashtag do
      hashList = ["#marketing", "#marketingtips", "#b2cmarketing",
      "#b2bmarketing", "#strategy", "#mktg", "#digitalmarketing",
      "#marketingstrategy", "#mobilemarketing", "#socialmediamarketing",
      "#promotion", "#food", "#yummy", "#nom", "#hungry", "#cleaneating",
      "#vegetarian", "#wine", "#sushi", "#birthday", "#red", "#workout",
      "#sweet",  "#wedding", "#blackandwhite"]
      Enum.random(hashList)
  end

  #function to spawn client actors
  def spawnClientActors(0, actorsPid) do
    actorsPid
  end
  def spawnClientActors(numClients, actorsPid) do
    #state = :spawned
    state = 0
    nodeName = numClients |> Integer.to_string |> String.to_atom
    {:ok, clientPid} = GenServer.start(Client, state, name: nodeName)
    actorsPid = actorsPid ++ [clientPid]
    #:global.register_name(nodeName, clientPid)
    #give username to client and add it to :users table
    userName = :md5
              |> :crypto.hash(Kernel.inspect(clientPid))
              |> Base.encode16()
    #IO.inspect clientPid
    :ets.insert_new(:usersSimulator, {clientPid, userName, []})

    #IO.inspect :ets.lookup(:usersSimulator, clientPid)

    GenServer.call(clientPid, {:register, userName}, :infinity)
    spawnClientActors(numClients-1, actorsPid)
  end
end
