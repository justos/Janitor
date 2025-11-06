Janitor is a light, fast, flexible class for cleaning up connections, instances, or really anything.
This implementation covers all uses. You may specify any destruction behavior for any object.

## Using it (adding an Instance)

```lua
local Janitor = require(path.to.Janitor)

local janitor = Janitor.new()

local part = janitor:Add(Instance.new("Part"), "Destroy")
part.Parent = workspace

janitor:Cleanup(1) -- Wait one second before cleaning up

-- No more part!
```

## Using it (adding a Connection or Signal)

```lua
local Players = game:GetService("Players")

local Janitor = require(path.to.Janitor)
local Signal = require(path.to.Signal)

local janitor = Janitor.new()
local signal = janitor:Construct(signal, "DisconnectAll")

janitor:Connect(signal, function(...: any)
    print(...)
end)

signal:Fire(3.14, 6.28)

janitor:Connect(Players.PlayerJoined, function(player: Player)
    print(player)
end)

janitor:Cleanup(1) -- Disconnects all of the Signal events and Disconnects the Players.PlayerAdded event
```

## Using it (Properly destroying it)

```lua
local Janitor = require(path.to.Janitor)

local janitor = Janitor.new()

janitor:Destroy()
janitor = nil -- Removing the reference
```
