--[[
	TycoonKit — a modular Roblox tycoon framework.

	Workspace convention
	--------------------
		workspace.Plots/
			Plot1/                       (Model)
				Spawn                    (SpawnLocation — player TPs here on claim)
				Collector                (BasePart — coins fly into this)
				Buttons/                 (Folder)
					<Name>/              (Model with a BasePart inside)
						attribute Price    : number
						attribute Requires : string?  (name of another button)
				Items/                   (Folder)
					<Name>/              (Model — name matches a Button name;
					                      hidden until that button is purchased)
				Droppers/                (Folder)
					<Name>/              (Model)
						DropSpawn        (BasePart — coins spawn here)
						attribute DropRate  : number (drops per second)
						attribute DropValue : number (cash per coin)
						attribute Button    : string  (button name that owns it)
			Plot2/ ...

	Usage
	-----
		local TycoonKit = require(ServerStorage.TycoonKit)
		local tycoon = TycoonKit.new()

		tycoon.PurchaseMade:Connect(function(player, buttonName, cashLeft)
			print(player.Name, "bought", buttonName, "/ remaining:", cashLeft)
		end)

		tycoon.CoinCollected:Connect(function(player, value)
			-- give XP, run VFX, etc.
		end)

		-- Inspect / mutate manually:
		tycoon:AddCash(somePlayer, 500)
		print(tycoon:GetCash(somePlayer))
--]]

local Players = game:GetService("Players")

local Plot = require(script:WaitForChild("Plot"))

--------------------------------------------------------------------------------
-- Minimal Signal (inlined to keep the package dependency-free).
--------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	table.insert(self._handlers, fn)
	return {
		Disconnect = function()
			for i, handler in ipairs(self._handlers) do
				if handler == fn then
					table.remove(self._handlers, i)
					return
				end
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in ipairs(self._handlers) do
		task.spawn(handler, ...)
	end
end

--------------------------------------------------------------------------------
-- TycoonKit
--------------------------------------------------------------------------------

local TycoonKit = {}
TycoonKit.__index = TycoonKit

function TycoonKit.new(options)
	options = options or {}
	local plotsFolder = options.plotsFolder or workspace:WaitForChild("Plots")

	local self = setmetatable({
		_plotsFolder = plotsFolder,
		_plots = {},      -- list of Plot, in folder order
		_ownedBy = {},    -- [Player] = Plot

		PurchaseMade = Signal.new(),    -- (player, buttonName, cashLeft)
		CoinCollected = Signal.new(),   -- (player, value)
		PlotAssigned = Signal.new(),    -- (player, plotModel)
		PlotReleased = Signal.new(),    -- (player, plotModel)
	}, TycoonKit)

	-- Construct a Plot wrapper for every Model under the plots folder.
	for _, model in ipairs(plotsFolder:GetChildren()) do
		if model:IsA("Model") then
			table.insert(self._plots, Plot.new(self, model))
		end
	end

	-- Assign existing players first (handles hot-reload during testing), then listen.
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_assignPlot(player)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		self:_assignPlot(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_releasePlot(player)
	end)

	return self
end

function TycoonKit:_assignPlot(player)
	if self._ownedBy[player] then
		return
	end
	for _, plot in ipairs(self._plots) do
		if not plot.Owner then
			plot:Claim(player)
			self._ownedBy[player] = plot
			self.PlotAssigned:Fire(player, plot.Model)
			return
		end
	end
	warn(("[TycoonKit] No free plot for %s"):format(player.Name))
end

function TycoonKit:_releasePlot(player)
	local plot = self._ownedBy[player]
	if not plot then
		return
	end
	plot:Release()
	self._ownedBy[player] = nil
	self.PlotReleased:Fire(player, plot.Model)
end

function TycoonKit:GetPlot(player)
	return self._ownedBy[player]
end

function TycoonKit:GetCash(player)
	local plot = self._ownedBy[player]
	return plot and plot:GetCash() or 0
end

function TycoonKit:AddCash(player, amount)
	local plot = self._ownedBy[player]
	if plot then
		plot:AddCash(amount)
	end
end

function TycoonKit:GetPurchases(player)
	local plot = self._ownedBy[player]
	return plot and plot:GetPurchases() or {}
end

-- Restore a player's progress (call after Load via DataStoreSafe etc).
function TycoonKit:RestorePurchases(player, buttonNames)
	local plot = self._ownedBy[player]
	if plot then
		plot:RestorePurchases(buttonNames)
	end
end

return TycoonKit
