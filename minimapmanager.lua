local MinimapConfig = {
    ExtraTiles = {
        [1] = {xOffset = 0, yOffset = 0, txd = "roxwood", txn = "minimap_0_0"},
        [2] = {xOffset = 0, yOffset = 1, txd = "roxwood", txn = "minimap_0_1"},
    },
    DefaultAlpha = 150,
    BitmapTileSizeX = 4500.0,
    BitmapTileSizeY = 4500.0,
    BitmapStartX = -4140.0,
    BitmapStartY = 8400.0,
}

local DEBUG_MODE = true

local function DebugPrint(...)
    if DEBUG_MODE then
        print(string.format("[MinimapManager DEBUG] %s", table.concat({...}, " ")))
    end
end

local MinimapManager = {}

local overlayHandle = 0
local drawnTilesMap = {}
local drawnTilesList = {}
local dummyBlips = {}

local function loadTextureDictionary(textureDictionary)
    DebugPrint("Loading texture dictionary:", textureDictionary)
    if not HasStreamedTextureDictLoaded(textureDictionary) then
        RequestStreamedTextureDict(textureDictionary, false)
        while not HasStreamedTextureDictLoaded(textureDictionary) do
            Citizen.Wait(0)
            DebugPrint("Waiting for texture dictionary to load:", textureDictionary)
        end
        DebugPrint("Texture dictionary loaded:", textureDictionary)
    else
        DebugPrint("Texture dictionary already loaded:", textureDictionary)
    end
end

local function createDummyBlip(x, y)
    DebugPrint("Creating dummy blip at X:", x, "Y:", y)
    local blip = AddBlipForCoord(x, y, 1.0)
    SetBlipDisplay(blip, 4)
    SetBlipAlpha(blip, 0)
    table.insert(dummyBlips, blip)
    DebugPrint("Dummy blip created. Handle:", blip)
end

local function getSortedTableKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

function MinimapManager.loadOverlay(gfxFilePath)
    DebugPrint("Attempting to load minimap overlay:", gfxFilePath)
    local handle
    if AddMinimapOverlayWithDepth then
        handle = AddMinimapOverlayWithDepth(gfxFilePath, -10)
        DebugPrint("Using AddMinimapOverlayWithDepth with depth -10.")
    else
        handle = AddMinimapOverlay(gfxFilePath)
        DebugPrint("Using AddMinimapOverlay (AddMinimapOverlayWithDepth not available).")
    end

    while not HasMinimapOverlayLoaded(handle) do
        Citizen.Wait(0)
        DebugPrint("Waiting for minimap overlay to load. Handle:", handle)
    end
    SetMinimapOverlayDisplay(handle, 0.0, 0.0, 100.0, 100.0, 100.0)
    DebugPrint("Minimap overlay loaded and displayed. Handle:", handle)
    return handle
end

function MinimapManager.createTile(tileKey)
    DebugPrint("Attempting to create tile:", tostring(tileKey))
    local tileData = MinimapConfig.ExtraTiles[tileKey]

    if not tileData then
        DebugPrint("Error: Invalid tile data for key '" .. tostring(tileKey) .. "'. Skipping creation.")
        return
    end

    if not tileData.txd or not tileData.txn then
        DebugPrint("Error: Missing 'txd' or 'txn' for tile '" .. tostring(tileKey) .. "'. Skipping creation.")
        return
    end

    if drawnTilesMap[tileKey] then
        DebugPrint("Tile '" .. tostring(tileKey) .. "' is already drawn. Skipping creation.")
        return
    end

    local textureDictionary = tileData.txd
    local textureName = tileData.txn
    local alpha = tileData.alpha or MinimapConfig.DefaultAlpha
    local centered = tileData.centered or false
    local rotation = tileData.rotation or 0.0
    DebugPrint("Tile properties - TXD:", textureDictionary, "TXN:", textureName, "Alpha:", alpha, "Centered:", tostring(centered), "Rotation:", rotation)

    loadTextureDictionary(textureDictionary)

    local textureResolutionRawResult = GetTextureResolution(textureDictionary, textureName)
    DebugPrint("GetTextureResolution('" .. textureDictionary .. "', '" .. textureName .. "') raw result: " .. tostring(textureResolutionRawResult) .. " (type: " .. type(textureResolutionRawResult) .. ")")

    local xTexture, yTexture

    if type(textureResolutionRawResult) == "table" and textureResolutionRawResult.x ~= nil and textureResolutionRawResult.y ~= nil then
        xTexture = tonumber(textureResolutionRawResult.x)
        yTexture = tonumber(textureResolutionRawResult.y)
        DebugPrint("Extracted xTexture: " .. tostring(xTexture) .. " (type: " .. type(xTexture) .. "), yTexture: " .. tostring(yTexture) .. " (type: " .. type(yTexture) .. ") from table.")
    elseif type(textureResolutionRawResult) == "number" then
        xTexture = tonumber(textureResolutionRawResult)
        yTexture = xTexture
        DebugPrint("GetTextureResolution returned single number. xTexture: " .. tostring(xTexture) .. " (type: " .. type(xTexture) .. "), assuming yTexture = xTexture.")
    else
        DebugPrint("Error: GetTextureResolution for '" .. textureDictionary .. "/" .. textureName .. "' returned an unexpected type: " .. type(textureResolutionRawResult) .. ". Cannot extract dimensions.")
        return
    end

    if type(xTexture) ~= "number" or type(yTexture) ~= "number" or xTexture == 0 or yTexture == 0 then
        DebugPrint("Error: Final check failed for texture resolution for '" .. textureDictionary .. "/" .. textureName .. "'. xTexture: " .. tostring(xTexture) .. " (type: " .. type(xTexture) .. "), yTexture: " .. tostring(yTexture) .. " (type: " .. type(yTexture) .. "). Must be non-zero numbers.")
        return
    end

    local xScale = MinimapConfig.BitmapTileSizeX / xTexture * 100
    local yScale = MinimapConfig.BitmapTileSizeY / yTexture * 100
    DebugPrint("Calculated xScale:", xScale, "(type:", type(xScale), "), yScale:", yScale, "(type:", type(yScale), ")")

    local xOffset = tileData.xOffset or 0
    local yOffset = tileData.yOffset or 0

    if tileData.x ~= nil and tileData.y ~= nil then
        xOffset = (tileData.x - MinimapConfig.BitmapStartX) / MinimapConfig.BitmapTileSizeX
        yOffset = (tileData.y - MinimapConfig.BitmapStartY) / MinimapConfig.BitmapTileSizeY
        DebugPrint("Calculated offsets from XY coords: xOffset:", xOffset, "yOffset:", yOffset)
    else
        DebugPrint("Using pre-defined offsets: xOffset:", xOffset, "yOffset:", yOffset)
    end

    local x = MinimapConfig.BitmapStartX + xOffset * MinimapConfig.BitmapTileSizeX
    local y = MinimapConfig.BitmapStartY - (yOffset * -1.0) * MinimapConfig.BitmapTileSizeY
    DebugPrint("Calculated final screen coordinates: X:", x, "Y:", y)

    alpha = math.floor(math.abs(alpha))
    rotation = rotation * 1.0

    DebugPrint("Calling ADD_SCALED_OVERLAY Scaleform function...")
    CallMinimapScaleformFunction(overlayHandle, "ADD_SCALED_OVERLAY")
    ScaleformMovieMethodAddParamTextureNameString(textureDictionary)
    ScaleformMovieMethodAddParamTextureNameString(textureName)
    ScaleformMovieMethodAddParamFloat(x)
    ScaleformMovieMethodAddParamFloat(y)
    ScaleformMovieMethodAddParamFloat(rotation)
    ScaleformMovieMethodAddParamFloat(xScale)
    ScaleformMovieMethodAddParamFloat(yScale)
    ScaleformMovieMethodAddParamInt(alpha)
    ScaleformMovieMethodAddParamBool(centered)
    EndScaleformMovieMethod()
    DebugPrint("ADD_SCALED_OVERLAY call ended.")

    SetStreamedTextureDictAsNoLongerNeeded(textureDictionary)
    DebugPrint("Marked texture dictionary as no longer needed:", textureDictionary)

    table.insert(drawnTilesList, tileKey)
    drawnTilesMap[tileKey] = true
    DebugPrint("Tile '" .. tostring(tileKey) .. "' successfully added to drawnTiles. Current drawnTiles count:", #drawnTilesList)
end

function MinimapManager.deleteTile(tileKey)
    DebugPrint("Attempting to delete tile:", tostring(tileKey))
    if not drawnTilesMap[tileKey] then
        DebugPrint("Tile '" .. tostring(tileKey) .. "' is not currently drawn. Skipping deletion.")
        return
    end

    local id = -1
    for i = 1, #drawnTilesList do
        if drawnTilesList[i] == tileKey then
            id = i
            break
        end
    end

    if id ~= -1 then
        DebugPrint("Found tile '" .. tostring(tileKey) .. "' at list index:", id, " (Scaleform ID:", id - 1, ")")
        DebugPrint("Calling REM_OVERLAY Scaleform function...")
        CallMinimapScaleformFunction(overlayHandle, "REM_OVERLAY")
        ScaleformMovieMethodAddParamInt(id - 1)
        EndScaleformMovieMethod()
        DebugPrint("REM_OVERLAY call ended.")

        table.remove(drawnTilesList, id)
        drawnTilesMap[tileKey] = nil
        DebugPrint("Tile '" .. tostring(tileKey) .. "' removed from drawnTiles. Current drawnTiles count:", #drawnTilesList)
    else
        DebugPrint("Error: Internal error - tile '" .. tostring(tileKey) .. "' found in map but not in list during deletion attempt.")
    end
end

function MinimapManager.createAllTiles()
    DebugPrint("Attempting to create all configured tiles.")
    local tileKeys = getSortedTableKeys(MinimapConfig.ExtraTiles)
    if #tileKeys == 0 then
        DebugPrint("No extra tiles configured to draw.")
        return
    end

    DebugPrint("Found", #tileKeys, "tiles to create. Starting creation loop.")
    for _, tileKey in ipairs(tileKeys) do
        MinimapManager.createTile(tileKey)
    end

    if #drawnTilesList > 0 and #dummyBlips == 0 then
        MinimapManager.extendPauseMenuMapBounds()
    elseif #drawnTilesList == 0 then
        DebugPrint("No tiles were successfully drawn, not extending map bounds.")
    else
        DebugPrint("Dummy blips already exist, not extending map bounds again during createAllTiles.")
    end
    DebugPrint("Finished creating all configured tiles.")
end

function MinimapManager.deleteAllTiles()
    DebugPrint("Attempting to delete all currently drawn tiles.")
    if #drawnTilesList == 0 then
        DebugPrint("No tiles are currently drawn to delete.")
    end

    for i = #drawnTilesList, 1, -1 do
        MinimapManager.deleteTile(drawnTilesList[i])
    end
    DebugPrint("All tiles deleted from list.")
    drawnTilesList = {}
    drawnTilesMap = {}
    DebugPrint("drawnTilesList and drawnTilesMap cleared.")

    if #dummyBlips ~= 0 then
        MinimapManager.resetPauseMenuMapBounds()
    end
    DebugPrint("Finished deleting all drawn tiles.")
end

function MinimapManager.isTileDrawn(tileKey)
    local isDrawn = drawnTilesMap[tileKey] ~= nil
    DebugPrint("Checking if tile '" .. tostring(tileKey) .. "' is drawn:", tostring(isDrawn))
    return isDrawn
end

function MinimapManager.extendPauseMenuMapBounds()
    DebugPrint("Attempting to extend pause menu map bounds.")
    MinimapManager.resetPauseMenuMapBounds()

    if #drawnTilesList == 0 then
        DebugPrint("No tiles drawn to base map bounds extension on. Skipping.")
        return
    end

    local firstTileKey = drawnTilesList[1]
    local firstTileData = MinimapConfig.ExtraTiles[firstTileKey]

    if not firstTileData then
        DebugPrint("Error: Could not find data for first drawn tile '" .. tostring(firstTileKey) .. "'. Cannot extend bounds.")
        return
    end

    local xMinOffset = firstTileData.xOffset or 0
    local xMaxOffset = firstTileData.xOffset or 0
    local yMinOffset = firstTileData.yOffset or 0
    local yMaxOffset = firstTileData.yOffset or 0

    DebugPrint("Initial min/max offsets: X (", xMinOffset, ",", xMaxOffset, "), Y (", yMinOffset, ",", yMaxOffset, ")")

    for i, tileKey in ipairs(drawnTilesList) do
        local tileData = MinimapConfig.ExtraTiles[tileKey]
        if tileData then
            xMinOffset = math.min(xMinOffset, tileData.xOffset or 0)
            xMaxOffset = math.max(xMaxOffset, tileData.xOffset or 0)
            yMinOffset = math.min(yMinOffset, tileData.yOffset or 0)
            yMaxOffset = math.max(yMaxOffset, tileData.yOffset or 0)
        else
            DebugPrint("Warning: Tile data for drawn tile '" .. tostring(tileKey) .. "' not found in MinimapConfig.ExtraTiles.")
        end
    end
    DebugPrint("Calculated overall min/max offsets: X (", xMinOffset, ",", xMaxOffset, "), Y (", yMinOffset, ",", yMaxOffset, ")")

    local tsX = MinimapConfig.BitmapTileSizeX
    local tsY = MinimapConfig.BitmapTileSizeY
    local bsX = MinimapConfig.BitmapStartX
    local bsY = MinimapConfig.BitmapStartY

    DebugPrint("Creating 4 dummy blips to extend bounds...")
    createDummyBlip(bsX + xMinOffset * tsX - tsX / 2,     bsY + yMaxOffset * tsY + tsY / 2)
    createDummyBlip(bsX + xMinOffset * tsX - tsX / 2,     bsY + (yMinOffset - 1) * tsY - tsY / 2)
    createDummyBlip(bsX + (xMaxOffset + 1) * tsX + tsX / 2, bsY + (yMinOffset - 1) * tsY - tsY / 2)
    createDummyBlip(bsX + (xMaxOffset + 1) * tsX + tsX / 2, bsY + yMaxOffset * tsY + tsY / 2)
    DebugPrint("Map bounds extension complete. Total dummy blips:", #dummyBlips)
end

function MinimapManager.resetPauseMenuMapBounds()
    DebugPrint("Attempting to reset pause menu map bounds. Removing", #dummyBlips, "dummy blips.")
    for i = 1, #dummyBlips do
        RemoveBlip(dummyBlips[i])
        DebugPrint("Removed dummy blip handle:", dummyBlips[i])
    end
    dummyBlips = {}
    DebugPrint("All dummy blips removed. dummyBlips table cleared.")
end

exports("createAllTiles", MinimapManager.createAllTiles)
exports("deleteAllTiles", MinimapManager.deleteAllTiles)
exports("createTile", MinimapManager.createTile)
exports("deleteTile", MinimapManager.deleteTile)
exports("extendPauseMenuMapBounds", MinimapManager.extendPauseMenuMapBounds)
exports("resetPauseMenuMapBounds", MinimapManager.resetPauseMenuMapBounds)
exports("isTileDrawn", MinimapManager.isTileDrawn)

Citizen.CreateThread(function()
    DebugPrint("Resource starting. Initializing minimap overlay...")
    overlayHandle = MinimapManager.loadOverlay("MINIMAP_LOADER.gfx")
    DebugPrint("Overlay handle received:", overlayHandle)
    MinimapManager.createAllTiles()
    DebugPrint("Initial tile creation complete.")
end)