# Minimap Manager (FiveM Resource)

This FiveM resource is designed to provide an **extended minimap for the Roxwood mapping project**. It allows you to display custom map textures (tiles) on the game's minimap and pause menu map, effectively creating custom map areas or overlays. This resource will be updated as the Roxwood map expands with various versions to suit server needs.

If you are using Roxwood but have created a different version of the map textures, please feel free to contribute and share it for all to use!

---

## Current Versions:

> **DLK HD Atlas Map (no postal)**
> ![DLK HD Atlas Map (no postal)](https://github.com/Manliketjb/ExtraMapTiles/assets/82594996/122b98fe-0f9a-44af-8190-5bf27e886b68)

---

> **DLK HD Atlas Map (postal)**
> ![DLK HD Atlas Map (postal)](https://github.com/Manliketjb/ExtraMapTiles/assets/82594996/d019144e-5fb4-466a-9f30-80df9ac06108)
> [Add Postal Json To Your Postal System](https://github.com/Manliketjb/ExtraMapTiles/blob/main/%5Btextures%5D/DLK%20HD%20Atlas%20Map%20(postal)/roxwood.MD)

---

## Original Resource Post and How To:

> **Original Release Thread:** [https://forum.cfx.re/t/release-extra-map-tiles-add-extra-map-and-minimap-texture-tiles/5179464](https://forum.cfx.re/t/release-extra-map-tiles-add-extra-map-and-minimap-texture-tiles/5179464)

---

## Edited for [Roxwood](https://ambitioneers.tebex.io/)

---

## Table of Contents

* [Features](#features)
* [Installation](#installation)
* [Configuration](#configuration)
* [Usage](#usage)
    * [Exported Functions (Client-Side)](#exported-functions-client-side)
    * [Examples](#examples)
* [Debugging](#debugging)
* [Adding Custom Map Tiles](#adding-custom-map-tiles)
* [Known Issues / Troubleshooting](#known-issues--troubleshooting)
* [Credits](#credits)
* [License](#license)

---

## Features

* **Custom Map Overlays:** Display your own `.ytd` (texture dictionary) map tiles directly on the minimap.
* **Toggleable Debugging:** Enable verbose console logs to troubleshoot issues with map tile loading and display.
* **Dynamic Tile Management:** Add or remove individual map tiles at runtime.
* **Automatic Map Bounds Extension:** Adjusts the pause menu map view to encompass your custom map area (uses invisible blips).
* **Optimized Loading:** Requests and sets texture dictionaries as no longer needed efficiently.
* **Blip Visibility Fix:** Includes a default transparency setting for custom map tiles to prevent them from completely obscuring regular blips.

---

## Installation

1.  **Download the Resource:** Get the `minimap_manager` resource files.
2.  **Place in `resources` folder:** Put the `minimap_manager` folder into your FiveM server's `resources` directory.
    ```
    fivem-server/
    ├── resources/
    │   ├── minimap_manager/
    │   │   ├── fxmanifest.lua
    │   │   ├── client.lua
    │   │   └── MINIMAP_LOADER.gfx  (or other .gfx files you might use)
    │   │   └── <your_map_textures>.ytd (e.g., roxwood.ytd)
    ```
3.  **Ensure `MINIMAP_LOADER.gfx` is present:** This file is crucial for the Scaleform overlay. It usually comes with map resources. If you have your own, make sure its path is correctly configured in `client.lua` (see `MinimapManager.loadOverlay`).
4.  **Add to `server.cfg`:** Add `ensure minimap_manager` (or `start minimap_manager`) to your server's `server.cfg` file.

    ```cfg
    ensure minimap_manager
    ```

---

* **`MinimapConfig.ExtraTiles`**: This is the core configuration for your map.
    * Each entry is a Lua table defining a single map tile.
    * **`Key`** (e.g., `[1]`, `[2]`): A unique identifier for the tile. Can be a number or string.
    * **`xOffset`, `yOffset`**: (Recommended) These define the tile's position in a grid relative to the map's origin. `0,0` is the first tile, `0,1` is the tile directly below it (increasing Y-offset moves south on the map), `1,0` is to the right of the first tile (increasing X-offset moves east). This is useful for grid-based custom maps.
    * **`x`, `y`**: (Alternative) You can specify exact world coordinates for the tile's center if `xOffset`/`yOffset` aren't suitable. If both are provided, `xOffset`/`yOffset` take precedence.
    * **`txd` (Texture Dictionary)**: The name of the `.ytd` file where your map texture is located (e.g., `roxwood`). This `.ytd` file must be streamed by your resource or another.
    * **`txn` (Texture Name)**: The specific name of the texture within the `txd` to use for this tile (e.g., `minimap_0_0`).
    * **`alpha`** (Optional): Overrides `DefaultAlpha` for a specific tile (0-255).
    * **`centered`** (Optional): Boolean, defaults to `false`. If `true`, the `x` and `y` coordinates (or offsets) are treated as the center of the texture rather than the top-left corner.
    * **`rotation`** (Optional): Number, defaults to `0.0`. Rotates the texture in degrees.
* **`MinimapConfig.DefaultAlpha`**: Controls the default transparency of all your custom map tiles. A lower value makes them more transparent, allowing standard blips to be seen through them.
* **`DEBUG_MODE`**: Set to `true` to enable detailed debug messages in your server console. Set to `false` to disable for a cleaner console.

---

## Usage

This resource provides several client-side exports that you can call from other scripts.

### Exported Functions (Client-Side)

You can call these functions from any other client-side script using `exports['minimap_manager']:FunctionName(...)`.

* **`exports['minimap_manager']:createAllTiles()`**
    * Draws all map tiles defined in `MinimapConfig.ExtraTiles`. This is called automatically on resource start.
    * It will also extend the pause menu map bounds if no dummy blips exist.

* **`exports['minimap_manager']:deleteAllTiles()`**
    * Removes all currently drawn custom map tiles from the minimap.
    * Resets the pause menu map bounds if they were extended by this resource.

* **`exports['minimap_manager']:createTile(tileKey)`**
    * Draws a single map tile specified by its `tileKey` (the key used in `MinimapConfig.ExtraTiles`).
    * `tileKey`: (any) The unique identifier of the tile (e.g., `1`, `"my_tile_id"`).

* **`exports['minimap_manager']:deleteTile(tileKey)`**
    * Removes a single drawn map tile specified by its `tileKey`.
    * `tileKey`: (any) The unique identifier of the tile.

* **`exports['minimap_manager']:extendPauseMenuMapBounds()`**
    * Manually extends the bounds of the pause menu map to encompass all currently *drawn* custom tiles. This is done automatically when `createAllTiles` is called, but can be useful if you dynamically add tiles and need the map view to update.

* **`exports['minimap_manager']:resetPauseMenuMapBounds()`**
    * Resets the pause menu map bounds to their default GTA V size by removing the invisible dummy blips used for extension.

* **`exports['minimap_manager']:isTileDrawn(tileKey)`**
    * Checks if a specific tile is currently drawn on the minimap.
    * `tileKey`: (any) The unique identifier of the tile.
    * Returns: `boolean` (`true` if drawn, `false` otherwise).

### Examples

**Example: Adding a new tile dynamically (from another client script)**

```lua
    -- In another_script/client.lua

    -- Let's say you added a new tile definition in minimap_manager/client.lua like this:
    -- MinimapConfig.ExtraTiles = {
    --     [1] = {xOffset = 0, yOffset = 0, txd = "roxwood", txn = "minimap_0_0"},
    --     ["secret_bunker_tile"] = {x = 500.0, y = 1000.0, txd = "bunker_txd", txn = "bunker_map"},
    -- }

    Citizen.CreateThread(function()
        -- Wait for minimap_manager to load
        while not exports['minimap_manager'] do
            Citizen.Wait(100)
        end
        print("minimap_manager exports are available.")

        -- Example: Draw a specific tile when a player enters a certain area
        local function checkArea()
            local playerCoords = GetEntityCoords(PlayerPedId())
            if #(playerCoords - vector3(500.0, 1000.0, 0.0)) < 50.0 then -- If player is near the bunker coords
                if not exports['minimap_manager']:isTileDrawn("secret_bunker_tile") then
                    exports['minimap_manager']:createTile("secret_bunker_tile")
                    print("Custom bunker map tile displayed!")
                    -- Optionally, re-extend bounds if you add tiles frequently
                    exports['minimap_manager']:extendPauseMenuMapBounds()
                end
            else
                if exports['minimap_manager']:isTileDrawn("secret_bunker_tile") then
                    exports['minimap_manager']:deleteTile("secret_bunker_tile")
                    print("Custom bunker map tile removed.")
                    exports['minimap_manager']:resetPauseMenuMapBounds()
                end
            end
        end

        while true do
            Citizen.Wait(1000) -- Check every second
            checkArea()
        end
    end)
```
```lua
    -- In another_script/client.lua
    -- On a command, for instance
    RegisterCommand("hidemap", function()
        exports['minimap_manager']:deleteAllTiles()
        print("All custom map tiles hidden.")
    end, false)

    RegisterCommand("showmap", function()
        exports['minimap_manager']:createAllTiles()
        print("All custom map tiles shown.")
    end, false)
```

---

## Debugging

To troubleshoot issues, set **`DEBUG_MODE = true`** at the top of `client.lua`.

When debug mode is active, the server console will show verbose messages prefixed with `[MinimapManager DEBUG]`. These messages track:

* Resource loading status.

* Texture dictionary requests and loading.

* Map tile creation and deletion processes.

* The exact values and Lua types of variables (like `xTexture`, `yTexture`, `xScale`, `yScale`) during calculations, which is critical for diagnosing type mismatch errors.

* Map bounds extension and reset operations.

**If you encounter `vector3 cannot match number` errors, pay close attention to the `DEBUG:` prints related to `GetTextureResolution` and the subsequent `xTexture`, `yTexture` extractions. This will show you exactly what data `GetTextureResolution` is returning in your environment.**

---

## Adding Custom Map Tiles

1.  **Create your map textures:** Design your custom map sections. Each section will be a PNG image.

2.  **Convert to `.ytd`:** Use a tool like OpenIV to create a `.ytd` (texture dictionary) file. Import your PNG images into this `.ytd` file. Give each image a unique texture name (e.g., `minimap_custom_0_0`).

3.  **Stream your `.ytd`:** Place your `.ytd` file (e.g., `my_custom_map.ytd`) inside your `minimap_manager` resource folder, or another resource that is streamed on your server.

4.  **Update `fxmanifest.lua`:** Ensure your `.ytd` file is listed in the `fxmanifest.lua` to be streamed:

    ```lua
    -- fxmanifest.lua
    client_scripts {
        'client.lua'
    }
    files {
        'MINIMAP_LOADER.gfx',
        'my_custom_map.ytd' -- Add your YTD here
    }
    data_files {
        'MAP_EXTENSIONS' -- If you have custom map extensions, otherwise remove
    }
    ```

5.  **Configure `MinimapConfig.ExtraTiles`:** Add an entry for each of your new tiles in `client.lua` using the `txd` (your `.ytd` file name) and `txn` (the texture name inside the `.ytd`) you defined. Use `xOffset` and `yOffset` to place them correctly in relation to each other, or `x` and `y` for absolute placement.

    > **Editing Textures:**
    >
    > * Open `roxwood.ytd` in [OpenIV](https://openiv.com) and replace the textures with the one that is provided in the `[textures]` Folder (from the original ExtraMapTiles GitHub repository) or replace with your own!
    >
    > * A `.pdn` file for a template and sizing has been [Provided](https://github.com/Manliketjb/ExtraMapTiles/blob/main/%5Btextures%5D/roxwood-example.pdn).
    >
    > * Feel free to edit and customise to your own, BUT you will need: [Paint.net](https://www.dotpdn.com/downloads/pdn.html).

---

## Known Issues / Troubleshooting

* **Blips obscured by map:** The `DefaultAlpha` setting is designed to mitigate this. Adjust its value in `MinimapConfig` (e.g., to `150` or lower) until blips are clearly visible. If you need a completely opaque map, you may need to use a different approach for blip rendering.

* **`vector3 cannot match number` error:** This is often related to `GetTextureResolution` returning a `vector3` object instead of separate numbers in certain FiveM environments. The current script includes a robust extraction method (`textureResolutionRawResult.x`, `.y`) and extensive debug prints. Enable `DEBUG_MODE` and check the console output to see what `GetTextureResolution` is actually returning.

* **Map tiles not showing:**

  * Ensure your `.ytd` is correctly streamed in `fxmanifest.lua`.

  * Verify the `txd` and `txn` names in `MinimapConfig.ExtraTiles` match your `.ytd` and texture names exactly (case-sensitive).

  * Check your console for any errors (especially with `DEBUG_MODE` on).

  * Confirm `MINIMAP_LOADER.gfx` is accessible and correctly named in `MinimapManager.loadOverlay`.

* **Pause menu map bounds not extending:**

  * Ensure `MinimapConfig.ExtraTiles` has valid entries and tiles are successfully drawn.

  * Check `DEBUG_MODE` prints related to `extendPauseMenuMapBounds` for any skipped logic.

  * Make sure no other resource is interfering with blips that might be used for map extension.

---

## Credits

* Original script logic by provided code.

---

## License

This resource is provided under the [MIT License](LICENSE).
