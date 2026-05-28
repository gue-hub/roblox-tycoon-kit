# TycoonKit

A modular Roblox tycoon framework. Build your plot in Studio with simple naming conventions; `TycoonKit` wires up purchases, droppers, coin collection, and player-plot assignment.

```lua
local TycoonKit = require(ServerStorage.TycoonKit)

local tycoon = TycoonKit.new()

tycoon.PurchaseMade:Connect(function(player, buttonName, cashLeft)
    print(player.Name, "bought", buttonName)
end)

tycoon.CoinCollected:Connect(function(player, value)
    -- award XP, run a sound, etc.
end)
```

## Why

Tycoons are the single most-commissioned Roblox genre — and they're full of subtle pitfalls. Coins that escape the plot, droppers that run after the owner left, buttons that double-purchase on a stuttery client, two players claiming the same plot on join. TycoonKit handles each of those once, so you can spend the commission on game design instead of plumbing.

Everything is **server-authoritative**: purchases are validated server-side, cash lives on the server, the client cannot fake a touch.

## Install

### Wally

```toml
[dependencies]
TycoonKit = "rumin/tycoon-kit@1.0.0"
```

### Manual

Drop `src/` into `ServerStorage`, rename it to `TycoonKit`. The `default.project.json` mounts it as a `ModuleScript` if you use Rojo.

## Studio setup

Build this hierarchy under `workspace`:

```
workspace.Plots/
  Plot1/                          (Model)
    Spawn                         (SpawnLocation)
    Collector                     (BasePart — coins fly into this)
    Buttons/                      (Folder)
      UnlockOven/                 (Model with at least one BasePart)
        @Price     = 50
        @Requires  = ""           (optional; name of prerequisite button)
      UnlockGrill/
        @Price     = 250
        @Requires  = "UnlockOven"
    Items/                        (Folder)
      UnlockOven/                 (Model — name matches a button name)
        ... your oven parts ...
      UnlockGrill/
        ...
    Droppers/                     (Folder)
      OvenDropper/                (Model)
        DropSpawn                 (BasePart — coins spawn here)
        @DropRate  = 0.5          (drops per second)
        @DropValue = 1            (cash per coin)
        @Button    = "UnlockOven" (dropper activates after this button is purchased)
  Plot2/ ...
```

`@Foo` denotes an instance attribute. Items and buttons start hidden; they appear when their owning button is purchased / their `Requires` chain is satisfied.

## API

### `TycoonKit.new(options?) -> Tycoon`

| option | default | meaning |
| --- | --- | --- |
| `plotsFolder` | `workspace.Plots` | Where the plot models live. |

### Events

| signal | fires | args |
| --- | --- | --- |
| `PurchaseMade`  | After a successful purchase. | `(player, buttonName, cashLeft)` |
| `CoinCollected` | When a coin touches the collector. | `(player, value)` |
| `PlotAssigned`  | When a player claims a plot. | `(player, plotModel)` |
| `PlotReleased`  | When a player leaves and their plot is reset. | `(player, plotModel)` |

### Methods

```lua
tycoon:GetPlot(player)        --> Plot?
tycoon:GetCash(player)        --> number
tycoon:AddCash(player, n)     --> ()
tycoon:GetPurchases(player)   --> { string }     -- button names already bought
tycoon:RestorePurchases(player, { "UnlockOven", ... })
```

`RestorePurchases` is meant to be called once, right after assignment, when loading a returning player's progress.

## Persistence

TycoonKit has no built-in saves — but it pairs neatly with [`rumin/datastore-safe`](https://github.com/gue-hub/roblox-datastore-safe):

```lua
tycoon.PlotAssigned:Connect(function(player, plotModel)
    local profile = store:Load(player.UserId)
    if profile then
        tycoon:RestorePurchases(player, profile.data.purchases or {})
        tycoon:AddCash(player, profile.data.cash or 0)
    end
end)

tycoon.PurchaseMade:Connect(function(player)
    local profile = store:Get(player.UserId)
    if profile then
        profile.data.purchases = tycoon:GetPurchases(player)
        profile.data.cash = tycoon:GetCash(player)
    end
end)
```

## Behaviour notes

- **Spawning.** Claim sets `Player.RespawnLocation` to the plot's `Spawn` and pivots the current character there. Make sure `Spawn.Neutral = true` and `AllowTeamChangeOnTouch = false` unless you're doing team-based plot assignment.
- **Coin cleanup.** Coins self-destruct after 30 seconds if they don't make it to the collector. On `Release` every live coin is destroyed immediately.
- **Idempotent touch wiring.** Button `Touched` connections are created at most once per button per server (tagged via `_TouchWired` attribute), so re-claiming a plot does not stack listeners.
- **Hidden items.** Inactive buttons and items live in `ServerStorage._TycoonHidden/<plotName>` while not in play. They re-parent to the plot when activated.

## License

MIT — see [LICENSE](LICENSE).
