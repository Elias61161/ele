
local debugMode = false
local anticheatActive = false
local playerId = PlayerId()
local playerPermissions = {}
local config
local lastPosition
local playerSpawned = false
local playerInitialized = false

-- Debug logging functies
local debug = {
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

-- Wacht tot config is geladen
local function waitForConfig()
    while not config do
        Wait(100)
    end
end

-- Voer functie uit met foutafhandeling
local function runSafely(func, name)
    Citizen.CreateThread(
        function()
            local success, error = pcall(func)
            if not success then
                if error then
                    TriggerServerEvent(encodeEvent "Anticheat:error", error, name)
                end
            end
        end
    )
end

-- Voer functie periodiek uit
local function runPeriodically(interval, func, name)
    runSafely(
        function()
            local running = true
            local stop = function()
                running = false
            end
            waitForConfig()
            while running do
                if anticheatActive then
                    if not playerPermissions.Whitelisted then
                        func(stop)
                    end
                    Wait(interval)
                else
                    Wait(0)
                end
            end
        end,
        name
    )
end

-- Toegestane wapens (triggeren geen detectie)
local whitelistedWeapons = {[joaat("WEAPON_STUNGUN")] = true}

-- Blacklisted pickups die spelers niet zouden moeten kunnen verzamelen
local blacklistedPickups = {
    joaat "PICKUP_WEAPON_BULLPUPSHOTGUN",
    joaat "PICKUP_WEAPON_ASSAULTSMG",
    joaat "PICKUP_VEHICLE_WEAPON_ASSAULTSMG",
    joaat "PICKUP_WEAPON_PISTOL50",
    joaat "PICKUP_VEHICLE_WEAPON_PISTOL50",
    joaat "PICKUP_AMMO_BULLET_MP",
    joaat "PICKUP_AMMO_MISSILE_MP",
    joaat "PICKUP_AMMO_GRENADELAUNCHER_MP",
    joaat "PICKUP_WEAPON_ASSAULTRIFLE",
    joaat "PICKUP_WEAPON_CARBINERIFLE",
    joaat "PICKUP_WEAPON_ADVANCEDRIFLE",
    joaat "PICKUP_WEAPON_MG",
    joaat "PICKUP_WEAPON_COMBATMG",
    joaat "PICKUP_WEAPON_SNIPERRIFLE",
    joaat "PICKUP_WEAPON_HEAVYSNIPER",
    joaat "PICKUP_WEAPON_MICROSMG",
    joaat "PICKUP_WEAPON_SMG",
    joaat "PICKUP_ARMOUR_STANDARD",
    joaat "PICKUP_WEAPON_RPG",
    joaat "PICKUP_WEAPON_MINIGUN",
    joaat "PICKUP_HEALTH_STANDARD",
    joaat "PICKUP_WEAPON_PUMPSHOTGUN",
    joaat "PICKUP_WEAPON_SAWNOFFSHOTGUN",
    joaat "PICKUP_WEAPON_ASSAULTSHOTGUN",
    joaat "PICKUP_WEAPON_GRENADE",
    joaat "PICKUP_WEAPON_MOLOTOV",
    joaat "PICKUP_WEAPON_SMOKEGRENADE",
    joaat "PICKUP_WEAPON_STICKYBOMB",
    joaat "PICKUP_WEAPON_PISTOL",
    joaat "PICKUP_WEAPON_COMBATPISTOL",
    joaat "PICKUP_WEAPON_APPISTOL",
    joaat "PICKUP_WEAPON_GRENADELAUNCHER",
    joaat "PICKUP_MONEY_VARIABLE",
    joaat "PICKUP_GANG_ATTACK_MONEY",
    joaat "PICKUP_WEAPON_STUNGUN",
    joaat "PICKUP_WEAPON_PETROLCAN",
    joaat "PICKUP_WEAPON_KNIFE",
    joaat "PICKUP_WEAPON_NIGHTSTICK",
    joaat "PICKUP_WEAPON_HAMMER",
    joaat "PICKUP_WEAPON_BAT",
    joaat "PICKUP_WEAPON_GolfClub",
    joaat "PICKUP_WEAPON_CROWBAR",
    joaat "PICKUP_CUSTOM_SCRIPT",
    joaat "PICKUP_CAMERA",
    joaat "PICKUP_PORTABLE_PACKAGE",
    joaat "PICKUP_PORTABLE_CRATE_UNFIXED",
    joaat "PICKUP_PORTABLE_PACKAGE_LARGE_RADIUS",
    joaat "PICKUP_PORTABLE_CRATE_UNFIXED_INCAR",
    joaat "PICKUP_PORTABLE_CRATE_UNFIXED_INAIRVEHICLE_WITH_PASSENGERS",
    joaat "PICKUP_PORTABLE_CRATE_UNFIXED_INAIRVEHICLE_WITH_PASSENGERS_UPRIGHT",
    joaat "PICKUP_PORTABLE_CRATE_UNFIXED_INCAR_WITH_PASSENGERS",
    joaat "PICKUP_PORTABLE_CRATE_FIXED_INCAR_WITH_PASSENGERS",
    joaat "PICKUP_PORTABLE_CRATE_FIXED_INCAR_SMALL",
    joaat "PICKUP_PORTABLE_CRATE_UNFIXED_INCAR_SMALL",
    joaat "PICKUP_PORTABLE_CRATE_UNFIXED_LOW_GLOW",
    joaat "PICKUP_MONEY_CASE",
    joaat "PICKUP_MONEY_WALLET",
    joaat "PICKUP_MONEY_PURSE",
    joaat "PICKUP_MONEY_DEP_BAG",
    joaat "PICKUP_MONEY_MED_BAG",
    joaat "PICKUP_MONEY_PAPER_BAG",
    joaat "PICKUP_MONEY_SECURITY_CASE",
    joaat "PICKUP_VEHICLE_WEAPON_COMBATPISTOL",
    joaat "PICKUP_VEHICLE_WEAPON_APPISTOL",
    joaat "PICKUP_VEHICLE_WEAPON_PISTOL",
    joaat "PICKUP_VEHICLE_WEAPON_GRENADE",
    joaat "PICKUP_VEHICLE_WEAPON_MOLOTOV",
    joaat "PICKUP_VEHICLE_WEAPON_SMOKEGRENADE",
    joaat "PICKUP_VEHICLE_WEAPON_STICKYBOMB",
    joaat "PICKUP_VEHICLE_HEALTH_STANDARD",
    joaat "PICKUP_VEHICLE_HEALTH_STANDARD_LOW_GLOW",
    joaat "PICKUP_VEHICLE_ARMOUR_STANDARD",
    joaat "PICKUP_VEHICLE_WEAPON_MICROSMG",
    joaat "PICKUP_VEHICLE_WEAPON_SMG",
    joaat "PICKUP_VEHICLE_WEAPON_SAWNOFF",
    joaat "PICKUP_VEHICLE_CUSTOM_SCRIPT",
    joaat "PICKUP_VEHICLE_CUSTOM_SCRIPT_NO_ROTATE",
    joaat "PICKUP_VEHICLE_CUSTOM_SCRIPT_LOW_GLOW",
    joaat "PICKUP_VEHICLE_MONEY_VARIABLE",
    joaat "PICKUP_SUBMARINE",
    joaat "PICKUP_HEALTH_SNACK",
    joaat "PICKUP_PARACHUTE",
    joaat "PICKUP_AMMO_PISTOL",
    joaat "PICKUP_AMMO_SMG",
    joaat "PICKUP_AMMO_RIFLE",
    joaat "PICKUP_AMMO_MG",
    joaat "PICKUP_AMMO_SHOTGUN",
    joaat "PICKUP_AMMO_SNIPER",
    joaat "PICKUP_AMMO_GRENADELAUNCHER",
    joaat "PICKUP_AMMO_RPG",
    joaat "PICKUP_AMMO_MINIGUN",
    joaat "PICKUP_WEAPON_BOTTLE",
    joaat "PICKUP_WEAPON_SNSPISTOL",
    joaat "PICKUP_WEAPON_HEAVYPISTOL",
    joaat "PICKUP_WEAPON_SPECIALCARBINE",
    joaat "PICKUP_WEAPON_BULLPUPRIFLE",
    joaat "PICKUP_WEAPON_RAYPISTOL",
    joaat "PICKUP_WEAPON_RAYCARBINE",
    joaat "PICKUP_WEAPON_RAYMINIGUN",
    joaat "PICKUP_WEAPON_BULLPUPRIFLE_MK2",
    joaat "PICKUP_WEAPON_DOUBLEACTION",
    joaat "PICKUP_WEAPON_MARKSMANRIFLE_MK2",
    joaat "PICKUP_WEAPON_PUMPSHOTGUN_MK2",
    joaat "PICKUP_WEAPON_REVOLVER_MK2",
    joaat "PICKUP_WEAPON_SNSPISTOL_MK2",
    joaat "PICKUP_WEAPON_SPECIALCARBINE_MK2",
    joaat "PICKUP_WEAPON_PROXMINE",
    joaat "PICKUP_WEAPON_HOMINGLAUNCHER",
    joaat "PICKUP_AMMO_HOMINGLAUNCHER",
    joaat "PICKUP_WEAPON_GUSENBERG",
    joaat "PICKUP_WEAPON_DAGGER",
    joaat "PICKUP_WEAPON_VINTAGEPISTOL",
    joaat "PICKUP_WEAPON_FIREWORK",
    joaat "PICKUP_WEAPON_MUSKET",
    joaat "PICKUP_AMMO_FIREWORK",
    joaat "PICKUP_AMMO_FIREWORK_MP",
    joaat "PICKUP_PORTABLE_DLC_VEHICLE_PACKAGE",
    joaat "PICKUP_WEAPON_HATCHET",
    joaat "PICKUP_WEAPON_RAILGUN",
    joaat "PICKUP_WEAPON_HEAVYSHOTGUN",
    joaat "PICKUP_WEAPON_MARKSMANRIFLE",
    joaat "PICKUP_WEAPON_CERAMICPISTOL",
    joaat "PICKUP_WEAPON_HAZARDCAN",
    joaat "PICKUP_WEAPON_NAVYREVOLVER",
    joaat "PICKUP_WEAPON_COMBATSHOTGUN",
    joaat "PICKUP_WEAPON_GADGETPISTOL",
    joaat "PICKUP_WEAPON_MILITARYRIFLE",
    joaat "PICKUP_WEAPON_FLAREGUN",
    joaat "PICKUP_AMMO_FLAREGUN",
    joaat "PICKUP_WEAPON_KNUCKLE",
    joaat "PICKUP_WEAPON_MARKSMANPISTOL",
    joaat "PICKUP_WEAPON_COMBATPDW",
    joaat "PICKUP_PORTABLE_CRATE_FIXED_INCAR",
    joaat "PICKUP_WEAPON_COMPACTRIFLE",
    joaat "PICKUP_WEAPON_DBSHOTGUN",
    joaat "PICKUP_WEAPON_MACHETE",
    joaat "PICKUP_WEAPON_MACHINEPISTOL",
    joaat "PICKUP_WEAPON_FLASHLIGHT",
    joaat "PICKUP_WEAPON_REVOLVER",
    joaat "PICKUP_WEAPON_SWITCHBLADE",
    joaat "PICKUP_WEAPON_AUTOSHOTGUN",
    joaat "PICKUP_WEAPON_BATTLEAXE",
    joaat "PICKUP_WEAPON_COMPACTLAUNCHER",
    joaat "PICKUP_WEAPON_MINISMG",
    joaat "PICKUP_WEAPON_PIPEBOMB",
    joaat "PICKUP_WEAPON_POOLCUE",
    joaat "PICKUP_WEAPON_WRENCH",
    joaat "PICKUP_WEAPON_ASSAULTRIFLE_MK2",
    joaat "PICKUP_WEAPON_CARBINERIFLE_MK2",
    joaat "PICKUP_WEAPON_COMBATMG_MK2",
    joaat "PICKUP_WEAPON_HEAVYSNIPER_MK2",
    joaat "PICKUP_WEAPON_PISTOL_MK2",
    joaat "PICKUP_WEAPON_SMG_MK2",
    joaat "PICKUP_WEAPON_STONE_HATCHET",
    joaat "PICKUP_WEAPON_METALDETECTOR",
    joaat "PICKUP_WEAPON_TACTICALRIFLE",
    joaat "PICKUP_WEAPON_PRECISIONRIFLE",
    joaat "PICKUP_WEAPON_EMPLAUNCHER",
    joaat "PICKUP_AMMO_EMPLAUNCHER",
    joaat "PICKUP_WEAPON_HEAVYRIFLE",
    joaat "PICKUP_WEAPON_PETROLCAN_SMALL_RADIUS"
}

-- Blacklisted texture dictionaries (vaak gebruikt door mod menu's)
local blacklistedTextures = {
    "fm",
    "rampage_tr_main",
    "MenyooExtras",
    "shopui_title_graphics_franklin",
    "deadline",
    "cockmenuu"
}

-- Bekende mod menu textures voor detectie
local menuTextures = {
    {
        txd = "HydroMenu",
        txt = "HydroMenuHeader",
        name = "HydroMenu"
    },
    {txd = "John", txt = "John2", name = "SugarMenu"},
    {txd = "darkside", txt = "logo", name = "Darkside"},
    {
        txd = "ISMMENU",
        txt = "ISMMENUHeader",
        name = "ISMMENU"
    },
    {
        txd = "dopatest",
        txt = "duiTex",
        name = "Copypaste Menu"
    },
    {txd = "fm", txt = "menu_bg", name = "Fallout Menu"},
    {txd = "wave", txt = "logo", name = "Wave"},
    {txd = "wave1", txt = "logo1", name = "Wave (alt.)"},
    {
        txd = "meow2",
        txt = "woof2",
        name = "Alokas66",
        x = 1000,
        y = 1000
    },
    {
        txd = "adb831a7fdd83d_Guest_d1e2a309ce7591dff86",
        txt = "adb831a7fdd83d_Guest_d1e2a309ce7591dff8Header6",
        name = "Guest Menu"
    },
    {
        txd = "hugev_gif_DSGUHDSGISDG",
        txt = "duiTex_DSIOGISDG",
        name = "HugeV Menu"
    },
    {
        txd = "MM",
        txt = "menu_bg",
        name = "Metrix Mehtods"
    },
    {txd = "wm", txt = "wm2", name = "WM Menu"},
    {
        txd = "NeekerMan",
        txt = "NeekerMan1",
        name = "Lumia Menu"
    },
    {
        txd = "Blood-X",
        txt = "Blood-X",
        name = "Blood-X Menu"
    },
    {
        txd = "Dopamine",
        txt = "Dopameme",
        name = "Dopamine Menu"
    },
    {
        txd = "Fallout",
        txt = "FalloutMenu",
        name = "Fallout Menu"
    },
    {
        txd = "Luxmenu",
        txt = "Lux meme",
        name = "LuxMenu"
    },
    {
        txd = "Reaper",
        txt = "reaper",
        name = "Reaper Menu"
    },
    {
        txd = "absoluteeulen",
        txt = "Absolut",
        name = "Absolut Menu"
    },
    {
        txd = "KekHack",
        txt = "kekhack",
        name = "KekHack Menu"
    },
    {
        txd = "Maestro",
        txt = "maestro",
        name = "Maestro Menu"
    },
    {
        txd = "SkidMenu",
        txt = "skidmenu",
        name = "Skid Menu"
    },
    {
        txd = "Brutan",
        txt = "brutan",
        name = "Brutan Menu"
    },
    {
        txd = "FiveSense",
        txt = "fivesense",
        name = "Fivesense Menu"
    },
    {
        txd = "NeekerMan",
        txt = "NeekerMan1",
        name = "Lumia Menu"
    },
    {
        txd = "Auttaja",
        txt = "auttaja",
        name = "Auttaja Menu"
    },
    {
        txd = "BartowMenu",
        txt = "bartowmenu",
        name = "Bartow Menu"
    },
    {txd = "Hoax", txt = "hoaxmenu", name = "Hoax Menu"},
    {
        txd = "FendinX",
        txt = "fendin",
        name = "Fendinx Menu"
    },
    {txd = "Hammenu", txt = "Ham", name = "Ham Menu"},
    {txd = "Lynxmenu", txt = "Lynx", name = "Lynx Menu"},
    {
        txd = "Oblivious",
        txt = "oblivious",
        name = "Oblivious Menu"
    },
    {
        txd = "malossimenuv",
        txt = "malossimenu",
        name = "Malossi Menu"
    },
    {
        txd = "memeeee",
        txt = "Memeeee",
        name = "Memeeee Menu"
    },
    {txd = "tiago", txt = "Tiago", name = "Tiago Menu"},
    {
        txd = "Hydramenu",
        txt = "hydramenu",
        name = "Hydra Menu"
    },
    {
        txd = "dopamine",
        txt = "Swagamine",
        name = "Dopamine"
    },
    {
        txd = "HydroMenu",
        txt = "HydroMenuHeader",
        name = "Hydro Menu"
    },
    {
        txd = "HydroMenu",
        txt = "HydroMenuLogo",
        name = "Hydro Menu"
    },
    {
        txd = "HydroMenu",
        txt = "https://i.ibb.co/0GhPPL7/Hydro-New-Header.png",
        name = "Hydro Menu"
    },
    {
        txd = "test",
        txt = "Terror Menu",
        name = "Terror Menu"
    },
    {
        txd = "lynxmenu",
        txt = "lynxmenu",
        name = "Lynx Menu"
    },
    {
        txd = "Maestro 2.3",
        txt = "Maestro 2.3",
        name = "Maestro Menu"
    },
    {
        txd = "ALIEN MENU",
        txt = "ALIEN MENU",
        name = "Alien Menu"
    },
    {
        txd = "~u~⚡️ALIEN MENU⚡️",
        txt = "~u~⚡️ALIEN MENU⚡️",
        name = "Alien Menu"
    }
}

-- Blacklisted commando's (vaak gebruikt door mod menu's)
local blacklistedCommands = {
    "killmenu",
    "chocolate",
    "pk",
    "haha",
    "lol",
    "panickey",
    "killmenu",
    "panik",
    "lynx",
    "brutan",
    "panic",
    "purgemenu"
}

-- Wapen schade referentietabel
local weaponDamageTable = {
    [-1357824103] = {damage = 34, name = "AdvancedRifle"},
    [453432689] = {damage = 26, name = "Pistol"},
    [1593441988] = {damage = 27, name = "CombatPistol"},
    [584646201] = {damage = 25, name = "APPistol"},
    [-1716589765] = {damage = 51, name = "Pistol50"},
    [-1045183535] = {damage = 160, name = "Revolver"},
    [-1076751822] = {damage = 28, name = "SNSPistol"},
    [-771403250] = {damage = 40, name = "HeavyPistol"},
    [137902532] = {damage = 34, name = "VintagePistol"},
    [324215364] = {damage = 21, name = "MicroSMG"},
    [736523883] = {damage = 22, name = "SMG"},
    [-270015777] = {damage = 23, name = "AssaultSMG"},
    [-1121678507] = {damage = 22, name = "MiniSMG"},
    [-619010992] = {damage = 27, name = "MachinePistol"},
    [171789620] = {damage = 28, name = "CombatPDW"},
    [487013001] = {damage = 58, name = "PumpShotgun"},
    [2017895192] = {damage = 40, name = "SawnoffShotgun"},
    [-494615257] = {damage = 32, name = "AssaultShotgun"},
    [-1654528753] = {damage = 14, name = "BullpupShotgun"},
    [984333226] = {damage = 117, name = "HeavyShotgun"},
    [-1074790547] = {damage = 30, name = "AssaultRifle"},
    [-2084633992] = {damage = 32, name = "CarbineRifle"},
    [-1063057011] = {damage = 32, name = "SpecialCarbine"},
    [2132975508] = {damage = 32, name = "BullpupRifle"},
    [1649403952] = {damage = 44, name = "CompactRifle"},
    [-1660422300] = {damage = 40, name = "MG"},
    [2144741730] = {damage = 45, name = "CombatMG"},
    [1627465347] = {damage = 34, name = "Gusenberg"},
    [100416529] = {damage = 101, name = "SniperRifle"},
    [205991906] = {damage = 216, name = "HeavySniper"},
    [-952879014] = {damage = 65, name = "MarksmanRifle"},
    [1119849093] = {damage = 30, name = "Minigun"},
    [-1466123874] = {damage = 165, name = "Musket"},
    [911657153] = {damage = 1, name = "StunGun"},
    [1198879012] = {damage = 10, name = "FlareGun"},
    [-598887786] = {damage = 220, name = "MarksmanPistol"},
    [1834241177] = {damage = 30, name = "Railgun"},
    [-275439685] = {damage = 30, name = "DoubleBarrelShotgun"},
    [-1746263880] = {
        damage = 81,
        name = "Double Action Revolver"
    },
    [-2009644972] = {damage = 30, name = "SNS Pistol Mk II"},
    [-879347409] = {
        damage = 200,
        name = "Heavy Revolver Mk II"
    },
    [-1768145561] = {
        damage = 32,
        name = "Special Carbine Mk II"
    },
    [-2066285827] = {damage = 33, name = "Bullpup Rifle Mk II"},
    [1432025498] = {damage = 32, name = "Pump Shotgun Mk II"},
    [1785463520] = {
        damage = 75,
        name = "Marksman Rifle Mk II"
    },
    [961495388] = {damage = 40, name = "Assault Rifle Mk II"},
    [-86904375] = {damage = 33, name = "Carbine Rifle Mk II"},
    [-608341376] = {damage = 47, name = "Combat MG Mk II"},
    [177293209] = {damage = 230, name = "Heavy Sniper Mk II"},
    [-1075685676] = {damage = 32, name = "Pistol Mk II"},
    [2024373456] = {damage = 25, name = "SMG Mk II"}
}

-- Event handlers array
local eventHandlers = {}

-- Voeg event handler toe aan tracking array
local function addEventHandler(handler)
    eventHandlers[#eventHandlers + 1] = handler
end

-- Verwijder alle event handlers
local function clearEventHandlers()
    for i, handler in pairs(eventHandlers) do
        RemoveEventHandler(handler)
    end
    eventHandlers = {}
end

-- Blacklisted ped taken
local blacklistedTasks = {100, 101, 151, 221, 222}

-- Blacklisted voertuig nummerplaten (vaak gebruikt door mod menu's)
local blacklistedPlates = {
    "Desudo",
    "LynxMenu",
    "AKTeam",
    "Ancient",
    "BRUTAN",
    "Brutan#7799",
    "AlikhanMenu",
    "GEJ",
    "LYNX",
    "CK GANG",
    "Tiago",
    "Swag Menu",
    "HamHaxia",
    "eulencheats",
    "EulenMenu",
    "Falcon",
    "GEJ",
    "Shadow",
    "AlphaV",
    "Luminous",
    "Lux Menu",
    "Malossi Menu V3",
    "Malossi",
    "obl2",
    "S1MLLER",
    "iSeekFR",
    "Skaza",
    "TITOModz",
    "ZajacMenu",
    "Menuxdhf798230fsdf3df Menu"
}

-- Blacklisted animaties
local blacklistedAnims = {
    {
        "rcmpaparazzi_2",
        "shag_loop_poppy"
    }
}

-- Blacklisted globale variabelen (vaak gebruikt door mod menu's)
local blacklistedVariables = {
    "nexus",
    "WarMenu",
    "AlikhanCheats",
    "gaybuild",
    "Plane",
    "LynxEvo",
    "FendinX",
    "LR",
    "Lynx8",
    "MIOddhwuie",
    "ililililil",
    "esxdestroyv2",
    "LiLLL",
    "obl2",
    "HamMafia",
    "Absolute",
    "Absolute_function",
    "TiagoMenu",
    "SkazaMenu",
    "BrutanPremium",
    "b00mMenu",
    "Cience",
    "MaestroMenu",
    "Crusader",
    "NertigelFunc",
    "dreanhsMod",
    "nukeserver",
    "SDefwsWr",
    "FlexSkazaMenu",
    "DynnoFamily",
    "FrostedMenu",
    "frosted_config",
    "FXMenu",
    "CKgang",
    "HoaxMenu",
    "alkomenu",
    "xseira",
    "KoGuSzEk",
    "LynxSeven",
    "lynxunknowncheats",
    "MaestroEra",
    "foriv",
    "ariesMenu",
    "Ham",
    "Outcasts666",
    "b00mek",
    "redMENU",
    "rootMenu",
    "xnsadifnias",
    "LDOWJDWDdddwdwdad",
    "moneymany",
    "FlexSkazaMenu",
    "VOITUREMenu",
    "fESX",
    "dexMenu",
    "zzzt",
    "AKTeam",
    "SwagMenu",
    "Gatekeeper",
    "Dopameme",
    "Lux",
    "Swag",
    "SwagUI",
    "Nisi",
    "nigmenu0001",
    "Motion",
    "MMenu",
    "FantaMenuEvo",
    "GRubyMenu",
    "InSec",
    "AlphaVeta",
    "ShaniuMenu",
    "HamHaxia",
    "FendinXMenu",
    "AlphaV",
    "Deer",
    "NyPremium",
    "lIlIllIlI",
    "OnionUI",
    "qJtbGTz5y8ZmqcAg",
    "LuxUI",
    "JokerMenu",
    "IlIlIlIlIlIlI",
    "SidMenu",
    "GheMenu",
    "INFINITY",
    "klVZJu56hiZnIjg88ekXcEgegjfDvuMv83grKxQiUJJFvN8SHENeK2WaRgTTuafpGe",
    "jailServerLoop",
    "carSpamServer",
    "Dopamine",
    "nofuckinglol"
}

-- Blacklisted events (vaak misbruikt)
local blacklistedEvents = {
    "neweden_garage:pay",
    "projektsantos:mandathajs",
    "esx_dmvschool:pay"
}

-- Registreer netwerk events
RegisterNetEvent(
    encodeEvent "Anticheat:setActive",
    function(isActive)
        anticheatActive = isActive
        if isActive then
            runSafely(activate, "Activator")
        else
            runSafely(deactivate, "Deactivator")
        end
    end
)

-- Initialiseer anticheat
Citizen.CreateThread(
    function()
        TriggerServerEvent(
            encodeEvent "Anticheat:requestIntialization"
        )
    end
)

RegisterNetEvent(
    encodeEvent "Anticheat:setConfig",
    function(newConfig)
        for i, entity in pairs(newConfig.modules.antiPed.whitelist) do
            whitelistedPeds[joaat(entity)] = true
        end
        for i, entity in pairs(newConfig.modules.antiVehicle.blacklist) do
            blacklistedVehicles[joaat(entity)] = true
        end
        for i, entity in pairs(newConfig.modules.antiWeapon.blacklist) do
            blacklistedWeapons[joaat(entity)] = true
        end
        config = newConfig
        SendNUIMessage(
            {onScreenDetection = config.modules.antiMenuOCR.enabled, onScreenKeywords = config.modules.antiMenuOCR.blacklist}
        )
    end
)

function quitGame()
    ForceSocialClubUpdate()
end

-- Controleer of speler is gespawned
runSafely(
    function()
        while not NetworkIsPlayerActive(playerId) do
            Wait(100)
        end
        playerInitialized = true
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        while coords.x == 0.0 or coords.y == 0.0 do
            ped = PlayerPedId()
            coords = GetEntityCoords(ped)
            Wait(0)
        end
        Wait(0)
        local camCoords = GetFinalRenderedCamCoord()
        while #(camCoords - coords) > 50.0 do
            camCoords = GetFinalRenderedCamCoord()
            ped = PlayerPedId()
            coords = GetEntityCoords(ped)
            Wait(0)
        end
        ped = PlayerPedId()
        lastPosition = GetEntityCoords(ped)
        playerSpawned = true
    end,
    "SpawnChecker"
)

local stateBagHandler
function activate()
    clearEventHandlers()
    debug.log("Anticheat activated")
    waitForConfig()
    if config.modules.antiPickup.enabled then
        for i = 1, #blacklistedPickups do
            ToggleUsePickupsForPlayer(playerId, blacklistedPickups[i], false)
        end
    end
    if config.modules.antiDamageChanger then
        for weaponHash, isBlacklisted in pairs(blacklistedWeapons) do
            SetWeaponDamageModifier(weaponHash, 0.0)
        end
    end
    if config.modules.antiVDM.enabled then
        SetWeaponDamageModifier(-1553120962, 0.0)
    end
    
    addEventHandler(
        AddEventHandler(
            "antilynx8:crashuser",
            function()
                waitForConfig()
                if config.modules.antiMenu.enabled then
                    punishFromClient(
                        "antiMenu",
                        "Menu detected"
                    )
                end
            end
        )
    )
    
    addEventHandler(
        AddEventHandler(
            "shilling=yet5",
            function()
                waitForConfig()
                if config.modules.antiMenu.enabled then
                    punishFromClient(
                        "antiMenu",
                        "Menu detected"
                    )
                end
            end
        )
    )
    
    addEventHandler(
        AddEventHandler(
            "antilynxr4:crashuser",
            function()
                waitForConfig()
                if config.modules.antiMenu.enabled then
                    punishFromClient(
                        "antiMenu",
                        "Menu detected"
                    )
                end
            end
        )
    )
    
    addEventHandler(
        AddEventHandler(
            "shilling=yet7",
            function()
                waitForConfig()
                if config.modules.antiMenu.enabled then
                    punishFromClient(
                        "antiMenu",
                        "Menu detected"
                    )
                end
            end
        )
    )
    
    addEventHandler(
        AddEventHandler(
            "antilynxr4:crashuser1",
            function()
                waitForConfig()
                if config.modules.antiMenu.enabled then
                    punishFromClient(
                        "antiMenu",
                        "Menu detected"
                    )
                end
            end
        )
    )
    
    addEventHandler(
        AddEventHandler(
            "HCheat:TempDisableDetection",
            function()
                waitForConfig()
                if config.modules.antiMenu.enabled then
                    punishFromClient(
                        "antiMenu",
                        "Tried to disable detection"
                    )
                end
            end
        )
    )
    
    if stateBagHandler then
        RemoveStateBagChangeHandler(stateBagHandler)
    end
    
    stateBagHandler =
        AddStateBagChangeHandler(
        nil,
        nil,
        function(bagName, key, value)
            waitForConfig()
            if config.modules.antiCrasher.enabled then
                if #value > 131072 then
                    punishFromClient(
                        "antiCrasher",
                        "Tried to Crash the Server"
                    )
                    quitGame()
                    while true do
                    end
                end
            end
        end
    )
end

function deactivate()
    clearEventHandlers()
    debug.log("Anticheat deactivated")
    waitForConfig()
    if config.modules.antiDamageChanger then
        for weaponHash, isBlacklisted in pairs(blacklistedWeapons) do
            SetWeaponDamageModifier(weaponHash, -1.0)
        end
    end
    if config.modules.antiVDM.enabled then
        SetWeaponDamageModifier(-1553120962, -1.0)
    end
    if stateBagHandler then
        RemoveStateBagChangeHandler(stateBagHandler)
    end
end

-- Functie voor het berekenen van kijkrichting
local function getDirectionFromRotation(rotation)
    local adjustedRotation = {x = math.rad(rotation.x), y = math.rad(rotation.y), z = math.rad(rotation.z)}
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

-- Functie voor raycast met materiaal detectie
local function raycastWithMaterial(distance)
    local camRot = GetGameplayCamRot()
    local camPos = GetGameplayCamCoord()
    local direction = getDirectionFromRotation(camRot)
    local destination = {x = camPos.x + direction.x * distance, y = camPos.y + direction.y * distance, z = camPos.z + direction.z * distance}
    local rayHandle, hit, endCoords, surfaceNormal, materialHash, entity =
        GetShapeTestResultIncludingMaterial(StartShapeTestRay(camPos.x, camPos.y, camPos.z, destination.x, destination.y, destination.z, -1, -1, 1))
    local rayDistance
    if endCoords then
        rayDistance = #(camPos - endCoords)
    end
    return hit, endCoords, entity, materialHash, rayDistance
end

-- Functie voor raycast zonder materiaal detectie
local function raycast(distance)
    local camRot = GetGameplayCamRot()
    local camPos = GetGameplayCamCoord()
    local direction = getDirectionFromRotation(camRot)
    local destination = {x = camPos.x + direction.x * distance, y = camPos.y + direction.y * distance, z = camPos.z + direction.z * distance}
    local rayHandle, hit, endCoords, surfaceNormal, entity = GetShapeTestResult(StartShapeTestRay(camPos.x, camPos.y, camPos.z, destination.x, destination.y, destination.z, -1, -1, 1))
    local rayDistance
    if endCoords then
        rayDistance = #(camPos - endCoords)
    end
    return hit, endCoords, entity, entity, rayDistance
end

-- Aimbot detectie data
local aimPositions = {}

-- Event handler voor entity damage
AddEventHandler(
    "entityDamaged",
    function(entity, attacker, weaponHash)
        waitForConfig()
        local ped = PlayerPedId()
        if config.modules.antiWallHack.enabled then
            if entity and attacker and entity ~= attacker and attacker == ped then
                if IsPedShooting(attacker) then
                    if IsEntityAPed(entity) then
                        local noLineOfSight = not HasEntityClearLosToEntity(attacker, entity)
                        local noLineOfSightWithWeapon = not HasEntityClearLosToEntity(attacker, entity, 17)
                        if noLineOfSight then
                            CancelEvent()
                        end
                        if noLineOfSight and noLineOfSightWithWeapon then
                            CancelEvent()
                            punishFromClient(
                                "antiWallHack",
                                "Player didn't have line of sight to entity"
                            )
                        end
                        local hit, endCoords, hitEntity, materialHash = raycastWithMaterial(1000.0)
                        if hit then
                            if not materialHash then
                                CancelEvent()
                                punishFromClient(
                                    "antiWallHack",
                                    "Shot trough wall"
                                )
                            end
                        end
                    end
                end
            end
        end
    end
)

-- Anti soft aim
local softAimActive = false
runPeriodically(
    0,
    function()
        if config.modules.antiSoftAim.enabled then
            local ped = PlayerPedId()
            if IsPedArmed(ped, 1) then
                softAimActive = true
                SetPlayerLockonRangeOverride(playerId, -1.0)
            else
                if softAimActive then
                    softAimActive = false
                    SetPlayerLockonRangeOverride(playerId, 0.0)
                end
                Wait(100)
            end
        end
    end,
    "AntiSoftAim"
)

-- Speler permissies
RegisterNetEvent(
    encodeEvent "Anticheat:setPermissions",
    function(permissions, isDebug)
        playerPermissions = permissions
        debugMode = isDebug
        if debugMode then
            debug.log("permissions:" .. json.encode(playerPermissions))
            RegisterCommand(
                "eacunwhitelist",
                function()
                    playerPermissions.Whitelisted = false
                    debug.log("unwhitelisted")
                end
            )
            RegisterCommand(
                "eacwhitelist",
                function()
                    playerPermissions.Whitelisted = true
                    debug.log("whitelisted")
                end
            )
        end
    end
)

-- Variabelen voor verschillende detecties
local lastUnderMapCheck = -9999999
local lastPosition
local teleportPositions = {}
local lastCoords
local lastNoClipTime = -math.huge
local noClipDetections = 0
local teleportPositionList = {}
local lastTeleportCheck
local teleportDetections = 0
local godmodeDetections = 0
local invisibilityDetections = 0
local staminaDetections = 0
local aimPositionHistory = {}
local lastSavedPosition
local lastSavedVelocity
local wasInAir
local speedHackDetections = 0
local isOutOfStamina = false

-- Periodieke controles voor verschillende cheats
runPeriodically(
    300,
    function()
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        if not lastSavedPosition then
            lastSavedPosition = coords
        end
        local groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, 99999.0, false)
        
        -- Anti under map
        if config.modules.antiUnderMap.enabled then
            local lastZ = lastSavedPosition.z
            local fallVelocity = -0.1
            if groundZ < 1000 then
                if IsPedInAnyVehicle(ped) then
                    local vehicle = GetVehiclePedIsUsing(ped)
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local vehicleHeight = GetEntityHeightAboveGround(vehicle)
                    if vehicleHeight < 1000 then
                        local velocity = GetEntityVelocity(vehicle)
                        if vehicleCoords.z < groundZ and vehicleHeight == vehicleCoords.z and velocity.z < 0 then
                            if invisibilityDetections < 1 then
                                SetEntityCoords(vehicle, vehicleCoords.x, vehicleCoords.y, lastSavedPosition.z + invisibilityDetections * 0.1)
                                SetEntityVelocity(vehicle, velocity.x, velocity.y, fallVelocity)
                                lastUnderMapCheck = GetGameTimer()
                                invisibilityDetections = invisibilityDetections + 1
                            elseif invisibilityDetections < 3 and lastSavedVelocity then
                                SetEntityCoords(vehicle, lastSavedVelocity.x, lastSavedVelocity.y, lastSavedVelocity.z + invisibilityDetections * 0.1)
                                SetEntityVelocity(vehicle, velocity.x, velocity.y, fallVelocity)
                                lastUnderMapCheck = GetGameTimer()
                                invisibilityDetections = invisibilityDetections + 1
                            else
                                if invisibilityDetections < 5 then
                                    SetEntityCoords(vehicle, vehicleCoords.x, vehicleCoords.y, groundZ)
                                    lastUnderMapCheck = GetGameTimer()
                                end
                                invisibilityDetections = invisibilityDetections + 1
                            end
                        else
                            invisibilityDetections = 0
                            lastSavedVelocity = vehicleCoords
                        end
                    end
                else
                    local velocity = GetEntityVelocity(ped)
                    local pedHeight = GetEntityHeightAboveGround(ped)
                    if pedHeight < 1000 then
                        if coords.z < groundZ and pedHeight == coords.z and velocity.z < 0 then
                            if invisibilityDetections < 1 then
                                SetEntityCoords(ped, coords.x, coords.y, lastZ - 0.99 + invisibilityDetections * 0.1)
                                SetEntityVelocity(ped, velocity.x, velocity.y, fallVelocity)
                                lastUnderMapCheck = GetGameTimer()
                                invisibilityDetections = invisibilityDetections + 1
                            elseif invisibilityDetections < 3 and lastSavedVelocity then
                                SetEntityCoords(ped, lastSavedPosition.x, lastSavedPosition.y, lastZ - 0.99 + invisibilityDetections * 0.1)
                                SetEntityVelocity(ped, velocity.x, velocity.y, fallVelocity)
                                lastUnderMapCheck = GetGameTimer()
                                invisibilityDetections = invisibilityDetections + 1
                            else
                                if invisibilityDetections < 5 then
                                    SetEntityCoords(ped, coords.x, coords.y, groundZ)
                                    lastUnderMapCheck = GetGameTimer()
                                end
                                invisibilityDetections = invisibilityDetections + 1
                            end
                        else
                            invisibilityDetections = 0
                            lastSavedVelocity = coords
                        end
                    end
                end
            end
        end
        
        -- Anti aimbot
        if config.modules.antiAimbot.enabled then
            local hasTarget, targetEntity = GetEntityPlayerIsFreeAimingAt(playerId)
            if hasTarget and targetEntity and ped and targetEntity ~= ped then
                if GetEntitySpeed(targetEntity) >= 1.5 or GetEntitySpeed(ped) >= 1.5 and IsPedArmed(ped, 6) and IsPlayerFreeAiming(playerId) then
                    local hit, endCoords, entity, materialHash, distance = raycast(1000.0)
                    if hit then
                        local targetRotation = GetEntityRotation(targetEntity, 2)
                        local pedRotation = GetEntityRotation(ped, 2)
                        local targetCoords = GetEntityCoords(targetEntity)
                        local distanceToTarget = #(coords - targetCoords)
                        if distanceToTarget > 5.0 then
                            local targetYaw = math.rad(targetRotation.z)
                            local relativePos = endCoords - targetCoords
                            local transformedPos =
                                vector3(
                                relativePos.x * math.cos(targetYaw) + relativePos.y * math.sin(targetYaw),
                                relativePos.x * math.sin(targetYaw) - relativePos.y * math.cos(targetYaw),
                                relativePos.z
                            )
                            if #aimPositionHistory >= 20 then
                                table.remove(aimPositionHistory, 20)
                            end
                            table.insert(aimPositionHistory, 1, {pos = transformedPos, dist = distance})
                            local consecutiveHits = 0
                            local lastPos
                            for i, pos in pairs(aimPositionHistory) do
                                if lastPos then
                                    local posDiff =
                                        #(vector3(lastPos.pos.x / 10, lastPos.pos.y / 10, lastPos.pos.z) -
                                        vector3(pos.pos.x / 10, pos.pos.y / 10, pos.pos.z))
                                    if posDiff <= math.min(math.min(pos.dist - 10, 2) * 0.0015, 0.05) then
                                        consecutiveHits = consecutiveHits + 1
                                    end
                                    if consecutiveHits >= 3 then
                                        teleportDetections = teleportDetections + 1
                                        if teleportDetections > 3 then
                                            punishFromClient(
                                                "antiAimbot",
                                                "Player locked on to entity while aiming"
                                            )
                                            teleportDetections = 0
                                        end
                                        consecutiveHits = 0
                                    end
                                end
                                lastPos = pos
                            end
                        end
                    end
                end
            end
        end
        
        -- Meer aimbot detectie
        if config.modules.antiAimbot.enabled then
            if
                GetScriptTaskStatus(ped, 3641635208) == 1 or GetScriptTaskStatus(ped, 167901368) == 1 or
                    GetScriptTaskStatus(ped, 167901369) == 1
             then
                punishFromClient(
                    "antiAimbot",
                    "Aimbot detected, aimbot task"
                )
            end
        end
        
        -- Anti noclip
        if config.modules.antiNoclip.enabled then
            local pedHeight = GetEntityHeightAboveGround(ped)
            local isOnVehicle = IsPedOnVehicle(ped)
            local ignoreChecks = false
            if lastCoords then
                local distanceMoved = #(lastCoords - coords)
                if distanceMoved > 150.0 then
                    noClipDetections = 0
                    lastNoClipTime = GetGameTimer()
                end
            end
            if GetGameTimer() - lastNoClipTime < 6000 then
                ignoreChecks = true
            end
            if not ignoreChecks then
                if
                    coords ~= lastPosition and lastPosition ~= nil and pedHeight > 3.0 and not IsPedJumpingOutOfVehicle(ped) and not IsPedClimbing(ped) and
                        IsPedOnFoot(ped) and
                        not IsPedRagdoll(ped) and
                        not IsPedSwimming(ped) and
                        GetGameTimer() - lastUnderMapCheck > 5000
                 then
                    local parachuteState = GetPedParachuteState()
                    if not IsPedJumping(ped) and not isOnVehicle and parachuteState ~= 2 and parachuteState ~= 1 then
                        if #teleportPositions >= 5 then
                            table.remove(teleportPositions, 5)
                        end
                        table.insert(teleportPositions, 1, coords)
                        if #teleportPositions >= 5 then
                            local lastHeight = -9999.9
                            local ascendCount = 0
                            local totalDistance = 0
                            local lastPos
                            local sameHeightCount = 0
                            for i = #teleportPositions, 1, -1 do
                                local pos = teleportPositions[i]
                                if lastPos then
                                    totalDistance = totalDistance + #(pos - lastPos)
                                end
                                lastPos = pos
                                if pos.z > lastHeight + 0.05 then
                                    lastHeight = pos.z
                                    ascendCount = ascendCount + 1
                                end
                                if pos.z == lastHeight then
                                    sameHeightCount = sameHeightCount + 1
                                end
                                lastHeight = pos.z
                                if ascendCount >= 3 and totalDistance > 4.0 and pedHeight > 2.0 or sameHeightCount >= 3 and pedHeight >= 10.0 and coords.z > 0.0 then
                                    noClipDetections = noClipDetections + 1
                                    teleportPositions = {}
                                    if groundZ < 1000 then
                                        SetEntityCoords(ped, coords.x, coords.y, groundZ)
                                    end
                                    if noClipDetections >= 2 then
                                        noClipDetections = 0
                                        punishFromClient(
                                            "antiNoclip",
                                            "Noclip detected"
                                        )
                                    end
                                    break
                                end
                            end
                        end
                    end
                else
                    teleportPositions = {}
                end
            end
            lastCoords = coords
        end
        
        -- Anti teleport
        if config.modules.antiTeleport.enabled then
            if lastTeleportCheck then
                if IsPedOnFoot(ped) then
                    local distance = #(vector2(coords.x, coords.y) - vector2(lastTeleportCheck.x, lastTeleportCheck.y))
                    if distance > 50.0 then
                        if
                            not IsScreenFadedOut() and not IsScreenFadingIn() and not IsScreenFadingOut() and
                                GetGameTimer() - lastUnderMapCheck > 1000
                         then
                            lastTeleportTime = GetGameTimer()
                            table.insert(teleportPositionList, 1, coords)
                            local uniquePositions = 0
                            if #teleportPositionList >= 3 then
                                local positionHashes = {}
                                for i, pos in pairs(teleportPositionList) do
                                    local hash = math.floor(pos.x / 15 + pos.y / 15 + pos.z / 15)
                                    if not positionHashes[hash] then
                                        positionHashes[hash] = true
                                        uniquePositions = uniquePositions + 1
                                    end
                                end
                                if uniquePositions >= 4 then
                                    teleportPositionList = {}
                                    punishFromClient(
                                        "antiTeleport",
                                        "Used Teleport Hacks"
                                    )
                                end
                            end
                        end
                    end
                else
                    teleportPositionList = {}
                end
            end
            if IsPlayerDead(playerId) then
                teleportPositionList = {}
            end
            if GetGameTimer() - lastTeleportTime > 20000 then
                teleportPositionList = {}
            end
            lastTeleportCheck = coords
        end
        
        -- Anti license clear
        if config.modules.antiLicenseClear.enabled then
            if ForceSocialClubUpdate == nil then
                punishFromClient(
                    "antiLicenseClear",
                    "Player tried to clear his License (social club)"
                )
            end
            if ShutdownAndLaunchSinglePlayerGame == nil then
                punishFromClient(
                    "antiLicenseClear",
                    "Player tried to clear his License (single player)"
                )
            end
            if ActivateRockstarEditor == nil then
                punishFromClient(
                    "antiLicenseClear",
                    "Player tried to clear his License (rockstar editor)"
                )
            end
        end
        lastSavedPosition = coords
    end,
    "ShortCheck"
)

-- Registreer netwerk events
RegisterNetEvent(GetCurrentResourceName() .. ".verify")
RegisterNetEvent("antilynx8:crashuser")
RegisterNetEvent("shilling=yet5")
RegisterNetEvent("antilynxr4:crashuser")
RegisterNetEvent("shilling=yet7")
RegisterNetEvent("antilynxr4:crashuser1")
RegisterNetEvent("HCheat:TempDisableDetection")

-- Event handler voor verify event
AddEventHandler(
    GetCurrentResourceName() .. ".verify",
    function()
        waitForConfig()
        if config.modules.antiInjector.enabled then
            punishFromClient(
                "antiInjector",
                "Injector detected"
            )
        end
    end
)

-- Event handlers voor blacklisted events
for i, eventName in pairs(blacklistedEvents) do
    RegisterNetEvent(eventName)
    AddEventHandler(
        eventName,
        function(amount)
            if config.modules.antiMenu.enabled then
                if amount < 0 then
                    punishFromClient(
                        "antiMenu",
                        "Menu detected (negative pay event)"
                    )
                end
            end
        end
    )
end

-- Variabelen voor voertuig controles
local explosionHash = joaat("WEAPON_EXPLOSION")
local wasInvisible = false
local lastVehicleCoords = vector3(0, 0, 0)
local lastSavedVehicle
local speedHackDetections = 0
local godmodeDetections = 0
local invisibilityDetections = 0
local staminaDetections = 0
local isOutOfStamina = false

-- Periodieke controles voor verschillende cheats
runPeriodically(
    1000,
    function()
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local players = GetActivePlayers()
        local pedHealth = GetEntityHealth(ped)
        local pedArmor = GetPedArmour(ped)
        local vehicle = GetVehiclePedIsUsing(ped)
        
        -- Anti aim assist
        if config.modules.antiAimAssist.enabled then
            if NetworkGetTargetingMode() ~= 3 or GetLocalPlayerAimState() ~= 3 then
                SetPlayerTargetingMode(3)
            end
        end
        
        -- Anti ammo
        if config.modules.antiAmmo.enabled then
            SetPedInfiniteAmmoClip(ped, false)
            if IsPedArmed(ped, 6) then
                local weaponHash = GetSelectedPedWeapon(ped)
                local success, ammoInClip = GetAmmoInClip(ped, weaponHash)
                local maxAmmoSuccess, maxAmmo = GetMaxAmmo(ped, weaponHash)
                local totalAmmo = GetAmmoInPedWeapon(ped, weaponHash)
                if not whitelistedWeapons[weaponHash] then
                    if ammoInClip > 499 or maxAmmo > 499 then
                        SetPedAmmo(ped, weaponHash, 0)
                        RemoveWeaponFromPed(ped, weaponHash)
                        punishFromClient(
                            "antiAmmo",
                            "Used infinite ammo"
                        )
                    end
                end
                if totalAmmo > maxAmmo or totalAmmo == -1 then
                    SetPedAmmo(ped, weaponHash, 0)
                    RemoveWeaponFromPed(ped, weaponHash)
                    punishFromClient(
                        "antiAmmo",
                        "Weapon was loaded with " .. totalAmmo .. " bullets"
                    )
                end
            end
        end
        
        -- Anti super jump
        if config.modules.antiSuperJump.enabled then
            local isJumping = IsPedJumping(ped)
            if isJumping then
                TriggerServerEvent(
                    encodeEvent "Anticheat:CheckJumping"
                )
            end
            if IsPedDoingBeastJump(ped) then
                punishFromClient(
                    "antiSuperJump",
                    "Tried to use superjump hacks"
                )
            end
        end
        
        -- Anti spectate
        if config.modules.antiSpectate.enabled then
            if NetworkIsInSpectatorMode() then
                punishFromClient(
                    "antiSpectate",
                    "Spectated another player"
                )
            end
        end
        
        -- Anti health
        if config.modules.antiHealth.enabled then
            if pedHealth > config.modules.antiHealth.max then
                punishFromClient(
                    "antiHealth",
                    "Used health hacks : " .. pedHealth
                )
            end
        end
        
        -- Anti armor
        if config.modules.antiArmor.enabled then
            if pedArmor > config.modules.antiArmor.max then
                punishFromClient(
                    "antiArmor",
                    "Used armor hacks: " .. pedArmor
                )
            end
        end
        
        -- Anti weapon
        if config.modules.antiWeapon.enabled then
            for weaponHash, isBlacklisted in pairs(blacklistedWeapons) do
                if HasPedGotWeapon(ped, weaponHash, false) then
                    RemoveWeaponFromPed(ped, weaponHash)
                    punishFromClient(
                        "antiWeapon",
                        "Used blacklisted weapon: " .. weaponHash
                    )
                end
            end
        end
        
        -- Anti godmode
        if config.modules.antiGodmode.enabled then
            if vehicle then
                if not GetEntityCanBeDamaged(vehicle) then
                    SetEntityCanBeDamaged(vehicle, true)
                end
            end
            if not GetEntityCanBeDamaged(ped) then
                SetEntityCanBeDamaged(ped, true)
                godmodeDetections = godmodeDetections + 1
                if godmodeDetections > 3 then
                    godmodeDetections = 0
                    punishFromClient(
                        "antiGodmode",
                        "Godmode hacks detected"
                    )
                end
            end
            if (GetPlayerInvincible(playerId) or GetPlayerInvincible_2(playerId)) and not IsEntityPositionFrozen(ped) then
                SetEntityInvincible(ped, false)
                SetEntityCanBeDamaged(ped, true)
                godmodeDetections = godmodeDetections + 1
                if godmodeDetections > 3 then
                    godmodeDetections = 0
                    punishFromClient(
                        "antiGodmode",
                        "Godmode hacks detected"
                    )
                end
            end
            local bulletProof, fireProof, explosionProof, collisionProof, meleeProof, steamProof, p7, drownProof = GetEntityProofs(ped)
            if fireProof == 1 or explosionProof == 1 or steamProof == 1 or p7 == 1 or drownProof == 1 then
                SetEntityProofs(ped, false, false, false, false, false, false, false, false)
            end
        end
        
        -- Anti stamina
        if config.modules.antiStamina.enabled then
            local pedHeight = GetEntityHeightAboveGround(ped)
            if
                GetEntitySpeed(ped) > 7 and not vehicle and not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped) and
                    not IsPedJumpingOutOfVehicle(ped) and
                    not IsPedRagdoll(ped) and
                    not IsEntityInAir(ped) and
                    not IsPedDeadOrDying(ped) and
                    pedHeight <= 1.0
             then
                local staminaRemaining = GetPlayerSprintStaminaRemaining(playerId)
                local velocity = GetEntityVelocity(ped)
                local speed = #vector2(velocity.x, velocity.y)
                local normalizedVelocity = vector2(velocity.x, velocity.y) * 6 / speed
                SetEntityVelocity(ped, normalizedVelocity.x, normalizedVelocity.y, normalizedVelocity.z)
                if staminaRemaining == 0.0 then
                    if isOutOfStamina then
                        staminaDetections = staminaDetections + 1
                        if staminaDetections > 2 then
                            staminaDetections = 0
                            punishFromClient(
                                "antiStamina",
                                "Used stamina hacks"
                            )
                        end
                    end
                    isOutOfStamina = true
                else
                    isOutOfStamina = false
                end
            end
        end
        
        -- Anti night vision
        if config.modules.antiNightVision.enabled then
            if GetUsingnightvision(true) and not IsPedInAnyHeli(ped) then
                punishFromClient(
                    "antiNightVision",
                    "Used night vision hack"
                )
            end
        end
        
        -- Anti thermal vision
        if config.modules.antiThermalVision.enabled then
            if GetUsingseethrough(true) and not IsPedInAnyHeli(ped) then
                punishFromClient(
                    "antiThermalVision",
                    "Used thermal vision hack"
                )
            end
        end
        
        -- Anti invisible
        if config.modules.antiInvisible.enabled then
            if not IsEntityVisible(ped) or GetEntityAlpha(ped) == 0 and playerSpawned then
                if
                    HasModelLoaded(joaat("mp_f_freemode_01")) and
                        HasModelLoaded(joaat("mp_m_freemode_01"))
                 then
                    SetEntityVisible(ped, true)
                    ResetEntityAlpha(ped)
                    invisibilityDetections = invisibilityDetections + 1
                    if invisibilityDetections > 4 then
                        invisibilityDetections = 0
                        punishFromClient(
                            "antiInvisible",
                            "Used invisibility exploits"
                        )
                    end
                end
            end
        end
        
        -- Anti plate
        if config.modules.antiPlate.enabled then
            if vehicle then
                for i, plate in ipairs(blacklistedPlates) do
                    local vehiclePlate = GetVehicleNumberPlateText(vehicle, false)
                    if vehiclePlate == plate then
                        punishFromClient(
                            "antiPlate",
                            "Used blacklisted plate : " .. plate .. ""
                        )
                    end
                end
            end
        end
        
        -- Anti damage changer
        if config.modules.antiDamageChanger.enabled then
            local weaponHash = GetSelectedPedWeapon(ped)
            if weaponHash then
                local weaponDamage = math.floor(GetWeaponDamage(weaponHash))
                if weaponDamage then
                    local weaponInfo = weaponDamageTable[weaponHash]
                    if weaponInfo then
                        if weaponDamage > weaponInfo.damage then
                            punishFromClient(
                                "antiDamageChanger",
                                "Tried to change " .. weaponInfo.name .. " damage to " .. weaponDamage
                            )
                        end
                    end
                end
            end
        end
        
        -- Anti horn boost
        if config.modules.antiHornBoost.enabled then
            if vehicle then
                local vehicleModel = GetEntityModel(vehicle)
                if
                    GetHasRocketBoost(vehicle) and vehicleModel ~= 989294410 and vehicleModel ~= 884483972 and vehicleModel ~= -638562243 and
                        vehicleModel ~= 2069146067
                 then
                    if IsVehicleRocketBoostActive(vehicle) then
                        punishFromClient(
                            "antiHornBoost",
                            "Player tried to hornboost"
                        )
                    end
                end
            end
        end
        
        -- Anti explosive weapon
        if config.modules.antiExplosiveWeapon.enabled then
            SetWeaponDamageModifier(explosionHash, 0.0)
            local weaponHash = GetSelectedPedWeapon(ped)
            local damageType = GetWeaponDamageType(weaponHash)
            if damageType == 4 or damageType == 5 or damageType == 6 or damageType == 13 then
                punishFromClient(
                    "antiExplosiveWeapon",
                    "Tried to use explosive weapon damage"
                )
            end
        end
        
        -- Anti ped
        if config.modules.antiPed.enabled then
            local pedModel = GetEntityModel(ped)
            if not whitelistedPeds[pedModel] then
                punishFromClient(
                    "antiPed",
                    "Tried to change ped to " .. pedModel .. "!"
                )
            end
        end
        
        -- Anti ped tasks
        if config.modules.antiPedTasks.enabled then
            for i, taskId in pairs(blacklistedTasks) do
                if GetIsTaskActive(ped, taskId) then
                    ClearPedTasksImmediately(ped)
                    ClearPedTasks(ped)
                    ClearPedSecondaryTask(ped)
                    punishFromClient(
                        "antiPedTasks",
                        "Tried to play task " .. taskId
                    )
                end
            end
        end
        
        -- Anti anims
        if config.modules.antiAnims.enabled then
            for i, anim in pairs(blacklistedAnims) do
                if IsEntityPlayingAnim(ped, anim[1], anim[2], 3) then
                    ClearPedTasksImmediately(ped)
                    ClearPedTasks(ped)
                    ClearPedSecondaryTask(ped)
                    punishFromClient(
                        "antiAnims",
                        "Tried to play blacklisted animation " .. anim[1] .. " and " .. anim[2] .. ""
                    )
                end
            end
        end
        
        -- Anti tiny ped
        if config.modules.antiPed.enabled then
            local isTinyPed = GetPedConfigFlag(ped, 223, true)
            if isTinyPed then
                punishFromClient(
                    "antiPed",
                    "Tried to turn into tiny ped"
                )
            end
        end
        
        -- Anti vehicle weapons
        if config.modules.antiVehicleWeapons.enabled then
            if IsPedInAnyVehicle(ped) then
                if DoesVehicleHaveWeapons(vehicle) then
                    for i, weaponHash in pairs(
                        {
                            2971687502,
                            1945616459,
                            3450622333,
                            3530961278,
                            1259576109,
                            4026335563,
                            1566990507,
                            1186503822,
                            2669318622,
                            3473446624,
                            4171469727,
                            1741783703,
                            2211086889
                        }
                    ) do
                        DisableVehicleWeapon(true, weaponHash, vehicle, ped)
                    end
                end
            end
        end
        
        -- Anti speed changer
        if config.modules.antiSpeedChanger.enabled then
            if vehicle then
                if not (IsPedInAnyPlane(ped) or IsPedInAnyHeli(ped)) then
                    local isInAir = IsEntityInAir(vehicle)
                    local velocity = GetEntityVelocity(vehicle)
                    local coords = GetEntityCoords(vehicle)
                    local maxSpeed = GetVehicleEstimatedMaxSpeed(vehicle)
                    if maxSpeed then
                        local speed = #vector2(velocity.x, velocity.y)
                        if not isInAir then
                            if speed > maxSpeed + 10.0 then
                                local normalizedVelocity = vector2(velocity.x, velocity.y) * maxSpeed / speed
                                SetEntityVelocity(vehicle, normalizedVelocity.x, normalizedVelocity.y, velocity.z)
                            else
                                speedHackDetections = 0
                            end
                        end
                    end
                    lastSavedVehicle = coords
                    lastSavedVelocity = velocity
                    wasInAir = isInAir
                end
            else
                local pedVelocity = GetEntityVelocity(ped)
                local speed = #vector2(pedVelocity.x, pedVelocity.y)
                local maxSpeed = 9.066428184509
                if
                    IsPedRunning(ped) and not IsPedJumping(ped) and not IsPedRagdoll(ped) and not IsEntityInAir(ped) and
                        not IsPedClimbing(ped)
                 then
                    if speed > maxSpeed then
                        local normalizedVelocity = vector2(pedVelocity.x, pedVelocity.y) * maxSpeed / speed
                        SetEntityVelocity(ped, normalizedVelocity.x, normalizedVelocity.y, pedVelocity.z)
                        speedHackDetections = speedHackDetections + 1
                        if speedHackDetections >= 2 then
                            speedHackDetections = 0
                            punishFromClient(
                                "antiSpeedChanger",
                                "Tried to change walk speed: " .. speed
                            )
                        end
                    else
                        speedHackDetections = 0
                    end
                end
            end
        end
        
        -- Anti menu (invisible vehicle)
        if config.modules.antiMenu.enabled then
            if vehicle then
                if IsVehicleVisible(vehicle) then
                    SetEntityVisible(vehicle, true)
                    punishFromClient(
                        "antiMenu",
                        "Player was sitting in an invisible vehicle"
                    )
                end
            end
        end
        
        -- Anti vehicle
        if config.modules.antiVehicle.enabled then
            local vehicleModel = GetEntityModel(vehicle)
            if blacklistedVehicles[vehicleModel] then
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteVehicle(vehicle)
            end
        end
    end,
    "MediumCheck"
)

-- Weapon component hashes voor folder detectie
local weaponComponents = {
    joaat("COMPONENT_COMBATPISTOL_CLIP_01"),
    joaat("COMPONENT_COMBATPISTOL_CLIP_02"),
    joaat("COMPONENT_APPISTOL_CLIP_01"),
    joaat("COMPONENT_APPISTOL_CLIP_02"),
    joaat("COMPONENT_MICROSMG_CLIP_01"),
    joaat("COMPONENT_MICROSMG_CLIP_02"),
    joaat("COMPONENT_SMG_CLIP_01"),
    joaat("COMPONENT_SMG_CLIP_02"),
    joaat("COMPONENT_ASSAULTRIFLE_CLIP_01"),
    joaat("COMPONENT_ASSAULTRIFLE_CLIP_02"),
    joaat("COMPONENT_CARBINERIFLE_CLIP_01"),
    joaat("COMPONENT_CARBINERIFLE_CLIP_02"),
    joaat("COMPONENT_ADVANCEDRIFLE_CLIP_01"),
    joaat("COMPONENT_ADVANCEDRIFLE_CLIP_02"),
    joaat("COMPONENT_MG_CLIP_01"),
    joaat("COMPONENT_MG_CLIP_02"),
    joaat("COMPONENT_COMBATMG_CLIP_01"),
    joaat("COMPONENT_COMBATMG_CLIP_02"),
    joaat("COMPONENT_PUMPSHOTGUN_CLIP_01"),
    joaat("COMPONENT_SAWNOFFSHOTGUN_CLIP_01"),
    joaat("COMPONENT_ASSAULTSHOTGUN_CLIP_01"),
    joaat("COMPONENT_ASSAULTSHOTGUN_CLIP_02"),
    joaat("COMPONENT_PISTOL50_CLIP_01"),
    joaat("COMPONENT_PISTOL50_CLIP_02"),
    joaat("COMPONENT_ASSAULTSMG_CLIP_01"),
    joaat("COMPONENT_ASSAULTSMG_CLIP_02"),
    joaat("COMPONENT_AT_RAILCOVER_01"),
    joaat("COMPONENT_AT_AR_AFGRIP"),
    joaat("COMPONENT_AT_PI_FLSH"),
    joaat("COMPONENT_AT_AR_FLSH"),
    joaat("COMPONENT_AT_SCOPE_MACRO"),
    joaat("COMPONENT_AT_SCOPE_SMALL"),
    joaat("COMPONENT_AT_SCOPE_MEDIUM"),
    joaat("COMPONENT_AT_SCOPE_LARGE"),
    joaat("COMPONENT_AT_SCOPE_MAX"),
    joaat("COMPONENT_AT_PI_SUPP")
}

-- Langere periodieke controles
runPeriodically(
    10000,
    function()
        local ped = PlayerPedId()
        
        -- Anti folder
        if config.modules.antiFolder.enabled then
            for i = 1, #weaponComponents do
                local damageModifier = GetWeaponComponentDamageModifier(weaponComponents[i])
                local accuracyModifier = GetWeaponComponentAccuracyModifier(weaponComponents[i])
                if damageModifier > 1.1 or accuracyModifier > 1.2 then
                    punishFromClient(
                        "antiFolder",
                        "Player tried to use folder cheats"
                    )
                end
            end
        end
        
        -- Anti menu (texture detectie)
        if config.modules.antiMenu.enabled then
            for i, texture in pairs(menuTextures) do
                if texture.x and texture.y then
                    if GetTextureResolution(texture.txd, texture.txt).x == texture.x and GetTextureResolution(texture.txd, texture.txt).y == texture.y then
                        punishFromClient(
                            "antiMenu",
                            "Lua Menu detected: " .. texture.name
                        )
                    end
                else
                    if GetTextureResolution(texture.txd, texture.txt).x ~= 4.0 then
                        punishFromClient(
                            "antiMenu",
                            "Lua Menu detected: " .. texture.name
                        )
                    end
                end
            end
            
            for i, textureDictionary in pairs(blacklistedTextures) do
                if HasStreamedTextureDictLoaded(textureDictionary) then
                    punishFromClient(
                        "antiMenu",
                        "Lua Menu detected, streamed texture dict: " .. textureDictionary
                    )
                end
            end
        end
        
        -- Anti no headshot
        if config.modules.antiNoHeadshot.enabled then
            if GetPedConfigFlag(ped, 2, false) then
                punishFromClient(
                    "antiNoHeadshot",
                    "Player tried to disable Headshot"
                )
            end
        end
        
        -- Anti injector
        if config.modules.antiInjector.enabled then
            if GetGlobalCharBuffer() == nil then
                punishFromClient(
                    "antiInjector",
                    "Lua Injector detected: Parazetamol"
                )
            end
        end
        
        -- Anti silent aim
        if config.modules.antiSilentAim.enabled then
            local pedModel = GetEntityModel(ped)
            local minDimensions, maxDimensions = GetModelDimensions(pedModel)
            if minDimensions.y < -0.29 or maxDimensions.z > 0.98 then
                punishFromClient(
                    "antiSilentAim",
                    "Hitboxes where extended (y:" .. minDimensions.y .. "z:" .. minDimensions.z .. ")"
                )
            end
            if minDimensions.y - 0.50 > 0.1 then
                punishFromClient(
                    "antiSilentAim",
                    "Hitboxes where extended (y:" .. minDimensions.y .. "z:" .. minDimensions.z .. ")"
                )
                Wait(1000)
            end
            if maxDimensions.z - 2.24 > 0.05 then
                punishFromClient(
                    "antiSilentAim",
                    "Hitboxes where extended (y:" .. minDimensions.y .. "z:" .. minDimensions.z .. ")"
                )
                Wait(1000)
            end
            if
                math.abs(minDimensions.x - -0.938245) < 0.001 and math.abs(minDimensions.y - -0.25) < 0.001 and math.abs(minDimensions.z - -1.3) < 0.001 and
                    math.abs(maxDimensions.x - 0.9379423) < 0.001 and
                    math.abs(maxDimensions.y - 0.25) < 0.001 and
                    math.abs(maxDimensions.z - 0.945) < 0.001
             then
                punishFromClient(
                    "antiSilentAim",
                    "Hitboxes where extended (y:" .. minDimensions.y .. "z:" .. minDimensions.z .. ")"
                )
            end
            if
                math.abs(minDimensions.x - -1.115262) < 0.001 and math.abs(minDimensions.y - -0.2601033) < 0.001 and
                    math.abs(minDimensions.z - -1.3) < 0.001 and
                    math.abs(maxDimensions.x - 1.11496) < 0.001 and
                    math.abs(maxDimensions.y - 0.25) < 0.001 and
                    math.abs(maxDimensions.z - 0.9591593) < 0.001
             then
                punishFromClient(
                    "antiSilentAim",
                    "Hitboxes where extended (y:" .. minDimensions.y .. "z:" .. minDimensions.z .. ")"
                )
                Wait(1000)
            end
            if
                math.abs(minDimensions.x - -0.5628748) < 0.001 and math.abs(minDimensions.y - -0.25) < 0.001 and math.abs(minDimensions.z - -1.3) < 0.001 and
                    math.abs(maxDimensions.x - 0.5650583) < 0.001 and
                    math.abs(maxDimensions.y - 0.25) < 0.001 and
                    math.abs(maxDimensions.z - 0.945) < 0.001
             then
                punishFromClient(
                    "antiSilentAim",
                    "Hitboxes where extended (y:" .. minDimensions.y .. "z:" .. minDimensions.z .. ")"
                )
                Wait(1000)
            end
        end
        
        -- Anti commands
        if config.modules.antiCommands.enabled then
            for i, command in ipairs(GetRegisteredCommands()) do
                if blacklistedCommands[command.name] then
                    punishFromClient(
                        "antiCommands",
                        "Blacklisted command detected: " .. command.name
                    )
                end
            end
        end
        
        -- Anti variable
        if config.modules.antiVariable.enabled then
            for i, variableName in pairs(blacklistedVariables) do
                if _G[variableName] ~= nil then
                    _G[variableName] = nil
                    punishFromClient(
                        "antiVariable",
                        "Blacklisted variable found: " .. variableName
                    )
                end
            end
        end
    end,
    "ExtraLongCheck"
)

-- Controles voor injector detectie
runPeriodically(
    2500,
    function()
        if config.modules.antiInjector.enabled then
            if
                GetNumResourceMetadata(
                    "_cfx_internal",
                    "client_script"
                ) > 0
             then
                punishFromClient(
                    "antiInjector",
                    "Tried to inject cheats"
                )
            end
            for i, entity in pairs(GetGamePool("CVehicle")) do
                if i ~= nil and entity ~= nil then
                    local entityScript = GetEntityScript(entity)
                    if entityScript == "scr_2" then
                        local entityOwner = NetworkGetEntityOwner(entity)
                        local ownerServerId = GetPlayerServerId(entityOwner)
                        local myServerId = GetPlayerServerId(playerId)
                        if entityOwner == -1 or ownerServerId == myServerId then
                            punishFromClient(
                                "antiInjector",
                                "Tried to spawn vehicle, scr_2"
                            )
                        end
                        SetEntityAsMissionEntity(entity, true, true)
                        DeleteVehicle(entity)
                    elseif entityScript == "scr_3" then
                        local entityOwner = NetworkGetEntityOwner(entity)
                        local ownerServerId = GetPlayerServerId(entityOwner)
                        local myServerId = GetPlayerServerId(playerId)
                        if entityOwner == -1 or ownerServerId == myServerId then
                            punishFromClient(
                                "antiInjector",
                                "Tried to spawn vehicle, scr_3"
                            )
                        end
                        SetEntityAsMissionEntity(entity, true, true)
                        DeleteVehicle(entity)
                    end
                end
            end
        end
    end,
    "LongCheck"
)

-- Unarmed weapon hash
local unarmedHash = joaat("WEAPON_UNARMED")

-- Event handler voor game events
AddEventHandler(
    "gameEventTriggered",
    function(name, args)
        if not anticheatActive then
            return
        end
        local ped = PlayerPedId()
        local pickupEvents = {
            ["CEventNetworkPlayerCollectedPickup"] = true,
            ["CEventNetworkPlayerCollectedAmbientPickup"] = true,
            ["CEventNetworkPlayerCollectedPortablePickup"] = true
        }
        waitForConfig()
        
        -- Anti pickup
        if config.modules.antiPickup.enabled then
            if pickupEvents[name] then
                punishFromClient(
                    "antiPickup",
                    "Tried to collect a pickup"
                )
            end
        end
        
        -- Anti weapon spoofer
        if config.modules.antiWeaponSpoofer.enabled then
            if
                name == "CEventNetworkEntityDamage"
             then
                local victim = args[1]
                local attacker = args[2]
                local victimDied = args[3]
                local weaponHash = args[4]
                local isMelee = args[5]
                if victim and attacker then
                    local distance = #(GetEntityCoords(ped) - GetEntityCoords(attacker))
                    local attackerWeapon = GetSelectedPedWeapon(attacker)
                    if weaponHash ~= attackerWeapon and attackerWeapon == unarmedHash and weaponHash ~= unarmedHash then
                        if attacker == ped and not IsPedInAnyVehicle(ped) and not attacker == victim and IsPedStill(ped) then
                            if distance >= 10.0 then
                                punishFromClient(
                                    "antiWeaponSpoofer",
                                    "Player tried to spoof weapon"
                                )
                            end
                        end
                    end
                end
            end
        end
    end
)

-- Functie om eigen entiteiten te verwijderen
function deleteOwnedEntities()
    local myServerId = GetPlayerServerId(playerId)
    for i, entity in pairs(GetGamePool("CPed")) do
        local entityOwner = NetworkGetEntityOwner(entity)
        local ownerServerId = GetPlayerServerId(entityOwner)
        if ownerServerId == myServerId then
            DeletePed(entity)
        end
    end
    for i, entity in pairs(GetGamePool("CObject")) do
        local entityOwner = NetworkGetEntityOwner(entity)
        local ownerServerId = GetPlayerServerId(entityOwner)
        if ownerServerId == myServerId then
            DeleteObject(entity)
        end
    end
    for i, entity in pairs(GetGamePool("CVehicle")) do
        local entityOwner = NetworkGetEntityOwner(entity)
        local ownerServerId = GetPlayerServerId(entityOwner)
        if ownerServerId == myServerId then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteVehicle(entity)
        end
    end
end

-- Functie om straf uit te voeren vanaf client
local lastPunishment
function punishFromClient(module, reason)
    if playerPermissions.Whitelisted then
        return
    end
    if lastPunishment == module then
        return
    end
    lastPunishment = module
    TriggerServerEvent(
        encodeEvent "Anticheat:punishFromClient",
        module,
        reason
    )
    waitForConfig()
    local moduleConfig = config.modules[module]
    if not moduleConfig then
        return
    end
    if moduleConfig.punishment == "BAN" or moduleConfig.punishment == "KICK" then
        deleteOwnedEntities()
    end
end

-- Ping event
RegisterNetEvent(
    encodeEvent "Anticheat:ping",
    function()
        TriggerServerEvent(encodeEvent "Anticheat:pong")
    end
)

-- Screenshot functionaliteit
local screenshotReady = false
RegisterNetEvent(
    encodeEvent "Anticheat:requestClientScreenshot",
    function(serverId, endpoint)
        waitForConfig()
        while not screenshotReady do
            Wait(0)
        end
        local screenshotOptions = {}
        screenshotOptions.encoding = "webp"
        screenshotOptions.quality = 0.92
        screenshotOptions.targetURL = endpoint
        screenshotOptions.targetField = "files[]"
        screenshotOptions.id = serverId
        SendNUIMessage({screenshotRequest = screenshotOptions})
    end
)

-- NUI callbacks
RegisterNuiCallback(
    "recognitionReady",
    function(data, cb)
        cb({})
        screenshotReady = true
        waitForConfig()
        SendNUIMessage(
            {onScreenDetection = config.modules.antiMenuOCR.enabled, onScreenKeywords = config.modules.antiMenuOCR.blacklist}
        )
    end
)

RegisterNuiCallback(
    "screenshotCreated",
    function(data, cb)
        cb({})
        if data.data.success then
            TriggerServerEvent(
                encodeEvent "Anticheat:clientScreenshotCreated",
                data.id,
                data.data.data.id
            )
        end
    end
)

RegisterNuiCallback(
    "keywordDetected",
    function(data, cb)
        cb({})
        waitForConfig()
        if config.modules.antiMenuOCR.enabled then
            if not IsPauseMenuActive() then
                punishFromClient(
                    "antiMenuOCR",
                    "Keyword: '" .. data.word .. "'' detected"
                )
            end
        end
    end
)

RegisterNuiCallback(
    "NUIDevTools",
    function(data, cb)
        cb({})
        waitForConfig()
        if config.modules.antiDevTools.enabled then
            punishFromClient(
                "antiDevTools",
                "opened NUI Dev Tools"
            )
        end
    end
)

RegisterNuiCallback(
    "playerOffline",
    function(data, cb)
        cb({})
        waitForConfig()
        if config.modules.antiOffline.enabled and playerSpawned then
            quitGame()
        end
    end
)

-- NUI heartbeat
local lastHeartbeat = GetGameTimer()
local isPongReceived = false
RegisterNuiCallback(
    "pong",
    function(data, cb)
        cb({})
        isPongReceived = true
    end
)

-- Callback met timeout
function callbackOrDelay(name, timeout, callback)
    local callbackExecuted = false
    RegisterNuiCallback(
        name,
        function(data, cb)
            cb({})
            if not callbackExecuted then
                callbackExecuted = true
                callback()
            end
        end
    )
    Citizen.CreateThread(
        function()
            Wait(timeout)
            if not callbackExecuted then
                callbackExecuted = true
                callback()
            end
        end
    )
end

local nuiBlockerDetections = 0
callbackOrDelay(
    "ready",
    30000,
    function()
        SendNUIMessage({permissions = playerPermissions})
        Wait(0)
        runPeriodically(
            3000,
            function()
                if config.modules.antiNuiBlocker.enabled then
                    isPongReceived = false
                    SendNUIMessage({type = "ping"})
                    Wait(5000)
                    if isPongReceived then
                        nuiBlockerDetections = 0
                    else
                        nuiBlockerDetections = nuiBlockerDetections + 1
                        if nuiBlockerDetections >= 3 then
                            punishFromClient(
                                "antiNuiBlocker",
                                "NUI Blocker detected"
                            )
                        end
                    end
                end
            end,
            "NUIHeartbeat"
        )
    end
)

RegisterNuiCallback(
    "peerInitialized",
    function(data, cb)
        cb({})
        TriggerServerEvent(
            encodeEvent "Anticheat:peerInitialized",
            data.id
        )
    end
)

-- Admin menu
local menuInitialized = false
local menuOpen = false
function openMenu()
    menuOpen = true
    SendNUIMessage({menuOpen = true})
end
function closeMenu()
    menuOpen = false
    SendNUIMessage({menuOpen = false})
end
RegisterNetEvent(
    "Anticheat:setMenuOpen",
    function(isOpen)
        if isOpen then
            openMenu()
        else
            closeMenu()
        end
    end
)

RegisterCommand(
    "eac",
    function()
        if not menuInitialized then
            return
        end
        if menuOpen then
            closeMenu()
        else
            TriggerServerEvent("Anticheat:openMenu")
        end
    end
)

RegisterNuiCallback(
    "menuOpen",
    function(data, cb)
        cb({})
        menuOpen = data.menuOpen
        if menuOpen then
            TriggerServerEvent(
                encodeEvent "Anticheat:GetNuiData"
            )
        end
        SetNuiFocus(menuOpen, menuOpen)
    end
)

-- ESP functionaliteit
local espActive = false
RegisterNuiCallback(
    "nuiEvent",
    function(data, cb)
        cb({})
        if data.type == "ESP" then
            if data.value then
                startEsp()
            else
                stopEsp()
            end
        end
        TriggerServerEvent(encodeEvent "Anticheat:nuiEvent", data)
    end
)

local nuiData
RegisterNuiCallback(
    "menuReady",
    function(data, cb)
        cb({})
        menuInitialized = true
        if nuiData then
            SendNUIMessage({nuiData = nuiData})
        end
    end
)

RegisterNetEvent(
    encodeEvent "Anticheat:setNuiData",
    function(data)
        nuiData = data
        if menuInitialized then
            SendNUIMessage({nuiData = data})
        end
    end
)

-- Regenboog kleur functie voor ESP
function RGBRainbow(frequency)
    local result = {}
    local curtime = GetGameTimer() / 1000
    local amplitude = 127
    local center = 128
    local phase = 2
    result.r = math.floor(math.sin(curtime * frequency) * amplitude + center)
    result.g = math.floor(math.sin(curtime * frequency + phase) * amplitude + center)
    result.b = math.floor(math.sin(curtime * frequency + 2 * phase) * amplitude + center)
    return result
end

-- ESP functionaliteit
function startEsp()
    if espActive then
        return
    end
    espActive = true
    Citizen.CreateThread(
        function()
            while espActive do
                local ped = PlayerPedId()
                local color = RGBRainbow(1.0)
                local r, g, b = color.r, color.g, color.b
                local pedCoords = GetEntityCoords(ped)
                for i, entity in ipairs(GetGamePool("CPed")) do
                    local entityCoords = GetEntityCoords(entity)
                    DrawLine(pedCoords.x, pedCoords.y, pedCoords.z, entityCoords.x, entityCoords.y, entityCoords.z, r, g, b, 255)
                end
                Wait(0)
            end
        end
    )
end

function stopEsp()
    espActive = false
end