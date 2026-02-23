--[[
    Improved minimap extra-tiles config

    Notes:
    - Tiles can be positioned using xOffset/yOffset (tile grid) OR x/y (world coords).
    - Alpha: 0-100
    - Rotation: degrees clockwise
    - centered: true = anchor in the middle of the chosen point instead of top-left

    This config is shared and safe to edit.
]]

Config = {
    -- Debug prints (F8 console)
    debug = false,

    -- Radar behavior
    radar = {
        enabled = true,
        zoom = 1100,        -- SetRadarZoom value
        pollMs = 250,       -- How often to check state (ms)
    },

    -- Optional GTA minimap zoom levels (SetMapZoomDataLevel)
    -- If you don't want custom zoom levels, set enabled=false.
    zoomLevels = {
        enabled = true,
        levels = {
            -- {level, zoomScale, zoomSpeed, scrollSpeed, tilesX, tilesY}
            {0, 0.96, 0.9, 0.08, 0.0, 0.0},
            {1, 1.60, 0.9, 0.08, 0.0, 0.0},
            {2, 8.60, 0.9, 0.08, 0.0, 0.0},
            {3, 12.3, 0.9, 0.08, 0.0, 0.0},
            {4, 22.3, 0.9, 0.08, 0.0, 0.0},
        }
    },

    -- Tile grid constants (must match your minimap.ytd/ymt setup)
    -- Only change these if you KNOW your minimap origin/tile size differs.
    bitmap = {
        tileSizeX = 4500.0,
        tileSizeY = 4500.0,
        startX = -4140.0,
        startY = 8400.0,
    },

    -- If true, the script will extend pause-menu map bounds using invisible blips.
    extendPauseMenuBounds = true,

    -- Default alpha when a tile doesn't specify one.
    defaultAlpha = 100,

    -- Tiles list
    -- Give each tile a unique name.
    tiles = {
        {
            name = 'roxwood_1',
            xOffset = 0,
            yOffset = 1,
            txd = 'minimap_roxwood_1',
            txn = 'extra_tile_1',
        },
        {
            name = 'roxwood_2',
            xOffset = -1,
            yOffset = 1,
            txd = 'minimap_roxwood_2',
            txn = 'extra_tile_1',
        },
        {
            name = 'roxwood_3',
            xOffset = -1,
            yOffset = 0,
            txd = 'minimap_roxwood_3',
            txn = 'extra_tile_1',
        },
    },
}
