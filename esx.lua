-- Vanguard Server Wrapper - ESX Framework Implementation
-- Provides unified API wrapper for ESX framework functions on server-side

-- ========================================
-- FRAMEWORK INITIALIZATION
-- ========================================

if Config.framework == "esx" then
    -- Initialize ESX
    ESX = exports.es_extended:getSharedObject()
    
    -- ========================================
    -- PLAYER MANAGEMENT
    -- ========================================
    
    -- Get player object from server ID
    function Vanguard.GetPlayerFromId(playerId)
        return ESX.GetPlayerFromId(playerId)
    end
    
    -- Get player data with fallback handling
    function Vanguard.GetPlayerData(playerId)
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if not xPlayer then
            return nil
        end
        
        local playerData
        
        -- Try modern ESX methods first
        if xPlayer.getIdentifier then
            playerData = {
                name = xPlayer.getName(),
                job = xPlayer.getJob(),
                identifier = xPlayer.getIdentifier()
            }
        else
            -- Fallback to old ESX method
            playerData = xPlayer.get("playerData")
        end
        
        -- Ensure job data exists
        if playerData and not playerData.job then
            playerData.job = xPlayer.getJob()
        end
        
        return playerData
    end
    
    -- ========================================
    -- INVENTORY MANAGEMENT
    -- ========================================
    
    -- Give item to player
    function Vanguard.GiveItem(playerId, itemName, quantity)
        -- Check if using QS Inventory
        if Config.inventory == "qs-inventory" then
            exports['qs-inventory']:AddItem(playerId, itemName, quantity)
            return
        end
        
        -- Default ESX inventory
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if xPlayer then
            xPlayer.addInventoryItem(itemName, quantity)
        end
    end
    
    -- Remove item from player
    function Vanguard.RemoveItem(playerId, itemName, quantity)
        -- Check if using QS Inventory
        if Config.inventory == "qs-inventory" then
            exports['qs-inventory']:RemoveItem(playerId, itemName, quantity)
            return
        end
        
        -- Default ESX inventory
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if xPlayer then
            xPlayer.removeInventoryItem(itemName, quantity)
        end
    end
    
    -- Get player's inventory
    function Vanguard.GetInventory(playerId)
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if xPlayer then
            return xPlayer.getInventory()
        end
        
        return nil
    end
    
    -- Check if player has specific item
    function Vanguard.HasItem(playerId, itemName)
        -- Check if using QS Inventory
        if Config.inventory == "qs-inventory" then
            local item = exports['qs-inventory']:GetItemTotalAmount(playerId, itemName)
            return item and item > 0
        end
        
        -- Default ESX inventory
        local inventory = Vanguard.GetInventory(playerId)
        
        if inventory then
            for _, item in pairs(inventory) do
                if item.name == itemName and item.count > 0 then
                    return true
                end
            end
        end
        
        return false
    end
    
    -- ========================================
    -- MONEY MANAGEMENT
    -- ========================================
    
    -- Give money to player
    function Vanguard.GiveMoney(playerId, amount)
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if xPlayer then
            xPlayer.addMoney(amount)
        end
    end
    
    -- Remove money from player
    function Vanguard.RemoveMoney(playerId, amount)
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if xPlayer then
            xPlayer.removeMoney(amount)
        end
    end
    
    -- Give dirty money (black money) to player
    function Vanguard.GiveDirtyMoney(playerId, amount)
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if xPlayer then
            xPlayer.addAccountMoney("black_money", amount)
        end
    end
    
    -- Remove dirty money from player
    function Vanguard.RemoveDirtyMoney(playerId, amount)
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if xPlayer then
            xPlayer.removeAccountMoney("black_money", amount)
        end
    end
    
    -- ========================================
    -- JOB MANAGEMENT
    -- ========================================
    
    -- Set player's job
    function Vanguard.SetJob(playerId, jobName, jobGrade)
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if xPlayer then
            xPlayer.setJob(jobName, jobGrade)
        end
    end
    
    -- ========================================
    -- NOTIFICATIONS
    -- ========================================
    
    -- Show notification to player
    function Vanguard.ShowNotification(playerId, message)
        local xPlayer = Vanguard.GetPlayerFromId(playerId)
        
        if xPlayer then
            xPlayer.showNotification(message)
        end
    end
    
    -- Unified notification system supporting multiple frameworks
    function Vanguard.notifyserver(playerId, title, message, duration, notificationType)
        local notifySystem = Config.notify
        
        if notifySystem == "okokNotify" then
            TriggerClientEvent("okokNotify:Alert", playerId, title, message, duration, notificationType)
            
        elseif notifySystem == "Vanguard_notify" then
            TriggerClientEvent("vanguardNotify", playerId, title, message, duration, notificationType)
            
        elseif notifySystem == "esx" then
            TriggerClientEvent("esx:showNotification", playerId, message)
            
        elseif notifySystem == "qbcore" then
            TriggerClientEvent("QBCore:Client:Notify", playerId, message, notificationType)
            
        elseif notifySystem == "brutal_notify" then
            TriggerClientEvent("brutal_notify:SendAlert", playerId, title, message, duration, notificationType)
            
        else
            print("Notification system not configured correctly or bridge does not support that notify system.")
        end
    end
    
    -- ========================================
    -- ITEM & CALLBACK REGISTRATION
    -- ========================================
    
    -- Register usable item
    function Vanguard.RegisterUsableItem(itemName, callback)
        ESX.RegisterUsableItem(itemName, callback)
    end
    
    -- Register server callback
    function Vanguard.RegisterServerCallback(callbackName, callback)
        ESX.RegisterServerCallback(callbackName, callback)
    end
    
    -- Trigger client callback
    function Vanguard.TriggerClientCallback(playerId, eventName, data, ...)
        TriggerClientEvent(eventName, playerId, data, ...)
    end
end
