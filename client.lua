local function dbg(...)
    if Config and Config.debug then
        print(('^5[minimap-tiles]^7 %s'):format(table.concat({ ... }, ' ')))
    end
end

-- Overlay handle.
local overlay = 0

-- Will store the names of the currently drawn tiles IN DRAW ORDER.
local drawnTiles = {}

-- Map of tileName -> draw index (1-based) for fast lookup.
local drawnIndexByName = {}

-- Dummy blips used to extend pause menu bounds.
local dummyBlips = {}

-- Derived constants (do not modify at runtime)
local vBitmapTileSizeX
local vBitmapTileSizeY
local vBitmapStartX
local vBitmapStartY

-- ----------------------------
-- Utilities
-- ----------------------------

local function clampInt(n, minv, maxv)
    n = tonumber(n) or 0
    if n < minv then return minv end
    if n > maxv then return maxv end
    return math.floor(n)
end

local function toFloat(n)
    return (tonumber(n) or 0.0) * 1.0
end

local function loadTextureDictionary(txd)
    if not txd or txd == '' then return false end
    if HasStreamedTextureDictLoaded(txd) then return true end

    RequestStreamedTextureDict(txd, false)
    local timeoutAt = GetGameTimer() + 5000
    while not HasStreamedTextureDictLoaded(txd) do
        Wait(0)
        if GetGameTimer() > timeoutAt then
            dbg('Timed out loading TXD:', txd)
            return false
        end
    end

    return true
end

local function getTextureSize(txd, txn)
    local x, y = table.unpack(GetTextureResolution(txd, txn))
    return tonumber(x) or 0, tonumber(y) or 0
end

local function getTileByName(tileName)
    if not Config or not Config.tiles then return nil end
    for i = 1, #Config.tiles do
        local t = Config.tiles[i]
        if t and t.name == tileName then
            return t
        end
    end
    return nil
end

local function createDummyBlip(x, y)
    local blip = AddBlipForCoord(x, y, 1.0)
    SetBlipDisplay(blip, 4)
    SetBlipAlpha(blip, 0)
    dummyBlips[#dummyBlips + 1] = blip
end

local function resetPauseMenuMapBounds()
    for i = 1, #dummyBlips do
        if DoesBlipExist(dummyBlips[i]) then
            RemoveBlip(dummyBlips[i])
        end
    end
    dummyBlips = {}
end

local function loadMinimapOverlay(gfxFilePath)
    local _overlay = AddMinimapOverlay(gfxFilePath)
    while not HasMinimapOverlayLoaded(_overlay) do
        Wait(0)
    end
    SetMinimapOverlayDisplay(_overlay, 0.0, 0.0, 100.0, 100.0, 100.0)
    return _overlay
end

local function ClearMinimap()
    SetMinimapClipType(0)

    -- small delay ensures reset
    Wait(100)

    if Config.enablePausemapBounds then
        SetMinimapClipType(1)
    end
end

-- ----------------------------
-- Tile operations
-- ----------------------------

local function computeOffsets(tile)
    -- If tile uses world coords, convert to offsets.
    if tile.x ~= nil and tile.y ~= nil then
        tile.xOffset = (tile.x - vBitmapStartX) / vBitmapTileSizeX
        tile.yOffset = (tile.y - vBitmapStartY) / vBitmapTileSizeY
    end

    if tile.xOffset == nil or tile.yOffset == nil then
        return nil, nil
    end

    -- y offset is inverted for minimap scaleform.
    local xOffset = toFloat(tile.xOffset)
    local yOffset = toFloat(tile.yOffset) * (-1.0)
    return xOffset, yOffset
end

local function createTile(tileName)
    if not tileName then return false end
    if drawnIndexByName[tileName] then
        dbg('Tile already drawn:', tileName)
        return true
    end

    local tile = getTileByName(tileName)
    if not tile then
        dbg('Unknown tile:', tileName)
        return false
    end

    if not tile.txd or not tile.txn then
        dbg('Tile missing txd/txn:', tileName)
        return false
    end

    local alpha = clampInt(tile.alpha ~= nil and tile.alpha or Config.defaultAlpha, 0, 100)
    local centered = tile.centered == true
    local rotation = toFloat(tile.rotation or 0.0)

    if not loadTextureDictionary(tile.txd) then
        return false
    end

    local texW, texH = getTextureSize(tile.txd, tile.txn)
    if texW <= 0 or texH <= 0 then
        dbg('Bad texture resolution for', tileName, tile.txd, tile.txn)
        SetStreamedTextureDictAsNoLongerNeeded(tile.txd)
        return false
    end

    local xScale = (vBitmapTileSizeX / texW) * 100.0
    local yScale = (vBitmapTileSizeY / texH) * 100.0

    local xOffset, yOffset = computeOffsets(tile)
    if not xOffset then
        dbg('Tile missing offsets/coords:', tileName)
        SetStreamedTextureDictAsNoLongerNeeded(tile.txd)
        return false
    end

    local x = vBitmapStartX + xOffset * vBitmapTileSizeX
    local y = vBitmapStartY - yOffset * vBitmapTileSizeY

    CallMinimapScaleformFunction(overlay, 'ADD_SCALED_OVERLAY')
    ScaleformMovieMethodAddParamTextureNameString(tile.txd)
    ScaleformMovieMethodAddParamTextureNameString(tile.txn)
    ScaleformMovieMethodAddParamFloat(x)
    ScaleformMovieMethodAddParamFloat(y)
    ScaleformMovieMethodAddParamFloat(rotation)
    ScaleformMovieMethodAddParamFloat(xScale)
    ScaleformMovieMethodAddParamFloat(yScale)
    ScaleformMovieMethodAddParamInt(alpha)
    ScaleformMovieMethodAddParamBool(centered)
    EndScaleformMovieMethod()

    SetStreamedTextureDictAsNoLongerNeeded(tile.txd)

    drawnTiles[#drawnTiles + 1] = tileName
    drawnIndexByName[tileName] = #drawnTiles

    return true
end

local function deleteTile(tileName)
    if not tileName then return false end

    local idx = drawnIndexByName[tileName]
    if not idx then
        return false
    end

    -- Remove overlay at (idx - 1). The scaleform overlay list is 0-based.
    CallMinimapScaleformFunction(overlay, 'REM_OVERLAY')
    ScaleformMovieMethodAddParamInt(idx - 1)
    EndScaleformMovieMethod()

    -- Remove from tables and rebuild the index map (cheap, small list)
    table.remove(drawnTiles, idx)
    drawnIndexByName = {}
    for i = 1, #drawnTiles do
        drawnIndexByName[drawnTiles[i]] = i
    end

    return true
end

local function isTileDrawn(tileName)
    return drawnIndexByName[tileName] ~= nil
end

local function createAllTiles()
    if not Config or not Config.tiles then return end
    for i = 1, #Config.tiles do
        local t = Config.tiles[i]
        if t and t.name then
            createTile(t.name)
        end
    end

    if Config.extendPauseMenuBounds then
        if #dummyBlips == 0 and #drawnTiles > 0 then
            -- Extend bounds once after drawing.
            -- This uses the *current* drawn tiles.
            local xMin = nil
            local xMax = nil
            local yMin = nil
            local yMax = nil

            for i = 1, #drawnTiles do
                local tile = getTileByName(drawnTiles[i])
                if tile then
                    local xOff, yOff = computeOffsets(tile)
                    if xOff then
                        -- computeOffsets returns inverted yOff already.
                        -- We want original offset directions for bounds, so use tile.yOffset directly.
                        local xo = toFloat(tile.xOffset)
                        local yo = toFloat(tile.yOffset)

                        xMin = xMin == nil and xo or math.min(xMin, xo)
                        xMax = xMax == nil and xo or math.max(xMax, xo)
                        yMin = yMin == nil and yo or math.min(yMin, yo)
                        yMax = yMax == nil and yo or math.max(yMax, yo)
                    end
                end
            end

            if xMin ~= nil then
                resetPauseMenuMapBounds()

                createDummyBlip(vBitmapStartX + xMin * vBitmapTileSizeX - vBitmapTileSizeX / 2,
                    vBitmapStartY + yMax * vBitmapTileSizeY + vBitmapTileSizeY / 2)

                createDummyBlip(vBitmapStartX + xMin * vBitmapTileSizeX - vBitmapTileSizeX / 2,
                    vBitmapStartY + (yMin - 1) * vBitmapTileSizeY - vBitmapTileSizeY / 2)

                createDummyBlip(vBitmapStartX + (xMax + 1) * vBitmapTileSizeX + vBitmapTileSizeX / 2,
                    vBitmapStartY + (yMin - 1) * vBitmapTileSizeY - vBitmapTileSizeY / 2)

                createDummyBlip(vBitmapStartX + (xMax + 1) * vBitmapTileSizeX + vBitmapTileSizeX / 2,
                    vBitmapStartY + yMax * vBitmapTileSizeY + vBitmapTileSizeY / 2)
            end
        end
    end
end

local function deleteAllTiles()
    -- Always delete index 1 until empty.
    while #drawnTiles > 0 do
        deleteTile(drawnTiles[1])
    end

    if #dummyBlips > 0 then
        resetPauseMenuMapBounds()
    end
end

-- ----------------------------
-- Radar zoom behavior (optimized)
-- ----------------------------

local function startRadarZoomThread()
    if not Config.radar.enabled then return end

    CreateThread(function()
        local lastApplied = nil
        while true do
            local ped = PlayerPedId()
            if ped ~= 0 then
                local shouldApply = (IsPedOnFoot(ped) or IsPedInAnyVehicle(ped, true))
                if shouldApply and lastApplied ~= Config.radar.zoom then
                    SetRadarZoom(Config.radar.zoom)
                    lastApplied = Config.radar.zoom
                elseif not shouldApply and lastApplied ~= nil then
                    -- Let the game handle default zoom when not in our conditions.
                    lastApplied = nil
                end
            end
            Wait(Config.radar.pollMs or 250)
        end
    end)
end

-- ----------------------------
-- Init / lifecycle
-- ----------------------------

local function applyZoomLevels()
    if not Config.zoomLevels.enabled then return end
    for i = 1, #Config.zoomLevels.levels do
        local z = Config.zoomLevels.levels[i]
        if z and #z >= 6 then
            SetMapZoomDataLevel(z[1], z[2], z[3], z[4], z[5], z[6])
        end
    end
end

local function initConstants()
    vBitmapTileSizeX = toFloat(Config.bitmap.tileSizeX)
    vBitmapTileSizeY = toFloat(Config.bitmap.tileSizeY)
    vBitmapStartX = toFloat(Config.bitmap.startX)
    vBitmapStartY = toFloat(Config.bitmap.startY)
end

local function init()
    if type(Config) ~= 'table' then
        print('^1[minimap-tiles]^7 Config missing/invalid')
        return
    end

    initConstants()
    applyZoomLevels()

    overlay = loadMinimapOverlay('MINIMAP_LOADER.gfx')
    createAllTiles()

    startRadarZoomThread()

    dbg('Loaded. Tiles drawn:', tostring(#drawnTiles))
end

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    deleteAllTiles()
    ClearMinimap()
end)

AddEventHandler('onResourceStart', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    print('Extended map tiles, orginally created by: L1CKS, Improved by: Lughworks')
end)
-- ----------------------------
-- Commands (optional quality-of-life)
-- ----------------------------

RegisterCommand('minimap_tiles_on', function()
    if overlay == 0 then
        overlay = loadMinimapOverlay('MINIMAP_LOADER.gfx')
    end
    createAllTiles()
end, false)

RegisterCommand('minimap_tiles_off', function()
    deleteAllTiles()
end, false)

RegisterCommand('minimap_tiles_debug', function()
    Config.debug = not Config.debug
    dbg('Debug:', tostring(Config.debug))
end, false)

-- ----------------------------
-- Exports (backwards compatible)
-- ----------------------------

exports('createAllTiles', createAllTiles)
exports('deleteAllTiles', deleteAllTiles)
exports('createTile', createTile)
exports('deleteTile', deleteTile)
exports('isTileDrawn', isTileDrawn)
exports('resetPauseMenuMapBounds', resetPauseMenuMapBounds)

CreateThread(init)
