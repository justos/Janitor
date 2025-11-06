Janitor is a light, fast, flexible class for cleaning up connections, instances, or really anything.
This implementation covers all uses. You may specify any destruction behavior for any object.

## Using it (a simple example)

```lua
local Janitor = require(path.to.Janitor)

local janitor = Janitor.new()

local part = janitor:Add(Instance.new("Part"), "Destroy")
part.Parent = workspace

janitor:Cleanup(1) -- Wait one second before cleaning up.

-- No more part!
```
