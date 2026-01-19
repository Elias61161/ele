-- Deze functie codeert event namen om te voorkomen dat cheaters ze gemakkelijk kunnen detecteren
-- Het maakt een unieke hash voor elke event naam gebaseerd op de resource naam

local resourceName = GetCurrentResourceName()
local eventCache = {}

function encodeEvent(eventName)
    local hashLength = 64  -- Lengte van de gegenereerde hash
    local seed = 0         -- Initiële seed voor de random generator
    
    -- Als deze event naam al eerder is gecodeerd, gebruik de opgeslagen versie
    if eventCache[eventName] then
        return eventCache[eventName]
    end
    
    -- Combineer de event naam met de resource naam voor extra veiligheid
    local combinedString = eventName..resourceName
    
    -- Bereken een numerieke seed gebaseerd op de karakters in de gecombineerde string
    for i = 1, #combinedString do
        local char = string.sub(combinedString, i, i)
        seed = seed + string.byte(char) * i + string.byte(char)
    end
    
    -- Initialiseer de random generator met de berekende seed
    math.randomseed(seed)
    
    -- Genereer een willekeurige string van kleine letters met de opgegeven lengte
    local encodedEvent = ''
    for i = 1, hashLength do
        encodedEvent = encodedEvent..string.char(math.random(97, 122))  -- ASCII codes voor a-z
    end
    
    -- Sla de gecodeerde naam op in de cache voor toekomstig gebruik
    eventCache[eventName] = encodedEvent
    
    return encodedEvent
end