# w_weathersync

Server-synchronized weather, time of day, dynamic weather transitions, time freeze, and blackout states for **Wraith Framework RedM**.

## Key Features

- Smooth server-wide weather and time synchronization across all connected clients.
- Dynamic weather cycling and configurable transition intervals.
- Time freeze and blackout toggles with full export support (integrated with `w_adminmenu`).

## Installation

1. Place `w_weathersync` in `resources/[wraith]/w_weathersync`.
2. Add `ensure w_weathersync` to `server.cfg` after `w_lib`.

## Key Exports

```lua
exports.w_weathersync:SetWeather('RAIN')
exports.w_weathersync:SetTime(12, 0)
exports.w_weathersync:setDynamicWeather(true)
exports.w_weathersync:setTimeFreeze(false)
exports.w_weathersync:setBlackout(false)
```

## Documentation & Links

- **Developer Docs:** https://wraith-core.github.io/docs/#/resources/interface-world
- **txAdmin Recipe:** https://github.com/Wraith-Core/txAdminRecipe

## License

GPL-3.0 — see [LICENSE](LICENSE).
