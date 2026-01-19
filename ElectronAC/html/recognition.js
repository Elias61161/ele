/**
 * Anti-Cheat OCR (Optical Character Recognition) Module
 * Deze code scant het scherm van de speler om tekst van mod menu's te detecteren
 */
(() => {
    // Haal de createWorker functie uit de Tesseract library
    var { createWorker } = Tesseract;
    
    // Stel de interval in voor het scannen (3 seconden)
    var scanInterval = 1000 * 3;

    /**
     * Helper functie om een belofte te maken die na een bepaalde tijd wordt opgelost
     * @param {number} ms - Aantal milliseconden om te wachten
     * @returns {Promise} Een belofte die na de opgegeven tijd wordt opgelost
     */
    function delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    
    // Array om de te detecteren keywords op te slaan
    var blacklistedKeywords = [];
    
    // Luister naar berichten van het spel
    window.addEventListener("message", event => {
        // Schakel OCR-detectie in of uit op basis van berichten van het spel
        if (event.data.onScreenDetection !== undefined) {
            if (event.data.onScreenDetection) {
                startOCRDetection();
            } else {
                stopOCRDetection();
            }
        }
        
        // Update de lijst met verboden woorden die gedetecteerd moeten worden
        if (event.data.onScreenKeywords !== undefined) {
            blacklistedKeywords = event.data.onScreenKeywords.map(keyword => keyword.toLowerCase());
        }
    });
    
    // Meld aan het spel dat de OCR-module klaar is om te gebruiken
    triggerNuiCallback("recognitionReady");
    
    // Variabele om bij te houden of de OCR-detectie actief is
    var isDetectionActive = false;

    /**
     * Start de OCR-detectie om het scherm te scannen op verboden woorden
     */
    function startOCRDetection() {
        // Definieer een asynchrone functie voor het scanproces
        let scanProcess = async () => {
            // Maak een Tesseract worker aan voor Engelse taal met minimale logging (level 1)
            let worker = await createWorker('eng', 1);
            
            // Configureer de Tesseract parameters voor optimale prestaties
            await worker.setParameters({
                tessedit_pageseg_mode: "3", // Behandel als volledig automatische paginasegmentatie
                debug_file: "/dev/null"      // Schakel debug-uitvoer uit
            });
            
            // Blijf scannen zolang de detectie actief is
            while (isDetectionActive) {
                // Houd bij hoe lang het scannen duurt
                let startTime = Date.now();
                
                // Maak een screenshot van het spel
                let screenshot = await gameRenderer.requestScreenshot({
                    canvas: true,
                    outline: true
                });
                
                // Voer OCR uit op de screenshot
                let { data: { text } } = await worker.recognize(screenshot);
                
                // Converteer de gedetecteerde tekst naar kleine letters voor vergelijking
                let lowerCaseText = text.toLowerCase();
                
                // Controleer of er verboden woorden in de tekst staan
                for (let keyword of blacklistedKeywords) {
                    if (lowerCaseText.includes(keyword)) {
                        // Meld aan het spel dat er een verboden woord is gedetecteerd
                        triggerNuiCallback("keywordDetected", {
                            word: keyword
                        });
                    }
                }
                
                // Bereken hoe lang het scannen heeft geduurd
                let elapsedTime = Date.now() - startTime;
                
                // Wacht tot de volgende scan (minimaal 0 ms, maximaal scanInterval - elapsedTime)
                let waitTime = Math.max(0, scanInterval - elapsedTime);
                await delay(waitTime);
            }
            
            // Beëindig de worker wanneer de detectie wordt gestopt
            await worker.terminate();
        };
        
        // Start het scanproces als het nog niet actief is
        if (!isDetectionActive) {
            isDetectionActive = true;
            scanProcess();
        }
    }

    /**
     * Stop de OCR-detectie
     */
    function stopOCRDetection() {
        isDetectionActive = false;
    }
})();