--!optimize 2
--!strict
local Janitor = {}

--[=[
	Janitor is a light, fast, flexible class for cleaning up connections, instances, or really anything.
	This implementation covers all uses.

	@external Signal https://sleitnick.github.io/RbxUtil/api/Signal/

	@class Janitor
]=]
local Metatable = {}
Metatable.__index = Metatable

--[=[
	Whether the Janitor is currently cleaning or not.

	@readonly
	@prop CurrentlyCleaning boolean
	@within Janitor
]=]
Metatable.CurrentlyCleaning = false

local TYPE_DEFAULTS = {
	["function"] = true,
	thread = true,
	RBXScriptConnection = "Disconnect",
}

--stylua: ignore
local INVALID_METHOD_NAME = "Object is a %* and as such expected `true?` for the method name and instead got %*. Traceback: %*"
local METHOD_NOT_FOUND_ERROR = "Object %* doesn't have method %*, are you sure you want to add it? Traceback: %*"

local janitors = setmetatable({}, { __mode = "kv" })

export type Janitor = {
	CurrentlyCleaning: boolean,

	Add: <T>(self: Janitor, object: T, methodName: (boolean | string)?, index: any?) -> T,
	Construct: <T, A...>(
		self: Janitor,
		constructor: { new: (A...) -> T },
		methodName: (boolean | string)?,
		index: any?,
		A...
	) -> T,
	Connect: (self: Janitor, signal: RBXScriptSignal | any, func: (...any) -> ...any, index: any?) -> (),
	LinkToInstance: (self: Janitor, instance: Instance, allowMultiple: boolean?) -> RBXScriptConnection,
	Remove: (self: Janitor, index: any) -> Janitor,
	Get: (self: Janitor, index: any) -> any?,
	Cleanup: (self: Janitor, delaySeconds: number?) -> (),
	Destroy: (self: Janitor) -> (),

	[any]: boolean | string,
}

--[=[
	Constructs a new Janitor object.

	```lua
	local Janitor = require(path.to.Janitor)

	local janitor = Janitor.new()
	```

	@return Janitor
]=]
function Janitor.new(): Janitor
	local self = setmetatable({}, Metatable) :: any
	self.CurrentlyCleaning = false

	return self
end

local function remove(self: Janitor, index: any): Janitor
	local janitor = janitors[self]

	if not janitor then
		return self
	end

	local object, methodName = janitor[index], nil
	if not object then
		return self
	end

	methodName = self[object]

	if not methodName then
		janitor[index] = nil
		return self
	end

	if methodName == true then
		if type(object) == "function" then
			object()
		else
			local wasCancelled = false

			if coroutine.running() ~= object then
				wasCancelled = pcall(function()
					task.cancel(object)
				end)
			end
			if not wasCancelled then
				task.defer(function()
					task.cancel(object)
				end)
			end
		end
	else
		if methodName == "Destroy" then
			local destroy = object.Destroy
			if destroy then
				destroy(object)
			end
		elseif methodName == "Disconnect" then
			local disconnect = object.Disconnect
			if disconnect then
				disconnect(object)
			end
		else
			local objectMethod = (object :: any)[methodName]
			if objectMethod then
				objectMethod(object)
			end
		end
	end

	janitor[index] = nil
	self[object] = nil

	return self
end

--[=[
	Removes and cleans up the object or objects that were added by index.

	```lua
	local Janitor = require(path.to.Janitor)

	local janitor = Janitor.new()

	janitor:Add(workspace.Baseplate, "Destroy", "Baseplate")
	janitor:Add(workspace.SpawnPoint, "Destroy", "SpawnPoint")

	janitor:Remove("Baseplate", "SpawnPoint")
	```

	@tag Remove
	@method Remove
	@within Janitor

	@param self Janitor
	@param ... ...any -- The index or indexes you want to remove.
	@return Janitor
]=]
function Metatable.Remove(self: Janitor, ...: any): Janitor
	for _, v in ... do
		remove(self, v)
	end

	return self
end

--[=[
	Removes the object or objects that were added by index without cleaning them up.

	```lua
	local Janitor = require(path.to.Janitor)

	local janitor = Janitor.new()

	janitor:Add(workspace.Baseplate, "Destroy", "Baseplate")
	janitor:Add(workspace.SpawnPoint, "Destroy", "SpawnPoint")

	janitor:Remove("Baseplate", "SpawnPoint")
	```

	@tag Remove
	@method RemoveNoClean
	@within Janitor

	@param self Janitor
	@param ... ...any -- The index or indexes you want to remove.
	@return Janitor
]=]
function Metatable.RemoveNoClean(self: Janitor, ...: any): Janitor
	local janitor = janitors[self]
	if not janitor then
		return self
	end

	for _, v in ... do
		self[v] = nil
		janitor[v] = nil
	end

	return self
end

--[=[
	Adds an object or thread to the Janitor to be later cleaned up or removed.
	
	:::info Note
	If you don't pass a `methodName` when adding an object to the Janitor,
	it will try to assume what method would work best for cleanup.

	RBXScriptSignals use the `Disconnect` method, threads will close themselves, functions will be called.
	And everything else defaults to the `Destroy` method.
	:::
	
	```lua
	local TweenService = game:GetService("TweenService")
	
	local Janitor = require(path.to.Janitor)

	local janitor = Janitor.new()
	
	-- Queue the Part to be Destroyed at cleanup
	local part = janitor:Add(Instance.new("Part"), "Destroy")
	part.Parent = workspace
	
	-- Queue a function to be called at cleanup
	janitor:Add(function()
		print("Cleaning up!")
	end)

	-- Queue a thread to be canceled or closed at cleanup
	janitor:Add(task.defer(function()
		while task.wait() do
			print("Doing something..")
		end
	end))

	-- Janitor allows you specify custom destruction behavior for any object
	local position = vector.create(0, 100, 0)

	janitor:Add(TweenService:Create(part, TweenInfo.new(1), {Position = position}), "Cancel")

	position = nil
	```

	@tag Add
	@method Add
	@within Janitor

	@param self Janitor
	@param object T -- The object you want to clean up.
	@param methodName (boolean | string)? -- The name of the method that will be used to clean up. If not passed, it will first check if the object's type exists in TypeDefaults, and if that doesn't exist, it assumes `Destroy`.
	@param index any? -- The index that can be used to clean up the object manually.
	@return T -- The object that was passed as the first argument.
]=]
local function add<T>(self: Janitor, object: T, methodName: (boolean | string)?, index: any?): T
	local typeOf = typeof(object)
	local newMethodName = methodName or TYPE_DEFAULTS[typeOf] or "Destroy"

	if index then
		remove(self, index)

		local janitor = janitors[self]
		if not janitor then
			janitor = {}
			janitors[self] = janitor
		end

		janitor[index] = object
	end

	if typeOf == "function" or typeOf == "thread" then
		if newMethodName ~= true then
			warn(string.format(INVALID_METHOD_NAME, typeOf, tostring(newMethodName), debug.traceback(nil, 2)))
		end
	else
		if not (object :: any)[newMethodName] then
			warn(
				string.format(
					METHOD_NOT_FOUND_ERROR,
					tostring(object),
					tostring(newMethodName),
					debug.traceback(nil, 2)
				)
			)
		end
	end

	self[object] = newMethodName
	return object
end

Metatable.Add = add

--[=[
	Returns the object that occupies the index passed.

	```lua
	local Janitor = require(path.to.Janitor)

	local janitor = Janitor.new()
	
	janitor:Add(Instance.new("Part"), "Destroy", "OurPart")

	-- Returns janitor["OurPart"]
	local part = janitor:Get("OurPart")
	part.Parent = workspace
	```

	@method Get
	@within Janitor

	@param self Janitor
	@param index any -- The index that the object is stored under.
	@return any? -- This will return the object if it is found, but it won't return anything if it doesn't exist.
  ]=]
local function get(self: Janitor, index: any): any?
	local janitor = janitors[self]
	return janitor and janitor[index] or nil
end

Metatable.Get = get

--[=[
	Calls each object's destroy method (`methodName`) and removes them from the Janitor.

	```lua
	local Janitor = require(path.to.Janitor)

	local janitor = Janitor.new()

	-- Instant cleanup
	janitor:Cleanup()

	-- Delayed cleanup
	janitor:Cleanup(5)
	```
	
	@tag Remove
	@method Cleanup
	@within Janitor
	
	@param self Janitor
	@param delaySeconds number? -- If included, the Janitor will wait that amount of seconds before cleaning up.
]=]
local function cleanup(self: Janitor, delaySeconds: number?)
	if delaySeconds then
		task.wait(delaySeconds)
	end

	self.CurrentlyCleaning = nil :: any

	local object, methodName = next(self)

	while object and methodName do
		if methodName == true then
			if type(object) == "function" then
				object()
			else
				local wasCancelled = false

				if coroutine.running() ~= object then
					wasCancelled = pcall(function()
						task.cancel(object)
					end)
				end
				if not wasCancelled then
					task.defer(function()
						task.cancel(object)
					end)
				end
			end
		else
			if methodName == "Destroy" then
				local destroy = object.Destroy
				if destroy then
					destroy(object)
				end
			elseif methodName == "Disconnect" then
				local disconnect = object.Disconnect
				if disconnect then
					disconnect(object)
				end
			else
				local objectMethod = (object :: any)[methodName]
				if objectMethod then
					objectMethod(object)
				end
			end
		end

		self[object] = nil
		object, methodName = next(self, object)
	end

	local janitor = janitors[self]
	if janitor then
		table.clear(janitor)
		janitors[self] = nil
	end

	self.CurrentlyCleaning = false
end

Metatable.Cleanup = cleanup

--[=[
	Connects a signal and adds it to the Janitor.
	Shorthand for `janitor:Add(Signal:Connect(func), methodName, index)`
	
	```lua
	-- Using a signal module
	local Janitor = require(path.to.Janitor)
	local Signal = require(path.to.Signal)

	local janitor = Janitor.new()

	local signal = janitor:Construct(Signal, "Destroy")

	local connection = Janitor:Connect(signal, function(...: any)
		print(...)
	end)

	signal:Fire(3.14, 6.28)
	```

	```lua
	-- Using a RBXScriptSignal
	local Players = game:GetService("Players")

	local Janitor = require(path.to.Janitor)

	local janitor = Janitor.new()

	janitor:Connect(Players.PlayerAdded, function(player: Player)
		print(player)
	end, "PlayerJoinedSignal")
	```

	@tag Add
	@method Connect
	@within Janitor

	@param self Janitor
	@param signal RBXScriptSignal | Signal -- The signal you want to connect to.
	@param func (...any) -> ...any -- The callback to the connection.
]=]
function Metatable.Connect(self: Janitor, signal: any, func: (...any) -> ...any, index: any?)
	add(self, signal:Connect(func), "Disconnect", index)
end

--[=[
	Constructs a class and adds it to the Janitor.
	Shorthand for `janitor:Add(Class.new(), methodName, index)`

	```lua
	local Janitor = require(path.to.Janitor)
	local Signal = require(path.to.Signal)

	local janitor = Janitor.new()

	local signal = janitor:Construct(Signal, "Destroy")

	signal:Connect(function(...: any)
	    print(...)
	end)

	signal:Fire(3.14, 6.28)
	```

	@tag Add
	@method Construct
	@within Janitor

	@param self Janitor
	@param constructor {new: (A...) -> T} -- The constructor for the object you want to add to the Janitor.
	@param methodName boolean | string? -- The name of the method that will be used to clean up. If not passed, it will first check if the object's type exists in TypeDefaults, and if that doesn't exist, it assumes `Destroy`.
	@param index any? -- The index that can be used to clean up the object manually.
	@param ... A... -- The arguments that will be passed to the constructor.
	@return T -- The object that was passed as the first argument.
]=]
function Metatable.Construct<T, A...>(
	self: Janitor,
	constructor: { new: (A...) -> T },
	methodName: (boolean | string)?,
	index: any?,
	...: A...
): T
	return add(self, constructor.new(...), methodName, index)
end

--[=[
	Listens to the Instance's provided .Destroying signal and when it is fired the Janitor destroy's itself.

	```lua
	local Janitor = require(path.to.Janitor)

	local part = workspace.Part

	local janitor = Janitor.new()
	janitor:LinkToInstance(part)

	part:Destroy() -- + janitor:Destroy()
	```

	@method LinkToInstance
	@within Janitor

	@param self Janitor
	@param instance Instance -- The instance you want to link.
	@param allowMultiple boolean? -- If you want to allow the Janitor object to be linked to multiple instances at once.
	@return RBXScriptConnection -- The connection for the instance.Destroying event.
]=]
function Metatable.LinkToInstance(self: Janitor, instance: Instance, allowMultiple: boolean?): RBXScriptConnection
	local index = nil
	if not allowMultiple then
		index = "__LinkToInstance"
	else
		index = instance :: any
	end

	--stylua: ignore
	return add(self, instance.Destroying:Connect(function()
		cleanup(self)
	end), "Disconnect", index)
end

--[=[
	:::danger Object Destruction
	Destroying your Janitor object also removes it from the Janitor metatable which means you can't use any
	Janitor methods. So only call this if you don't plan on using the object anymore. If you do plan on using it still
	call [:Cleanup()](#Cleanup) instead.

	```lua
	local Janitor = require(path.to.Janitor)

	local janitor = Janitor.new()

	-- How to properly cleanup
	janitor:Destroy()
	janitor = nil -- Remove the reference

	-- Will error after calling :Destroy()
	local part = janitor:Add(Instance.new("Part"), "Destroy")
	```
	:::
	
	```lua
	local Janitor = require(path.to.Janitor)
	local Signal = require(path.to.Signal)
	
	local janitor = Janitor.new()

	local signal = janitor:Construct(Signal, "Destroy", "OurSignal")

	signal:Connect(function(...: any)
	    print(...)
	end)

	signal:Fire(3.14, 6.28)

	janitor:Destroy()
	janitor = nil
	signal = nil
	```

	@tag Remove
	@method Destroy
	@within Janitor

	@param self Janitor
]=]
function Metatable.Destroy(self: any)
	cleanup(self)
	table.clear(self)
	setmetatable(self, nil)
end

return Janitor
