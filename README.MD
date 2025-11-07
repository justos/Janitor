## Why use it?

- It's light, fast, and flexible
- It's easy to use
- And it helps you manage and clean up memory

## Installation

1. Using Wally, just [visit](https://wally.run/package/justos/janitor) and copy the latest release and copy it into your Wally.toml

```toml
[dependencies]
Janitor = "justos/janitor@0.6.0"
```

2. Using Github, navigate the [releases](https://github.com/justos/Janitor/releases) tab and download the latest version and copy the "init.lua" file into where you want to use it

## Using it (adding an Instance)

```lua
local Janitor = require(path.to.Janitor)

local janitor = Janitor.new()

local part = janitor:Add(Instance.new("Part"), "Destroy")
part.Parent = workspace

janitor:Cleanup(1) -- Waits one second before cleaning up

-- No more part!
part = nil
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
janitor = nil -- Removes the reference
```
