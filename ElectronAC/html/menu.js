/**
 * Admin Menu Interface voor het Anti-Cheat Systeem
 * Deze code beheert de interactie tussen het spel en de HTML/JS interface
 */
(() => {
    /**
     * Functie om het menu te openen of te sluiten
     * @param {boolean} isOpen - Of het menu geopend (true) of gesloten (false) moet worden
     */
    function toggleMenu(isOpen) {
        if (isOpen) {
            // Toon het menu met een fade-in effect
            $(".menu-bg").fadeIn(200);
            $(".menu-container").fadeIn(200);
        } else {
            // Verberg het menu met een fade-out effect
            $(".menu-bg").fadeOut(200);
            $(".menu-container").fadeOut(200);
        }
        
        // Stuur een callback naar het spel om te melden dat het menu is geopend/gesloten
        triggerNuiCallback("menuOpen", {
            menuOpen: isOpen
        });
    }

    // Luister naar berichten van het spel
    window.addEventListener("message", async (event) => {
        // Verwerk menuOpen berichten
        if (event.data.menuOpen !== undefined) {
            $(() => {
                toggleMenu(event.data.menuOpen);
            });
        }
        
        // Verwerk nuiData berichten (bijv. voor het instellen van de routingBucket)
        if (event.data.nuiData !== undefined) {
            $("#routingBucket").val(event.data.nuiData.routingBucket);
        }
    });

    // jQuery document ready functie
    $(() => {
        // Sluit het menu wanneer op de achtergrond wordt geklikt
        $(".menu-bg").click(() => {
            toggleMenu(false);
        });
        
        // Sluit het menu wanneer op de sluit-knop wordt geklikt
        $(".close-btn").click(() => {
            toggleMenu(false);
        });
        
        // Event handlers voor de verschillende admin knoppen
        
        // Verwijder alle voertuigen in de wereld
        $("#deleteVehicles").click(() => {
            triggerNuiCallback("nuiEvent", {
                type: "deleteVehicles"
            });
        });
        
        // Verwijder alle peds (NPC's) in de wereld
        $("#deletePeds").click(() => {
            triggerNuiCallback("nuiEvent", {
                type: "deletePeds"
            });
        });
        
        // Verwijder alle objecten in de wereld
        $("#deleteObjects").click(() => {
            triggerNuiCallback("nuiEvent", {
                type: "deleteObjects"
            });
        });
        
        // Verander de routing bucket (instance) van de speler
        $("#routingBucket").change((event) => {
            triggerNuiCallback("nuiEvent", {
                type: "setRoutingBucket",
                value: parseInt(event.target.value)
            });
        });
        
        // Schakel ESP (wallhack voor admins) in of uit
        $("#esp").change((event) => {
            triggerNuiCallback("nuiEvent", {
                type: "ESP",
                value: event.target.checked
            });
        });
    });

    // Meld aan het spel dat het menu klaar is om te gebruiken
    triggerNuiCallback("menuReady");
})();