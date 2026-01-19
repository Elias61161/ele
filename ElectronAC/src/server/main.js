/**
 * Electron Anti-Cheat - Main Server Module
 * This file handles the server-side operations of the anti-cheat system
 */

// Configuration settings for the anti-cheat system
var settings = {
    preferences: {
        showIPs: false,
        globalBans: true,
        whitelistTxAdmins: true,
        discordInvite: ""
    },
    modules: {
        // Various anti-cheat detection modules with their settings
        antiPhoneExplosions: { enabled: true },
        antiFolder: { enabled: true, punishment: "BAN" },
        antiHealth: { enabled: true, punishment: "BAN", max: 200 },
        antiArmor: { enabled: true, punishment: "BAN", max: 100 },
        antiStamina: { enabled: true, punishment: "BAN" },
        antiGodmode: { enabled: false, punishment: "WARN" },
        // Many more modules listed with their configurations...
    },
    logs: {
        warn: { console: true, webhook: null },
        kick: { console: true, webhook: null },
        ban: { console: true, webhook: null },
        connect: { console: true, webhook: null },
        disconnect: { console: true, webhook: null }
    }
};

// Debug mode flag
var debugMode = false;

// Logger setup for different message types
var logger = {
    log: (...args) => { console.log("^4[LOG]^0", ...args) },
    warn: (...args) => { console.warn("^2[WARN]^0", ...args) },
    error: (...args) => { console.error("^1[ERROR]^0", ...args) },
    write: (...args) => { console.log(...args) },
    writeCenter(text, width) {
        console.log(" ".repeat(Math.max(Math.round(width / 2 - text.length / 2), 0)) + text)
    }
};

// Debug logger that only outputs when debug mode is enabled
var debugLogger = {
    log: (...args) => { debugMode && console.log("^2[DEBUG]^4[LOG]^0", ...args) },
    warn: (...args) => { debugMode && console.warn("^2[DEBUG]^2[WARN]^0", ...args) },
    error: (...args) => { debugMode && console.error("^2[DEBUG]^1[ERROR]^0", ...args) }
};

// Array to store connected players
var players = [];

// Get resource information
var resourceName = GetCurrentResourceName();
var licenseKey = LoadResourceFile(resourceName, ".key");
var versionInfo = LoadResourceFile(resourceName, ".version");

// Check if required files exist
if (!versionInfo || !licenseKey) {
    throw new Error("Failed to start! Files missing/corrupted!");
}

// Server endpoints configuration
var endpoints = debugMode ? {
    backendServerEndpoint: "wss://electronac.root.sx:8631",
    webServerEndpoint: "https://electronac.root.sx"
} : {
    backendServerEndpoint: "wss://anticheat.electron-services.com",
    webServerEndpoint: "https://api.electron-services.com"
};

// Timeouts for connection handling
var connectionTimeout = 20000;
var pingTimeout = 5000;

// Map to store command handlers
var commandHandlers = new Map();

// Initialize WebSocket connection
function initializeWebSocket() {
    debugLogger.log("Trying to establish WS connection...");
    
    let connected = false;
    
    const connect = () => {
        // Create WebSocket connection to backend
        let ws = new WebSocket(endpoints.backendServerEndpoint, {
            handshakeTimeout: 0
        });
        
        // Setup ping/pong to keep connection alive
        let intervals = {};
        let timeout = setTimeout(() => {
            clearTimeout(timeout);
            if (ws.readyState === 1) ws.close();
        }, connectionTimeout + pingTimeout);
        
        // Handle connection events
        ws.on("error", err => { debugLogger.error(err) });
        
        ws.on("open", () => {
            connected = true;
            debugLogger.log("WS connection opened");
            
            // Initialize the anti-cheat system
            initializeAntiCheat(ws);
            
            // Setup player and resource reporting functions
            playerReporter = () => {
                sendToServer(ws, "server:players", { players: players });
            };
            
            resourceReporter = () => {
                sendToServer(ws, "server:resources", { resources: resources });
            };
        });
        
        // Handle incoming messages
        ws.on("message", data => {
            let message = parseMessage(data);
            if (!message) return;
            
            let handler = commandHandlers.get(message.type);
            if (handler) {
                handler.call(null, ws, message.data);
            }
        });
        
        // Handle connection close
        ws.on("close", () => {
            let wasConnected = connected;
            connected = false;
            playerReporter = undefined;
            resourceReporter = undefined;
            
            debugLogger.log("WS connection closed");
            clearTimeout(timeout);
            
            // Clear all intervals
            for (const [_, interval] of Object.entries(intervals)) {
                clearInterval(interval);
            }
            intervals = {};
            
            // Reconnect after delay
            setTimeout(() => {
                if (wasConnected) logger.log("Connection closed. Reconnecting...");
                connect();
            }, 3000);
        });
    };
    
    // Start in offline mode or connect to server
    if (offlineMode) {
        logger.write("^3" + "-".repeat(30) + "^0");
        logger.writeCenter("^1 OFFLINE MODE ^0", 30);
        logger.write("^3" + "-".repeat(30) + "^0");
        
        // Initialize with default settings in offline mode
        updateAntiCheatSettings({
            active: true,
            settings: settings,
            serverId: "testserverid"
        });
    } else {
        connect();
    }
}

// Main startup function
function startup() {
    debugLogger.log("Starting Electron Anticheat...");
    
    // Initialize settings
    updateAntiCheatSettings({
        webServerEndpoint: endpoints.webServerEndpoint,
        licenseKey: licenseKey,
        debugMode: debugMode
    });
    
    // Start WebSocket connection
    initializeWebSocket();
}

// Start the anti-cheat system
startup();

// Register command handlers for various server operations
commandHandlers.set("entities:peds:remove", (ws, data) => {
    logger.log("Removing all peds...");
    let peds = GetAllPeds();
    for (let ped of peds) DeleteEntity(ped);
    logger.log(`Removed ${peds.length} peds ...`);
});

commandHandlers.set("entities:objects:remove", (ws, data) => {
    logger.log("Removing all objects...");
    let objects = GetAllObjects();
    for (let object of objects) DeleteEntity(object);
    logger.log(`Removed ${objects.length} objects ...`);
});

commandHandlers.set("entities:vehicles:remove", (ws, data) => {
    logger.log("Removing all vehicles...");
    let vehicles = GetAllVehicles();
    for (let vehicle of vehicles) DeleteEntity(vehicle);
    logger.log(`Removed ${vehicles.length} vehicles ...`);
});

commandHandlers.set("resource:start", (ws, data) => {
    let { resource } = data;
    StartResource(resource);
});

commandHandlers.set("resource:stop", (ws, data) => {
    let { resource } = data;
    StopResource(resource);
});

commandHandlers.set("resource:restart", (ws, data) => {
    let { resource } = data;
    StopResource(resource);
    StartResource(resource);
});

commandHandlers.set("player:kick", (ws, data) => {
    let { playerId, reason } = data;
    DropPlayer(playerId, reason || "No reason provided");
});

commandHandlers.set("settings:update", (ws, data) => {
    logger.log("Updating settings...");
    updateAntiCheatSettings({
        settings: data.settings
    });
});

// Helper functions for the anti-cheat system
function updateAntiCheatSettings(settings) {
    setTimeout(() => {
        setImmediate(() => {
            let randomId = Math.floor(Math.random() * 999);
            on("Anticheat:confirmLock:" + randomId, multiplier => {
                let lockId = randomId * multiplier;
                emit("Anticheat:sendToLock" + lockId, settings);
            });
            emit("Anticheat:createLock", randomId);
        });
    }, 0);
}

function getPlayerIdentifiers(playerId) {
    let count = GetNumPlayerIdentifiers(playerId);
    let identifiers = {};
    
    for (i = 0; i < count; i++) {
        let identifier = GetPlayerIdentifier(playerId, i);
        let [type, value] = identifier.split(":");
        if (type && value) {
            identifiers[type] = value;
        }
    }
    
    return identifiers;
}

function sendToServer(ws, type, data) {
    ws.send(JSON.stringify({
        type: type,
        data: data
    }));
}

function parseMessage(data) {
    let message = JSON.parse(data.toString());
    if (!message?.type || !message?.data) return null;
    
    return {
        type: message.type,
        data: message.data
    };
}

// Event handlers for player connections and resource changes
on("playerJoining", async () => {
    let playerId = global.source;
    players.push({
        id: playerId,
        name: GetPlayerName(playerId),
        ping: GetPlayerPing(playerId),
        identifiers: getPlayerIdentifiers(playerId),
        coordinates: null,
        peerId: null
    });
    
    if (playerReporter) playerReporter();
    
    // Get player's geolocation based on IP
    let endpoint = GetPlayerEndpoint(playerId);
    if (endpoint) {
        let coordinates = await getGeoLocation(endpoint);
        let player = players.find(p => p.id === playerId);
        if (player) {
            player.coordinates = coordinates;
            if (playerReporter) playerReporter();
        }
    }
});

on("playerDropped", () => {
    let playerId = global.source;
    let index = players.findIndex(p => p.id === playerId);
    if (index !== -1) {
        players.splice(index, 1);
        if (playerReporter) playerReporter();
    }
});

on("Anticheat:peerInitialized", (playerId, peerId) => {
    let player = players.find(p => p.id === playerId);
    if (player) {
        player.peerId = peerId;
        if (playerReporter) playerReporter();
    }
});