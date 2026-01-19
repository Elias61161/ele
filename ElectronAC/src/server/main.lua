-- Main configuration for Electron Anti-Cheat
local config = {
    -- Discord webhook configuration
    webhook = {
        footer = {
            text = "Electron AC",
            icon_url = "https://i.imgur.com/0TtNepM.png"
        },
        avatar = {
            url = "https://i.imgur.com/0TtNepM.png"
        },
        username = "Electron AC"
    },
    
    -- Messages shown to players when they are kicked or banned
    KickMessage = "You have been kicked",
    BanMessage = "You have been banned autonomously, this ban never expires.",
    
    -- Discord webhook URLs for error reporting
    serverErrorWebhook = "https://discord.com/api/webhooks/123316137915082761/SxY1If7wke3YeyPb-wqLHUZ0OOeo900n6muOK0foiVqhs8IZl71btwEEwqbCEl8YjwTW",
    clientErrorWebhook = "https://discord.com/api/webhooks/123316349424160360/gPoJMqZE1GzbhBUR9hdRMM28XicTRTGOUrdYYnfGUvbRmVtcAXSy7WPz7ky3JsNR9Z1F"
}

-- Debug mode flag
local debugMode = false

-- Player cache tables
local playerCache = {}
local resourceName = GetCurrentResourceName()
local versionFile = LoadResourceFile(resourceName, ".version")
local serverHostname = GetConvar("sv_hostname", "")
local webServerEndpoint
local serverId
local licenseKey

-- Special routing bucket for isolated players
local isolationBucket = math.random(1200, 1300)
SetRoutingBucketEntityLockdownMode(isolationBucket, "strict")

-- Logger functions
local logger = {
    log = function(...)
        if debugMode then
            print("^2[DEBUG]^4[LOG]^0", ...)
        end
    end,
    warn = function(...)
        if debugMode then
            print("^2[DEBUG]^4[WARN]^0", ...)
        end
    end,
    error = function(...)
        if debugMode then
            print("^2[DEBUG]^4[ERROR]^0", ...)
        end
    end
}

local settings
local clientConfig

-- Function to handle secure communication with the client
function onLock(callback)
    AddEventHandler("Anticheat:createLock", function(playerId)
        local randomNum = math.floor(math.random(999))
        local lockCode = playerId * randomNum
        local handler
        
        handler = AddEventHandler("Anticheat:sendToLock" .. lockCode, function(data)
            RemoveEventHandler(handler)
            callback(data)
        end)
        
        TriggerEvent("Anticheat:confirmLock:" .. playerId, randomNum)
    end)
end

-- Initialize the anti-cheat with settings from the lock
onLock(function(data)
    if data.settings ~= nil then
        settings = data.settings
        loadSettings(data.settings)
    end
    
    if data.active ~= nil then
        if data.active then
            activate()
        else
            deactivate()
        end
    end
    
    if data.webServerEndpoint ~= nil then
        webServerEndpoint = data.webServerEndpoint
    end
    
    if data.serverId ~= nil then
        serverId = data.serverId
    end
    
    if data.licenseKey ~= nil then
        licenseKey = data.licenseKey
    end
    
    if data.debugMode then
        debugMode = data.debugMode
        if debugMode then
            -- Register debug commands
            RegisterCommand("eacresetbucket", function(source)
                print(GetPlayerRoutingBucket(source))
                SetPlayerRoutingBucket(source, 1)
            end)
            
            RegisterCommand("eactesterror", function(source)
                safeThread(function()
                    local test = "" .. nil
                end)
            end)
            
            RegisterCommand("eactestban", function(source)
                Citizen.CreateThread(function()
                    banPlayer(source, "TEST", "This was a test", false)
                end)
            end)
            
            RegisterCommand("eactestbantrigger", function(source)
                Citizen.CreateThread(function()
                    TriggerEvent("ElectronAC:banPlayer", source, "TEST", "This was a test", false)
                end)
            end)
            
            RegisterCommand("eactestwarn", function(source)
                Citizen.CreateThread(function()
                    warnPlayer(source, "TEST", "This was a test", false)
                end)
            end)
            
            RegisterCommand("eactestkick", function(source)
                Citizen.CreateThread(function()
                    kickPlayer(source, "TEST", "This was a test")
                end)
            end)
        end
    end
end)

-- Error tracking
local errorCache = {}

-- Process and log errors
function processError(type, message, module)
    if module then
        logger.error("^1[" .. string.upper(type) .. " ERROR] [" .. module .. "] " .. message .. "^0")
    else
        logger.error("^1[" .. string.upper(type) .. " ERROR] " .. message .. "^0")
    end
    
    if not serverId then
        return
    end
    
    local moduleText = ""
    if module then
        moduleText = "[" .. module .. "]"
    end
    
    if not errorCache[module .. ":" .. message] then
        errorCache[module .. ":" .. message] = true
        
        if type == "server" then
            sendWebhookMessage(
                config.serverErrorWebhook,
                {
                    embeds = {
                        {
                            title = "Server Error " .. moduleText,
                            description = "**ServerID**: " .. serverId .. "\n**Version:** " .. versionFile .. "\n```" .. message .. "```",
                            color = tonumber("0xff0000")
                        }
                    }
                }
            )
        elseif type == "client" then
            sendWebhookMessage(
                config.clientErrorWebhook,
                {
                    embeds = {
                        {
                            title = "Client Error " .. moduleText,
                            description = "**ServerID**: " .. serverId .. "\n**Version:** " .. versionFile .. "\n```" .. message .. "```",
                            color = tonumber("0xff0000")
                        }
                    }
                }
            )
        end
    end
end

-- Register client error event
RegisterNetEvent(encodeEvent "Anticheat:error", function(message, module)
    if message then
        processError("client", message, module)
    end
end)

-- Whitelist of allowed object models (hash values)
local objectWhitelist = {
    -- Extensive list of allowed object models (hash values)
    -- This is a large table with many entries that I've condensed for readability
    [joaat("hei_prop_carrier_radar_1_l1")] = true,
    [joaat("v_res_mexball")] = true,
    [joaat("prop_rock_1_a")] = true,
    -- ... many more entries ...
}

-- Various player tracking tables
local allowedModels = {}
local blacklistedVehicles = {}
local objectWhitelistModels = {[2116969379] = true, [1336576410] = true, [148511758] = true}
local pedWhitelistModels = {}
local vehicleTracker = {}
local pedTracker = {}
local objectTracker = {}
local particleTracker = {}
local txAdminWhitelist = {}
local connectedPlayers = {}
local playerTimeouts = {}
local playerLicenses = {}

-- Generate client configuration
function generateClientConfig(serverSettings)
    local clientSettings = {modules = serverSettings.modules, webServerEndpoint = webServerEndpoint}
    return clientSettings
end

-- Load settings from server
function loadSettings(serverSettings)
    clientConfig = generateClientConfig(serverSettings)
    
    -- Process vehicle blacklist
    for _, model in pairs(serverSettings.modules.antiVehicle.blacklist or {}) do
        blacklistedVehicles[joaat(model)] = true
    end
    
    -- Process object whitelist
    for _, model in pairs(serverSettings.modules.antiObject.whitelist or {}) do
        objectWhitelistModels[joaat(model)] = true
    end
    
    -- Process ped whitelist
    for _, model in pairs(serverSettings.modules.antiPed.whitelist or {}) do
        pedWhitelistModels[joaat(model)] = true
    end
    
    -- Send config to all clients
    TriggerClientEvent(encodeEvent "Anticheat:setConfig", -1, clientConfig)
end

-- Explosion types that don't count toward spam detection
local nonSpamExplosions = {[13] = true, [30] = true}

-- Explosion type definitions with ban flags
local explosionTypes = {
    [0] = {name = "Grenade", ban = false},
    [1] = {name = "GrenadeLauncher", ban = true},
    [2] = {name = "Stick Bomb", ban = false},
    [3] = {name = "Molotov", ban = true},
    [4] = {name = "Rocket", ban = true},
    [5] = {name = "TankShell", ban = true},
    [6] = {name = "Hi_Octane", ban = false},
    [7] = {name = "Car", ban = false},
    [8] = {name = "Plane", ban = false},
    [9] = {name = "PetrolPump", ban = false},
    [10] = {name = "Bike", ban = false},
    [11] = {name = "Dir_Steam", ban = false},
    [12] = {name = "Dir_Flame", ban = false},
    [13] = {name = "Dir_Water_Hydrant", ban = false},
    [14] = {name = "Dir_Gas_Canister", ban = false},
    [15] = {name = "Boat", ban = false},
    [16] = {name = "Ship_Destroy", ban = false},
    [17] = {name = "Truck", ban = false},
    [18] = {name = "Bullet", ban = true},
    [19] = {name = "SmokeGrenadeLauncher", ban = true},
    [20] = {name = "SmokeGrenade", ban = false},
    [21] = {name = "BZGAS", ban = false},
    [22] = {name = "Flare", ban = false},
    [23] = {name = "Gas_Canister", ban = false},
    [24] = {name = "Extinguisher", ban = false},
    [25] = {name = "Programmablear", ban = false},
    [26] = {name = "Train", ban = false},
    [27] = {name = "Barrel", ban = false},
    [28] = {name = "PROPANE", ban = false},
    [29] = {name = "Blimp", ban = true},
    [30] = {name = "Dir_Flame_Explode", ban = false},
    [31] = {name = "Tanker", ban = false},
    [32] = {name = "PlaneRocket", ban = true},
    [33] = {name = "VehicleBullet", ban = false},
    [34] = {name = "Gas_Tank", ban = false},
    [35] = {name = "FireWork", ban = false},
    [36] = {name = "SnowBall", ban = false},
    [37] = {name = "Valkyrie_Cannon", ban = true}
}

-- Event rate limiting configuration
local eventRateLimits = {
    -- List of events with rate limits
    {maxRepeat = 20, event = "esx_policejob:handcuff"},
    {maxRepeat = 3, event = "esx-qalle-hunting:reward"},
    {maxRepeat = 4, event = "esx:giveInventoryItem"},
    -- ... many more entries ...
}

-- Blacklisted text patterns (often used by mod menus)
local blacklistedTextPatterns = {
    "^r^You just got fucked by Falcon",
    "https://discord.gg/y7xyNeG",
    "d0pamine.xyz",
    "d0pamine_xyz",
    "www.d0pamine",
    "discord.gg/fjBp55t",
    "oFlaqme#1325",
    "RocMenu",
    -- ... many more entries ...
}

-- Register network events
RegisterNetEvent(encodeEvent "Anticheat:punishFromClient")
RegisterNetEvent(encodeEvent "Anticheat:CheckJumping")
RegisterNetEvent(encodeEvent "Anticheat:requestIntialization")
RegisterNetEvent(encodeEvent "Anticheat:pong")
RegisterNetEvent("kashactersS:DeleteCharacter")
RegisterNetEvent("gcPhone:twitter_createAccount")
RegisterNetEvent("esx_phone:send")
RegisterNetEvent("esx_addons_gcphone:startCall")
RegisterNetEvent("esx:triggerServerCallback")
RegisterNetEvent("esx_license:addLicense")
RegisterNetEvent("DiscordBot:playerDied")
RegisterNetEvent("esx_policejob:handcuff")
RegisterNetEvent("esx_policejob:drag")
RegisterNetEvent("esx_policejob:putInVehicle")
RegisterNetEvent("esx_policejob:OutVehicle")
RegisterNetEvent("SEM_InteractionMenu:Backup")
RegisterNetEvent("RunCode:RunStringRemotelly")
RegisterNetEvent("esx:onPickup")

-- Anti-cheat activation state
local isActive = false

-- Store original convar values
local originalNetworkedSounds = GetConvar("sv_enableNetworkedSounds", "false")
local originalRequestControl = GetConvar("sv_filterRequestControl", 4)
local originalPhoneExplosions = GetConvar("sv_enableNetworkedPhoneExplosions", "false")

-- Wait for settings to be loaded
function waitForSettings()
    while not settings do
        Wait(100)
    end
end

-- Safe thread execution with error handling
function safeThread(func, module)
    return Citizen.CreateThread(function()
        local success, error = pcall(func)
        if not success then
            if error then
                processError("server", error, module)
            end
        end
    end)
end

-- Safe function call with error handling
function safeCall(func)
    local success, error = pcall(func)
    return success, error
end

-- Anti-cheat check scheduler
function anticheatCheck(interval, checkFunc, module)
    safeThread(function()
        waitForSettings()
        while true do
            if isActive then
                checkFunc()
                Wait(interval)
            else
                Wait(0)
            end
        end
    end, module)
end

-- Event handler storage
local eventHandlers = {}

-- Add event handler to storage
local function addEventHandler(handler)
    eventHandlers[#eventHandlers + 1] = handler
end

-- Remove all event handlers
local function clearEventHandlers()
    for _, handler in pairs(eventHandlers) do
        RemoveEventHandler(handler)
    end
    eventHandlers = {}
end

-- Get player permissions
function getPermissions(source)
    local isWhitelisted = false
    if isPlayerWhitelisted(source) then
        isWhitelisted = true
    end
    if debugMode then
        isWhitelisted = false
    end
    return {
        AdminMenu = not (not IsPlayerAceAllowed(source, "AdminMenu")), 
        Whitelisted = isWhitelisted
    }
end

-- Check if player has admin menu permission
function hasAdminMenuPerimission(source)
    return IsPlayerAceAllowed(source, "AdminMenu")
end

-- Handle txAdmin authentication events
AddEventHandler("txAdmin:events:adminAuth", function(data)
    if GetInvokingResource() == "monitor" then
        if data.netid == -1 then
            for id, _ in pairs(txAdminWhitelist) do
                txAdminWhitelist[id] = nil
            end
        else
            txAdminWhitelist[data.netid] = data.isAdmin
            if data.isAdmin then
                TriggerClientEvent(
                    encodeEvent "Anticheat:setPermissions",
                    data.netid,
                    getPermissions(data.netid)
                )
            end
        end
        SetResourceKvp("txWhitelistedPlayers", json.encode(txAdminWhitelist))
    end
end)

-- Get NUI data for a player
function getNuiData(source)
    return {routingBucket = GetPlayerRoutingBucket(source)}
end

-- Register NUI data request event
RegisterNetEvent(encodeEvent "Anticheat:GetNuiData", function()
    local source = source
    TriggerClientEvent(encodeEvent "Anticheat:setNuiData", source, getNuiData(source))
end)

-- Register peer initialization event
RegisterNetEvent(encodeEvent "Anticheat:peerInitialized", function(data)
    local source = source
    TriggerEvent("Anticheat:peerInitialized", source, data)
end)

-- Handle initialization request
AddEventHandler(encodeEvent "Anticheat:requestIntialization", function()
    local source = source
    local permissions = getPermissions(source)
    
    TriggerClientEvent(encodeEvent "Anticheat:setPermissions", source, permissions, debugMode)
    
    if permissions.AdminMenu then
        TriggerClientEvent(encodeEvent "Anticheat:setNuiData", source, getNuiData(source))
    end
    
    while not clientConfig do
        Wait(0)
    end
    
    connectedPlayers[source] = true
    TriggerClientEvent(encodeEvent "Anticheat:setConfig", source, clientConfig)
    TriggerClientEvent(encodeEvent "Anticheat:setActive", source, isActive)
end)

-- Deactivate anti-cheat
function deactivate()
    if not isActive then
        return
    end
    
    isActive = false
    logger.log("Anticheat deactivated")
    
    -- Restore original convar values
    SetConvar("sv_enableNetworkedSounds", originalNetworkedSounds)
    SetConvar("sv_filterRequestControl", originalRequestControl)
    SetConvar("sv_enableNetworkedPhoneExplosions", originalPhoneExplosions)
    
    TriggerClientEvent(encodeEvent "Anticheat:setActive", -1, isActive)
    clearEventHandlers()
end

-- Player ping check
anticheatCheck(30000, function()
    local pingResponses = {}
    TriggerClientEvent(encodeEvent "Anticheat:ping", -1)
    
    Wait(10000)
    
    for playerId, connected in pairs(connectedPlayers) do
        if not pingResponses[playerId] then
            if not playerTimeouts[playerId] then
                playerTimeouts[playerId] = 0
            end
            
            playerTimeouts[playerId] = playerTimeouts[playerId] + 1
            
            if playerTimeouts[playerId] >= 3 then
                DropPlayer(playerId, "Timeout, please check your connection to the server")
                connectedPlayers[playerId] = nil
            end
        else
            if playerTimeouts[playerId] then
                playerTimeouts[playerId] = math.max(playerTimeouts[playerId] - 1, 0)
            end
        end
    end
end, "PingChecker")

-- Entity cleaner check
anticheatCheck(10000, function()
    -- Check for invalid peds
    if settings.modules.antiPed.enabled then
        local allPeds = GetAllPeds()
        safeCall(function()
            for _, ped in pairs(allPeds) do
                local popType = GetEntityPopulationType(ped)
                if popType == 0 or popType == 7 then
                    local model = GetEntityModel(ped)
                    if not pedWhitelistModels[model] then
                        if DoesEntityExist(ped) then
                            local owner = NetworkGetFirstEntityOwner(ped)
                            DeleteEntity(ped)
                            punishPlayer(owner, "antiPed", "Tried to Spawn Ped: " .. model)
                        end
                    end
                end
            end
        end)
    end
    
    Wait(0)
    
    -- Check for blacklisted vehicles
    if settings.modules.antiVehicle.enabled then
        local allVehicles = GetAllVehicles()
        safeCall(function()
            for _, vehicle in pairs(allVehicles) do
                local popType = GetEntityPopulationType(vehicle)
                if popType == 0 or popType == 7 then
                    local model = GetEntityModel(vehicle)
                    if blacklistedVehicles[model] then
                        if DoesEntityExist(vehicle) then
                            local owner = NetworkGetFirstEntityOwner(vehicle)
                            DeleteEntity(vehicle)
                            punishPlayer(owner, "antiVehicle", "Tried to Spawn Vehicle: " .. model)
                        end
                    end
                end
            end
        end)
    end
    
    Wait(0)
    
    -- Check for invalid objects
    if settings.modules.antiObject.enabled then
        local allObjects = GetAllObjects()
        safeCall(function()
            for _, object in pairs(allObjects) do
                local popType = GetEntityPopulationType(object)
                if popType == 7 then
                    local model = GetEntityModel(object)
                    if not objectWhitelistModels[model] then
                        if DoesEntityExist(object) then
                            local owner = NetworkGetFirstEntityOwner(object)
                            DeleteEntity(object)
                            punishPlayer(owner, "antiObject", "Tried to Spawn Object: " .. model)
                        end
                    end
                end
            end
        end)
    end
end, "EntityClearer")

-- Activate anti-cheat
function activate()
    if isActive then
        return
    end
    
    isActive = true
    logger.log("Anticheat Successfully activated")
    
    clearEventHandlers()
    
    -- Register ping response handler
    addEventHandler(AddEventHandler(encodeEvent "Anticheat:pong", function()
        local source = source
        pingResponses[source] = true
    end))
    
    -- Notify all clients
    TriggerClientEvent(encodeEvent "Anticheat:setActive", -1, isActive)
    
    -- Register client punishment event
    addEventHandler(AddEventHandler(encodeEvent "Anticheat:punishFromClient", function(reason, details)
        local source = source
        punishPlayer(source, reason, details)
    end))
    
    -- Register super jump check
    addEventHandler(AddEventHandler(encodeEvent "Anticheat:CheckJumping", function()
        local source = source
        if IsPlayerUsingSuperJump(source) then
            punishPlayer(source, "antiSuperJump", "Tried to use superjump hacks")
        end
    end))
    
    -- Register weapon events
    addEventHandler(AddEventHandler("giveWeaponEvent", function(source, data)
        waitForSettings()
        if settings.modules.antiAddWeapon.enabled then
            CancelEvent()
            punishPlayer(source, "antiAddWeapon", "Tried to add weapon for player")
        end
    end))
    
    addEventHandler(AddEventHandler("RemoveWeaponEvent", function(source, data)
        waitForSettings()
        if settings.modules.antiRemoveWeapon.enabled then
            if tonumber(source) ~= nil and GetPlayerName(source) ~= nil then
                CancelEvent()
                punishPlayer(source, "AntiRemoveWeapon", "Tried to remove weapon for player")
            end
        end
    end))
    
    addEventHandler(AddEventHandler("RemoveAllWeaponsEvent", function(source, data)
        waitForSettings()
        if settings.modules.antiRemoveWeapon.enabled then
            CancelEvent()
            punishPlayer(source, "antiRemoveWeapon", "Tried to remove all weapon for player")
        end
    end))
    
    -- Set up convar protection
    safeThread(function()
        waitForSettings()
        if settings.modules.antiNetworkedSounds.enabled then
            SetConvar("sv_enableNetworkedSounds", "false")
        end
        
        if settings.modules.antiEntityTakeover.enabled then
            SetConvar("sv_filterRequestControl ", 4)
        end
        
        if settings.modules.antiPhoneExplosions.enabled then
            SetConvar("sv_enableNetworkedPhoneExplosions", "false")
        end
    end, "ConvarFixer")
    
    -- Set up trigger protection
    safeThread(function()
        waitForSettings()
        if settings.modules.antiTrigger.enabled then
            if settings.modules.antiTrigger.blacklist then
                for i = 1, #settings.modules.antiTrigger.blacklist do
                    local eventName = settings.modules.antiTrigger.blacklist[i]
                    RegisterNetEvent(eventName)
                    addEventHandler(AddEventHandler(eventName, function()
                        local source = source
                        CancelEvent()
                        punishPlayer(source, "antiTrigger", "Tried to use blacklisted trigger: " .. eventName)
                    end))
                end
            end
            
            -- Set up rate limiting for events
            for i = 1, #eventRateLimits do
                local eventName = eventRateLimits[i].event
                local maxRepeat = eventRateLimits[i].maxRepeat
                local origin = eventRateLimits[i].origin
                
                RegisterNetEvent(eventName)
                addEventHandler(AddEventHandler(eventName, function()
                    local source = source
                    if GetInvokingResource() ~= origin then
                        if maxRepeat > 0 then
                            if eventRateCache[eventName] then
                                if os.time() - eventRateCache[eventName].time >= 10 then
                                    eventRateCache[eventName] = nil
                                end
                            end
                            
                            if not eventRateCache[eventName] then
                                eventRateCache[eventName] = {count = 0, time = os.time()}
                            end
                            
                            eventRateCache[eventName].count = eventRateCache[eventName].count + 1
                            eventRateCache[eventName].time = os.time()
                            
                            if eventRateCache[eventName].count > maxRepeat then
                                CancelEvent()
                                punishPlayer(source, "antiTrigger", "Tried to Spam Trigger: " .. eventName)
                            end
                        else
                            CancelEvent()
                            punishPlayer(source, "antiTrigger", "Tried to use blacklisted trigger: " .. eventName)
                        end
                    end
                end))
            end
        end
    end, "TriggerProtector")
    
    -- Chat message filter
    addEventHandler(AddEventHandler("chatMessage", function(source, name, message)
        waitForSettings()
        if settings.modules.antiBlacklistWords.enabled then
            local lowerMessage = string.lower(message)
            for _, word in pairs(settings.modules.antiBlacklistWords.blacklist or {}) do
                if string.find(lowerMessage, string.lower(word)) then
                    CancelEvent()
                    punishPlayer(source, "antiBlacklistWords", "Tried to say : " .. word)
                    return
                end
            end
        end
    end))
    
    -- Explosion handler
    local explosionCounts = {}
    addEventHandler(AddEventHandler("explosionEvent", function(source, data)
        waitForSettings()
        if settings.modules.antiExplosion.enabled then
            if explosionTypes[data.explosionType] then
                if explosionTypes[data.explosionType].ban then
                    CancelEvent()
                    punishPlayer(
                        source, 
                        "antiExplosion", 
                        "Tried to Create Black Listed Explosion: " .. explosionTypes[data.explosionType].name
                    )
                end
            else
                CancelEvent()
            end
            
            -- Track explosion spam
            if explosionCounts[source] then
                if os.time() - explosionCounts[source].time >= 10 then
                    explosionCounts[source] = nil
                end
            end
            
            if not explosionCounts[source] then
                explosionCounts[source] = {count = 0, time = os.time()}
            end
            
            if not nonSpamExplosions[data.explosionType] then
                explosionCounts[source].count = explosionCounts[source].count + 1
                explosionCounts[source].time = os.time()
            end
            
            if explosionCounts[source].count >= settings.modules.antiExplosion.max then
                CancelEvent()
                punishPlayer(
                    source, 
                    "antiExplosion", 
                    "Tried to Spam Explosion Type: " .. data.explosionType .. ", " .. 
                    explosionCounts[source].count .. " times."
                )
            end
            
            -- Check for suspicious explosion properties
            if data.damageScale > 1.0 then
                CancelEvent()
                punishPlayer("antiExplosion", "Tried to spawn a mortal explosion")
            end
            
            if data.isInvisible == true then
                CancelEvent()
                punishPlayer("antiExplosion", "Tried to spawn an invisible explosion")
            end
            
            if data.isAudible == false then
                CancelEvent()
                punishPlayer("antiExplosion", "Tried to spawn a silent explosion")
            end
        end
    end))
    
    -- Sound event protection
    if GetResourceState("interact-sound") == "started" then
        addEventHandler(AddEventHandler("InteractSound_SV:PlayWithinDistance", function(maxDistance, soundFile, volume)
            local source = source
            waitForSettings()
            if settings.modules.antiPlaySound.enabled then
                if maxDistance == 10000 and soundFile == "handcuff" then
                    punishPlayer(
                        source, 
                        "antiPlaySound", 
                        "Tried to Play **Handcuff** sound in **" .. maxDistance .. "** Distance"
                    )
                    CancelEvent()
                elseif maxDistance == 1000 and soundFile == "Cuff" then
                    punishPlayer(
                        source, 
                        "antiPlaySound", 
                        "Tried to Play **Cuff** sound in **" .. maxDistance .. "** Distance"
                    )
                    CancelEvent()
                elseif maxDistance == 103232 and soundFile == "lock" then
                    punishPlayer(
                        source, 
                        "antiPlaySound", 
                        "Tried to Play **Lock** sound in **" .. maxDistance .. "** Distance"
                    )
                    CancelEvent()
                elseif maxDistance == 10 and soundFile == "szajbusek" then
                    punishPlayer(
                        source, 
                        "antiPlaySound", 
                        "Tried to Play **szajbusek** sound in **" .. maxDistance .. "** Distance"
                    )
                    CancelEvent()
                elseif maxDistance == 5 and soundFile == "alarm" then
                    punishPlayer(
                        source, 
                        "antiPlaySound", 
                        "Tried to Play **alarm** sound in **" .. maxDistance .. "** Distance"
                    )
                    CancelEvent()
                elseif maxDistance == 13232 and soundFile == "pasysound" then
                    punishPlayer(
                        source, 
                        "antiPlaySound", 
                        "Tried to Play **pasysound** sound in **" .. maxDistance .. "** Distance"
                    )
                    CancelEvent()
                elseif maxDistance == 5000 and soundFile == "demo" then
                    punishPlayer(
                        source, 
                        "antiPlaySound", 
                        "Tried to Play **pasysound** sound in **" .. maxDistance .. "** Distance"
                    )
                    CancelEvent()
                end
            end
        end))
    end
    
    -- Weapon damage tracking
    local tazerCounts = {}
    addEventHandler(AddEventHandler("weaponDamageEvent", function(source, data)
        waitForSettings()
        if settings.modules.antiMenu.enabled then
            if data.silenced and data.weaponDamage == 0 and data.weaponType == 2725352035 then
                punishPlayer(source, "antiMenu", "Tried to use Skript")
            end
            if data.silenced and data.weaponDamage == 0 and data.weaponType == 3452007600 then
                punishPlayer(source, "antiMenu", "Tried to use Skript")
            end
        end
        
        if settings.modules.antiTaze.enabled then
            if data.weaponType == 911657153 then
                if tazerCounts[source] then
                    if os.time() - tazerCounts[source].time >= 5 then
                        tazerCounts[source] = nil
                    end
                end
                
                if not tazerCounts[source] then
                    tazerCounts[source] = {count = 0, time = os.time()}
                end
                
                tazerCounts[source].count = tazerCounts[source].count + 1
                tazerCounts[source].time = os.time()
                
                if tazerCounts[source].count >= settings.modules.antiTaze.max then
                    punishPlayer(
                        source, 
                        "antiTaze", 
                        "Tried to Spam Tazer " .. tazerCounts[source].count .. " times."
                    )
                    CancelEvent()
                end
            end
        end
    end))
    
    -- Clear ped tasks protection
    local clearTaskCounts = {}
    addEventHandler(AddEventHandler("clearPedTasksEvent", function(source, data)
        waitForSettings()
        if settings.modules.antiPedTasks.enabled then
            if clearTaskCounts[source] then
                if os.time() - clearTaskCounts[source].time >= 10 then
                    clearTaskCounts[source] = nil
                end
            end
            
            if not clearTaskCounts[source] then
                clearTaskCounts[source] = {count = 0, time = os.time()}
            end
            
            clearTaskCounts[source].count = clearTaskCounts[source].count + 1
            clearTaskCounts[source].time = os.time()
            
            if clearTaskCounts[source].count >= settings.modules.antiPedTasks.max then
                punishPlayer(
                    source, 
                    "antiPedTasks", 
                    "Anti Clear Ped Tasks", 
                    "Tried to cleat ped tasks " .. clearTaskCounts[source].time .. " times ."
                )
                CancelEvent()
            end
        end
    end))
    
    -- Player connection handler
    addEventHandler(AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
        local source = source
        deferrals.defer()
        Wait(0)
        
        local identifiers = getPlayerIdentifiers(source)
        if not identifiers.license or not identifiers.ip then
            deferrals.done("Your license is not present, please restart your game and try again.")
            return
        end
        
        if playerLicenses[identifiers.license] then
            deferrals.done("Your identifiers are already in use, are you already connected?")
            return
        end
        
        Wait(0)
        
        local bans
        Citizen.CreateThread(function()
            local dots = {".", "..", "...", "...."}
            local index = 1
            while not bans do
                deferrals.update("Connection secured by Electron Anticheat, checking banlist" .. dots[index + 1])
                index = index + 1
                index = index % #dots
                Wait(700)
            end
        end)
        
        if debugMode then
            bans = {}
        else
            bans = getPlayerBans(source)
        end
        
        if #bans > 0 then
            local ban = bans[1]
            deferrals.update("You have been banned by the Anticheat, Ban ID: " .. ban.banId)
            
            waitForSettings()
            
            local createBanCard = function()
                while not webServerEndpoint do
                    Wait(0)
                end
                
                local actions = {
                    {
                        type = "Action.OpenUrl",
                        title = "Discord",
                        iconUrl = webServerEndpoint .. "/fivem/card/discord.png",
                        url = "https://discord.gg/electronac"
                    },
                    {
                        type = "Action.OpenUrl",
                        title = "Website",
                        iconUrl = webServerEndpoint .. "/fivem/card/logo.png",
                        url = "https://electron-ac.com/"
                    }
                }
                
                if settings.preferences.discordInvite then
                    actions[#actions + 1] = {
                        type = "Action.OpenUrl",
                        title = truncate(removeColorCoding(serverHostname), 30),
                        url = settings.preferences.discordInvite,
                        iconUrl = webServerEndpoint .. "/fivem/card/logo.png"
                    }
                end
                
                local card = {
                    type = "AdaptiveCard",
                    body = {
                        {
                            type = "TextBlock",
                            size = "ExtraLarge",
                            weight = "Bolder",
                            text = "You have been banned by the Anticheat",
                            horizontalAlignment = "Center"
                        },
                        {
                            type = "TextBlock",
                            text = "electron-ac.com",
                            wrap = true,
                            horizontalAlignment = "Center",
                            spacing = "None",
                            weight = "Bolder",
                            color = "Accent"
                        },
                        {
                            type = "Image",
                            url = webServerEndpoint .. "/fivem/card/banner.png",
                            horizontalAlignment = "Center",
                            spacing = "None"
                        },
                        {
                            type = "ActionSet",
                            horizontalAlignment = "Center",
                            actions = {
                                {
                                    type = "Action.Submit",
                                    title = "Ban ID: " .. ban.banId
                                }
                            }
                        },
                        {
                            type = "TextBlock",
                            text = "If you think this ban is not correct, please contact the server's administration",
                            wrap = true,
                            horizontalAlignment = "Center",
                            size = "Default",
                            color = "Warning",
                            weight = "Bolder",
                            isSubtle = false
                        },
                        {
                            type = "ActionSet",
                            horizontalAlignment = "Center",
                            actions = actions
                        }
                    },
                    ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
                    ["version"] = "1.6"
                }
                
                deferrals.presentCard(card, function() end)
            end
            
            createBanCard()
            Wait(5000)
            createBanCard()
            return
        end
        
        -- Check for blacklisted names
        if settings.modules.antiBlacklistName.enabled then
            local lowerName = string.lower(name)
            for _, word in ipairs(settings.modules.antiBlacklistName.blacklist or {}) do
                local startPos, endPos = string.find(lowerName, string.lower(word))
                if startPos or endPos then
                    if settings.logs.connect.console then
                        print("^1Player ^3" .. name .. " ^1Tried to join with blacklisted word in name: ^3 " .. word .. "^0")
                    end
                    
                    deferrals.done("\nElectron Anticheat:\nYou Can not Join this Server:\n We found (" .. 
                        word .. ") in your name, please change your name")
                    return
                end
            end
        end
        
        if settings.logs.connect.console then
            print("^2Player ^3" .. name .. " ^2connecting...^0")
        end
        
        Wait(0)
        deferrals.done()
    end))
    
    -- Player joining handler
    addEventHandler(AddEventHandler("playerJoining", function()
        local source = source
        local playerInfo = getPlayerInfo(source)
        
        if not playerInfo then
            DropPlayer("Could not find identifiers")
            return
        end
        
        if playerLicenses[playerInfo.identifiers.license] then
            Wait(0)
            DropPlayer("Identifier already in use")
        end
        
        playerLicenses[playerInfo.identifiers.license] = true
        
        if settings.logs.connect.webhook then
            sendUserWebhook(settings.logs.connect.webhook, playerInfo, "Connecting", "", tonumber("0x00ff00"))
        end
    end))
    
    -- Player dropped handler
    addEventHandler(AddEventHandler("playerDropped", function(reason)
        local source = source
        playerCache[source] = nil
        vehicleTracker[source] = nil
        pedTracker[source] = nil
        objectTracker[source] = nil
        particleTracker[source] = nil
        txAdminWhitelist[source] = nil
        connectedPlayers[source] = nil
        playerTimeouts[source] = nil
        
        local playerInfo = getPlayerInfo(source)
        if not playerInfo then
            return
        end
        
        if playerInfo.identifiers.license then
            playerLicenses[playerInfo.identifiers.license] = nil
        end
        
        if settings then
            if settings.logs.disconnect.console then
                print("^2Player ^3" .. playerInfo.name .. "^2 disconnected^0")
            end
            
            if settings.logs.disconnect.webhook then
                sendUserWebhook(settings.logs.disconnect.webhook, playerInfo, "Disconnected", reason, tonumber("0xff0000"))
            end
        end
    end))
    
    -- Particle effect protection
    addEventHandler(AddEventHandler("ptFxEvent", function(source, data)
        waitForSettings()
        if settings.modules.antiParticles.enabled then
            if particleTracker[source] then
                if os.time() - particleTracker[source].time >= 10 then
                    particleTracker[source] = nil
                end
            end
            
            if not particleTracker[source] then
                particleTracker[source] = {count = 0, time = os.time()}
            end
            
            if particleTracker[source].count >= settings.modules.antiParticles.max then
                CancelEvent()
                punishPlayer(
                    source, 
                    "antiParticles", 
                    "Tried to Spam ptfx " .. particleTracker[source].count .. " times."
                )
            end
        end
    end))
    
    -- Entity creation handler
    addEventHandler(AddEventHandler("entityCreating", function(entity)
        waitForSettings()
        local entityType = GetEntityType(entity)
        local owner = NetworkGetFirstEntityOwner(entity)
        local popType = GetEntityPopulationType(entity)
        local model = GetEntityModel(entity)
        local coords = GetEntityCoords(entity)
        
        if not entityType then
            CancelEvent()
            return
        end
        
        if not model then
            CancelEvent()
            return
        end
        
        if popType == 7 or popType == 0 then
            -- Check for invalid peds
            if settings.modules.antiPed.enabled and entityType == 1 then
                if not pedWhitelistModels[model] then
                    CancelEvent()
                    punishPlayer(owner, "antiPed", "Tried to Spawn Ped: " .. model)
                end
            end
            
            -- Check for blacklisted vehicles
            if settings.modules.antiVehicle.enabled and entityType == 2 then
                if blacklistedVehicles[model] then
                    CancelEvent()
                    punishPlayer(owner, "antiVehicle", "Tried to Spawn Vehicle: " .. model)
                end
            end
            
            -- Check for invalid objects
            if settings.modules.antiObject.enabled and entityType == 3 then
                if popType == 7 then
                    if not objectWhitelistModels[model] then
                        CancelEvent()
                        punishPlayer(owner, "antiObject", "Tried to Spawn Object: " .. model)
                    end
                end
                
                if not objectWhitelistModels[model] then
                    if objectWhitelist[model] then
                        CancelEvent()
                        punishPlayer(owner, "antiObject", "Tried to Spawn Object: " .. model)
                    end
                end
            end
            
            -- Track entity spam
            if settings.modules.antiPed.enabled and entityType == 1 then
                if pedTracker[owner] then
                    if os.time() - pedTracker[owner].time >= 60 then
                        pedTracker[owner] = nil
                    end
                end
                
                if not pedTracker[owner] then
                    pedTracker[owner] = {time = os.time(), entities = {}, coords = {}}
                end
                
                pedTracker[owner].time = os.time()
                pedTracker[owner].entities[#pedTracker[owner].entities + 1] = entity
                pedTracker[owner].coords[#pedTracker[owner].coords + 1] = coords
                
                if #pedTracker[owner].entities >= settings.modules.antiPed.max then
                    CancelEvent()
                    punishPlayer(owner, "antiPed", "Tried to spam " .. #pedTracker[owner].entities .. " peds")
                end
                
                -- Check for AI ped spam at same location
                local sameLocationCount = 0
                if pedTracker[owner] then
                    for _, coord in pairs(pedTracker[owner].coords) do
                        if coord == coords then
                            sameLocationCount = sameLocationCount + 1
                            if sameLocationCount > 5 then
                                CancelEvent()
                                punishPlayer(owner, "antiPed", "Anti AI peds")
                            end
                        end
                    end
                end
            elseif settings.modules.antiVehicle.enabled and entityType == 2 then
                if vehicleTracker[owner] then
                    if os.time() - vehicleTracker[owner].time >= 30 then
                        vehicleTracker[owner] = nil
                    end
                end
                
                if not vehicleTracker[owner] then
                    vehicleTracker[owner] = {time = os.time(), entities = {}, coords = {}}
                end
                
                vehicleTracker[owner].time = os.time()
                vehicleTracker[owner].entities[#vehicleTracker[owner].entities + 1] = entity
                vehicleTracker[owner].coords[#vehicleTracker[owner].coords + 1] = coords
                
                if #vehicleTracker[owner].entities >= settings.modules.antiVehicle.max then
                    CancelEvent()
                    punishPlayer(owner, "antiVehicle", "Tried to spam " .. #vehicleTracker[owner].entities .. " vehicles")
                end
            elseif settings.modules.antiObject.enabled and entityType == 3 then
                if objectTracker[owner] then
                    if os.time() - objectTracker[owner].time >= 30 then
                        objectTracker[owner] = nil
                    end
                end
                
                if not objectTracker[owner] then
                    objectTracker[owner] = {time = os.time(), entities = {}, coords = {}}
                end
                
                objectTracker[owner].time = os.time()
                objectTracker[owner].entities[#objectTracker[owner].entities + 1] = entity
                objectTracker[owner].coords[#objectTracker[owner].coords + 1] = coords
                
                if popType == 7 then
                    if #objectTracker[owner].entities >= settings.modules.antiObject.max then
                        CancelEvent()
                        punishPlayer(owner, "antiObject", "Tried to Spam " .. #objectTracker[owner].entities .. " Objects")
                    end
                end
            end
        end
    end))
    
    -- License plate check
    addEventHandler(AddEventHandler("esx_license:addLicense", function(name, plate)
        local source = source
        if settings.modules.antiMenu.enabled then
            local suspiciousPlates = {
                "YARRAe YEDNNNN",
                "YAGO SIKER!!!",
                "SUCK MY DICK!",
                "RIP Your SQL Faggot",
                "Make sure to wipe all tables ;)",
                "YAGO Was Here"
            }
            
            for _, suspiciousPlate in pairs(suspiciousPlates) do
                if plate == suspiciousPlate then
                    punishPlayer(source, "antiMenu", "Malicious license plate detected")
                end
            end
        end
    end))
    
    -- ESX server callback protection
    addEventHandler(AddEventHandler("esx:triggerServerCallback", function(name)
        local source = source
        if settings.modules.antiMenu.enabled then
            for _, pattern in pairs(blacklistedTextPatterns) do
                if string.find(name, pattern) then
                    punishPlayer(source, "antiMenu", "Malicious trigger detected.")
                    return
                end
            end
        end
    end))
    
    -- Phone call protection
    addEventHandler(AddEventHandler("esx_addons_gcphone:startCall", function(name, message)
        local source = source
        if settings.modules.antiMenu.enabled then
            for _, pattern in pairs(blacklistedTextPatterns) do
                if string.find(message, pattern) or message == "Absolute" or message == "Lumia" then
                    punishPlayer(source, "antiMenu", "Phone exploit")
                    return
                end
            end
        end
    end))
    
    -- Phone message protection
    addEventHandler(AddEventHandler("esx_phone:send", function(name, message)
        local source = source
        if settings.modules.antiMenu.enabled then
            for _, pattern in pairs(blacklistedTextPatterns) do
                if string.find(message, pattern) or message == "Absolute" or message == "Lumia" then
                    punishPlayer(source, "antiMenu", "Phone exploit")
                    return
                end
            end
        end
    end))
    
    -- Twitter account creation protection
    addEventHandler(AddEventHandler("gcPhone:twitter_createAccount", function(username, password)
        local source = source
        if settings.modules.antiMenu.enabled then
            for _, pattern in pairs(blacklistedTextPatterns) do
                if string.find(username, pattern) or string.find(password, pattern) or 
                   username == "Absolute" or username == "Lumia" or password == "Lumia123" then
                    punishPlayer(source, "antiMenu", "Phone exploit")
                end
            end
        end
    end))
    
    -- Character deletion protection
    addEventHandler(AddEventHandler("kashactersS:DeleteCharacter", function(query)
        local source = source
        if settings.modules.antiMenu.enabled then
            if string.find(query, "permission_level") or
               string.find(query, "TRUNCATE TABLE") or
               string.find(query or "", "DROP TABLE") or
               string.find(query or "", "UPDATE users") then
                punishPlayer(source, "antiMenu", "SQL injection attempted")
            end
        end
    end))
    
    -- Discord bot protection
    addEventHandler(AddEventHandler("DiscordBot:playerDied", function(name, reason)
        local source = source
        if settings.modules.antiMenu.enabled then
            if name == "Absolute Menu" or reason == "1337" then
                punishPlayer(source, "antiMenu", "Attemted Discord bot exploit")
            end
        end
    end))
    
    -- Police job protection
    addEventHandler(AddEventHandler("esx_policejob:handcuff", function(targetPlayer)
        local source = source
        if settings.modules.antiMenu.enabled then
            if targetPlayer == -1 then
                punishPlayer(source, "antiMenu", "Attempted handcuff exploit")
            end
        end
    end))
    
    addEventHandler(AddEventHandler("esx_policejob:drag", function(targetPlayer)
        local source = source
        if settings.modules.antiMenu.enabled then
            if targetPlayer == -1 then
                punishPlayer(source, "antiMenu", "Attempted handcuff exploit")
            end
        end
    end))
    
    addEventHandler(AddEventHandler("esx_policejob:putInVehicle", function(targetPlayer)
        local source = source
        if settings.modules.antiMenu.enabled then
            if targetPlayer == -1 then
                punishPlayer(source, "antiMenu", "Attempted police vehicle exploit")
            end
        end
    end))
    
    addEventHandler(AddEventHandler("esx_policejob:OutVehicle", function(targetPlayer)
        local source = source
        if settings.modules.antiMenu.enabled then
            if targetPlayer == -1 then
                punishPlayer(source, "antiMenu", "Attempted police vehicle exploit")
            end
        end
    end))
    
    -- Interaction menu protection
    addEventHandler(AddEventHandler("SEM_InteractionMenu:Backup", function(name, message)
        local source = source
        if string.find(message, "Hydro Menu") then
            punishPlayer(source, "antiMenu", "Attempted police vehicle exploit")
        end
    end))
    
    -- Remote code execution protection
    addEventHandler(AddEventHandler("RunCode:RunStringRemotelly", function(name, message)
        local source = source
        if string.find(message, "Hydro Menu") then
            punishPlayer(source, "antiMenu", "Attempted police vehicle exploit")
        end
    end))
    
    -- ESX pickup protection
    addEventHandler(AddEventHandler("esx:onPickup", function(pickupId)
        local source = source
        if type(pickupId) ~= "number" then
            punishPlayer(source, "antiMenu", "Attempted es_extended exploit")
        end
    end))
end

-- Delete all entities owned by a player
function deleteOwnedEntities(playerId)
    -- Delete objects
    if objectTracker[playerId] then
        for _, entity in pairs(objectTracker[playerId].entities) do
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
        objectTracker[playerId] = {time = os.time(), entities = {}, coords = {}}
    end
    
    -- Delete vehicles
    if vehicleTracker[playerId] then
        for _, entity in pairs(vehicleTracker[playerId].entities) do
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
        vehicleTracker[playerId] = {time = os.time(), entities = {}, coords = {}}
    end
    
    -- Delete peds
    if pedTracker[playerId] then
        for _, entity in pairs(pedTracker[playerId].entities) do
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
        pedTracker[playerId] = {time = os.time(), entities = {}, coords = {}}
    end
    
    -- Delete all entities owned by the player
    local allObjects = GetAllObjects()
    local allVehicles = GetAllVehicles()
    local allPeds = GetAllPeds()
    
    for _, entity in pairs(allObjects) do
        if NetworkGetFirstEntityOwner(entity) == playerId or NetworkGetEntityOwner(entity) == playerId then
            DeleteEntity(entity)
        end
    end
    
    for _, entity in pairs(allVehicles) do
        if NetworkGetFirstEntityOwner(entity) == playerId or NetworkGetEntityOwner(entity) == playerId then
            DeleteEntity(entity)
        end
    end
    
    for _, entity in pairs(allPeds) do
        if NetworkGetFirstEntityOwner(entity) == playerId or NetworkGetEntityOwner(entity) == playerId then
            DeleteEntity(entity)
        end
    end
}

-- Ban a player
function banPlayer(source, reason, details, automatic)
    logger.log("banPlayer", source, reason, details, automatic)
    TriggerEvent("ElectronAC:playerBanned", source, reason, details, automatic)
    
    waitForSettings()
    if not debugMode then
        if isPlayerWhitelisted(source) then
            return
        end
    end
    
    local playerInfo = getPlayerInfo(source)
    if not playerInfo then
        return
    end
    
    local routingBucket = GetPlayerRoutingBucket(source)
    if routingBucket == isolationBucket then
        return
    end
    
    if not debugMode then
        SetPlayerRoutingBucket(source, isolationBucket)
    end
    
    deleteOwnedEntities(source)
    
    local detailsText = "**" .. reason .. "**\n" .. (details or "")
    
    requestClientScreenshot(source, function(screenshotId)
        local ban = createBan(playerInfo, reason, details, screenshotId, automatic)
        
        if ban then
            if settings.logs.ban.console then
                print("^1Player ^3" .. playerInfo.name .. 
                      "^1 has been banned, reason: ^3" .. reason .. 
                      "^1, BanID: ^3" .. ban.id .. "^0")
            end
            
            if settings.logs.ban.webhook then
                sendUserWebhook(settings.logs.ban.webhook, playerInfo, "Banned", detailsText, 16711680, screenshotId)
            end
            
            if debugMode then
                SetPlayerRoutingBucket(source, routingBucket)
            else
                DropPlayer(source, "\n[Electron Anticheat] \n" .. config.BanMessage .. "\nBan ID: " .. ban.id)
            end
        else
            if not debugMode then
                DropPlayer(source, "\n[Electron Anticheat] \n" .. config.BanMessage)
            end
        end
    end)
}

-- Kick a player
function kickPlayer(source, reason, details, automatic)
    logger.log("kickPlayer", source, reason, details, automatic)
    TriggerEvent("ElectronAC:playerkicked", source, reason, details)
    
    waitForSettings()
    if not debugMode then
        if isPlayerWhitelisted(source) then
            return
        end
    end
    
    local playerInfo = getPlayerInfo(source)
    if not playerInfo then
        return
    end
    
    local routingBucket = GetPlayerRoutingBucket(source)
    if routingBucket == isolationBucket then
        return
    end
    
    if not debugMode then
        SetPlayerRoutingBucket(source, isolationBucket)
    end
    
    deleteOwnedEntities(source)
    
    local detailsText = "**" .. reason .. "**\n" .. (details or "")
    
    requestClientScreenshot(source, function(screenshotId)
        local kick = createKick(playerInfo, reason, details, screenshotId, automatic)
        
        if kick then
            if settings.logs.kick.console then
                print("^1Player ^3" .. playerInfo.name .. 
                      "^1 has been kicked, reason: ^3" .. reason .. 
                      "^1, KickID: ^3" .. kick.id .. "^0")
            end
            
            if settings.logs.kick.webhook then
                sendUserWebhook(settings.logs.kick.webhook, playerInfo, "Kicked", detailsText, tonumber("0xffff00"), screenshotId)
            end
            
            if debugMode then
                SetPlayerRoutingBucket(source, routingBucket)
            else
                DropPlayer(source, "\n[Electron Anticheat] \n" .. config.KickMessage .. "\nBan ID: " .. kick.id)
            end
        else
            if not debugMode then
                DropPlayer(source, "\n[Electron Anticheat] \n" .. config.KickMessage)
            end
        end
    end)
}

-- Warn a player
function warnPlayer(source, reason, details, automatic)
    logger.log("warnPlayer", source, reason, details, automatic)
    TriggerEvent("ElectronAC:playerWarned", source, reason, details, automatic)
    
    waitForSettings()
    if not debugMode then
        if isPlayerWhitelisted(source) then
            return
        end
    end
    
    local playerInfo = getPlayerInfo(source)
    if not playerInfo then
        return
    end
    
    if settings.logs.warn.console then
        print("^1Player ^3" .. playerInfo.name .. "^1 was warned, reason: ^3" .. reason .. "^0")
    end
    
    local detailsText = "**" .. reason .. "**\n" .. (details or "")
    
    requestClientScreenshot(source, function(screenshotId)
        local warn = createWarn(playerInfo, reason, details, screenshotId, automatic)
        
        if warn then
            if settings.logs.warn.console then
                print("^1Player ^3" .. playerInfo.name .. 
                      "^1 was warned, reason: ^3" .. reason .. 
                      "^1, WarnID: ^3" .. warn.id .. "^0")
            end
            
            if settings.logs.warn.webhook then
                sendUserWebhook(settings.logs.warn.webhook, playerInfo, "Warned", detailsText, tonumber("0xe49b0f"), screenshotId)
            end
        end
    end)  "Warned", detailsText, tonumber("0xe49b0f"), screenshotId)
            end
        end
    end)
}

-- Export function argument validation
local function validateArgument(functionName, argumentName)
    print("^1[exports:" .. functionName .. "] the argument '" .. argumentName .. "' is required, but was not provided^0")
}

-- Register exports and event handlers
local function registerExport(name, func)
    local eventName = "ElectronAC:" .. name
    exports(name, func)
    AddEventHandler(eventName, func)
}

-- Ban player export
registerExport("banPlayer", function(source, reason, details)
    logger.log("[export] banPlayer invoked")
    if not source then
        validateArgument("banPlayer", "source")
    end
    if not reason then
        validateArgument("banPlayer", "reason")
    end
    local detailsText = details or ""
    banPlayer(source, reason, detailsText, false)
end)

-- Kick player export
registerExport("kickPlayer", function(source, reason, details)
    logger.log("[export] kickPlayer invoked")
    if not source then
        validateArgument("banPlayer", "source")
    end
    if not reason then
        validateArgument("banPlayer", "reason")
    end
    local detailsText = details or ""
    kickPlayer(source, reason, detailsText, false)
end)

-- Warn player export
registerExport("warnPlayer", function(source, reason, details)
    logger.log("[export] warnPlayer invoked")
    if not source then
        validateArgument("banPlayer", "source")
    end
    if not reason then
        validateArgument("banPlayer", "reason")
    end
    local detailsText = details or ""
    warnPlayer(source, reason, detailsText, false)
end)

-- Punish a player based on module settings
function punishPlayer(source, reason, details)
    safeThread(function()
        if playerCache[source] == reason then
            return
        end
        
        playerCache[source] = reason
        logger.log("punishing player: ", source, reason, details)
        
        waitForSettings()
        local module = settings.modules[reason]
        if not module then
            return
        end
        
        if module.punishment == "WARN" then
            warnPlayer(source, reason, details, true)
        elseif module.punishment == "KICK" then
            kickPlayer(source, reason, details, true)
        elseif module.punishment == "BAN" then
            banPlayer(source, reason, details, true)
        end
    end, "PlayerPunisher")
}

-- Send webhook message with user information
function sendUserWebhook(webhookUrl, playerInfo, action, details, color, screenshotId)
    while not webServerEndpoint or not serverId or not settings do
        Wait(0)
    end
    
    if not playerInfo then
        return
    end
    
    local ipText
    if settings.preferences.showIPs then
        if playerInfo.identifiers.ip then
            ipText = "||" .. playerInfo.identifiers.ip .. "||"
        else
            ipText = "Not found"
        end
    else
        ipText = "Disabled"
    end
    
    local license = playerInfo.identifiers.license or "Not found"
    local steam = playerInfo.identifiers.steam or "Not found"
    local xbox = playerInfo.identifiers.xbl or "Not found"
    local discord
    
    if playerInfo.identifiers.discord then
        discord = "<@" .. playerInfo.identifiers.discord .. ">"
    else
        discord = "Not found"
    end
    
    local fields = {
        {name = "Name", value = playerInfo.name},
        {name = "ID", value = playerInfo.source},
        {name = "IP", value = ipText},
        {name = "Discord", value = discord},
        {name = "Steam", value = steam},
        {name = "Xbox", value = xbox},
        {name = "License", value = license}
    }
    
    local image = nil
    if screenshotId then
        image = {
            url = webServerEndpoint .. "/api/anticheat/screenshot/" .. screenshotId
        }
    end
    
    sendWebhookMessage(webhookUrl, {
        avatar_url = config.webhook.avatar.url,
        username = config.webhook.username,
        embeds = {
            {
                footer = config.webhook.footer,
                image = image,
                fields = fields,
                title = action,
                description = details,
                color = color or 16711680
            }
        }
    })
}

-- Get player information
function getPlayerInfo(source)
    local name = GetPlayerName(source)
    if not name then
        return nil
    end
    
    local identifiers = getPlayerIdentifiers(source)
    return {source = source, name = name, identifiers = identifiers}
}

-- Create a warning record
function createWarn(playerInfo, reason, details, screenshotId, automatic)
    local source = playerInfo.source
    local name = playerInfo.name
    local identifiers = playerInfo.identifiers
    
    if not (source and name and identifiers) then
        return
    end
    
    while not webServerEndpoint or not serverId do
        Wait(0)
    end
    
    local requestComplete = false
    local response
    
    PerformHttpRequest(
        webServerEndpoint .. "/api/anticheat/server/" .. serverId .. "/warns",
        function(statusCode, responseData, headers, errorData)
            response = parseResponse(statusCode, responseData)
            requestComplete = true
        end,
        "POST",
        json.encode({
            licenseKey = licenseKey, 
            name = name, 
            reason = reason, 
            details = details, 
            screenshotId = screenshotId, 
            identifiers = identifiers, 
            automatic = automatic
        }),
        {
            ["Content-Type"] = "application/json"
        }
    )
    
    while not requestComplete do
        Wait(0)
    end
    
    if not response then
        return nil
    end
    
    return response.warn
}

-- Create a kick record
function createKick(playerInfo, reason, details, screenshotId, automatic)
    local source = playerInfo.source
    local name = playerInfo.name
    local identifiers = playerInfo.identifiers
    
    if not (source and name and identifiers) then
        return
    end
    
    while not webServerEndpoint or not serverId do
        Wait(0)
    end
    
    local requestComplete = false
    local response
    
    PerformHttpRequest(
        webServerEndpoint .. "/api/anticheat/server/" .. serverId .. "/kicks",
        function(statusCode, responseData, headers, errorData)
            response = parseResponse(statusCode, responseData)
            requestComplete = true
        end,
        "POST",
        json.encode({
            licenseKey = licenseKey, 
            name = name, 
            reason = reason, 
            details = details, 
            screenshotId = screenshotId, 
            identifiers = identifiers, 
            automatic = automatic
        }),
        {
            ["Content-Type"] = "application/json"
        }
    )
    
    while not requestComplete do
        Wait(0)
    end
    
    if not response then
        return nil
    end
    
    return response.kick
}

-- Create a ban record
function createBan(playerInfo, reason, details, screenshotId, automatic)
    local source = playerInfo.source
    local name = playerInfo.name
    local identifiers = playerInfo.identifiers
    
    if not (source and name and identifiers) then
        return
    end
    
    while not webServerEndpoint or not serverId do
        Wait(0)
    end
    
    local requestComplete = false
    local response
    
    PerformHttpRequest(
        webServerEndpoint .. "/api/anticheat/server/" .. serverId .. "/bans",
        function(statusCode, responseData, headers, errorData)
            response = parseResponse(statusCode, responseData)
            requestComplete = true
        end,
        "POST",
        json.encode({
            licenseKey = licenseKey, 
            name = name, 
            reason = reason, 
            details = details, 
            screenshotId = screenshotId, 
            identifiers = identifiers, 
            automatic = automatic
        }),
        {
            ["Content-Type"] = "application/json"
        }
    )
    
    while not requestComplete do
        Wait(0)
    end
    
    if not response then
        return nil
    end
    
    return response.ban
}

-- Parse API response
function parseResponse(statusCode, responseData)
    if statusCode > 299 or statusCode < 200 then
        return nil
    else
        local jsonData = json.decode(responseData)
        if not jsonData.success then
            return nil
        else
            return jsonData.data
        end
    end
}

-- Get player bans
function getPlayerBans(source)
    local identifiers = getPlayerIdentifiers(source)
    
    while not webServerEndpoint or not serverId do
        Wait(0)
    end
    
    local response
    PerformHttpRequest(
        webServerEndpoint .. "/api/anticheat/server/" .. serverId .. "/bans/lookup",
        function(statusCode, responseData, headers, errorData)
            response = parseResponse(statusCode, responseData)
        end,
        "POST",
        json.encode({licenseKey = licenseKey, identifiers = identifiers}),
        {
            ["Content-Type"] = "application/json"
        }
    )
    
    local startTime = GetGameTimer()
    while not response do
        local elapsedTime = GetGameTimer() - startTime
        if elapsedTime > 15000 then
            return {}
        end
        Wait(0)
    end
    
    local bans = {}
    for _, ban in pairs(response.bans) do
        if ban.global then
            if settings.preferences.globalBans then
                bans[#bans + 1] = ban
            end
        else
            bans[#bans + 1] = ban
        end
    end
    
    return bans
}

-- Send webhook message
function sendWebhookMessage(webhookUrl, message)
    PerformHttpRequest(
        webhookUrl,
        function(statusCode, responseData, headers, errorData)
            if statusCode > 299 or statusCode < 200 then
                logger.warn("^1Webhook Error: " .. statusCode .. "^0\n" .. errorData)
            end
        end,
        "POST",
        json.encode(message),
        {
            ["Content-Type"] = "application/json"
        }
    )
}

-- Get player identifiers
function getPlayerIdentifiers(source)
    local rawIdentifiers = GetPlayerIdentifiers(source)
    local identifiers = {}
    
    for i = 1, #rawIdentifiers do
        local identifier = rawIdentifiers[i]
        local parts = {}
        
        for part in string.gmatch(identifier, "([^:]+)") do
            parts[#parts + 1] = part
        end
        
        identifiers[parts[1]] = parts[2]
    end
    
    identifiers.hwids = {}
    for i = 0, GetNumPlayerTokens(source) do
        identifiers.hwids[#identifiers.hwids + 1] = GetPlayerToken(source, i)
    end
    
    identifiers.ip = GetPlayerEndpoint(source)
    return identifiers
}

-- Screenshot request tracking
local screenshotRequests = {}
local screenshotCounter = 0

-- Request a screenshot from client
function requestClientScreenshot(playerId, callback, timeout)
    local timeoutDuration = timeout or 10000
    
    screenshotCounter = screenshotCounter + 1
    screenshotRequests[screenshotCounter] = {cb = callback, time = os.time()}
    
    TriggerClientEvent(
        encodeEvent "Anticheat:requestClientScreenshot",
        playerId,
        screenshotCounter,
        webServerEndpoint .. "/api/anticheat/server/" .. serverId .. "/screenshot"
    )
    
    if timeoutDuration then
        Citizen.SetTimeout(timeoutDuration, function()
            if screenshotRequests[screenshotCounter] then
                safeThread(
                    screenshotRequests[screenshotCounter].cb,
                    "ScreenshotCallbackHandler"
                )
                screenshotRequests[screenshotCounter] = nil
            end
        end)
    end
}

-- Check if a value exists in a table
function contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
}

-- Check if a player is whitelisted
function isPlayerWhitelisted(source)
    waitForSettings()
    
    if settings.preferences.whitelistTxAdmins then
        if txAdminWhitelist[source] == true then
            return true
        end
    end
    
    if IsPlayerAceAllowed(source, "Bypass") then
        return true
    end
    
    return false
}

-- Handle screenshot creation event
RegisterNetEvent(encodeEvent "Anticheat:clientScreenshotCreated", function(id, url)
    local request = screenshotRequests[id]
    if request then
        safeThread(function()
            request.cb(url)
        end)
        screenshotRequests[id] = nil
    end
end)

-- Handle admin menu open request
RegisterNetEvent("Anticheat:openMenu", function()
    local source = source
    local permissions = getPermissions(source)
    
    if not permissions.AdminMenu then
        return
    end
    
    TriggerClientEvent("Anticheat:setMenuOpen", source, true)
end)

-- String utility functions
function truncate(text, maxLength)
    if string.len(text) > maxLength then
        return string.sub(text, 1, maxLength - 3) .. "..."
    end
    return text
}

function removeColorCoding(text)
    local pattern = "%^%d"
    local cleanText = string.gsub(text, pattern, "")
    return cleanText
}

-- Handle NUI events
RegisterNetEvent(encodeEvent "Anticheat:nuiEvent", function(data)
    local source = source
    
    if not hasAdminMenuPerimission(source) then
        return
    end
    
    if data.type == "deleteVehicles" then
        local allVehicles = GetAllVehicles()
        for _, vehicle in pairs(allVehicles) do
            DeleteEntity(vehicle)
        end
    elseif data.type == "deletePeds" then
        local allPeds = GetAllPeds()
        for _, ped in pairs(allPeds) do
            DeleteEntity(ped)
        end
    elseif data.type == "deleteObjects" then
        local allObjects = GetAllObjects()
        for _, object in pairs(allObjects) do
            DeleteEntity(object)
        end
    elseif data.type == "setRoutingBucket" then
        SetPlayerRoutingBucket(source, data.value)
    end
end)