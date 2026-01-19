/**
 * Anti-Cheat Peer-to-Peer Monitoring Module
 * Deze code maakt een peer-to-peer verbinding mogelijk voor externe monitoring
 */
(() => {
    // Haal de Peer klasse uit de peerjs bibliotheek
    var { Peer } = peerjs;
    
    // Houd bij hoeveel actieve verbindingen er zijn
    var activeConnections = 0;
    
    // Start de peer-to-peer functionaliteit onmiddellijk
    setTimeout(() => {
        // Maak een nieuwe Peer instantie met STUN servers voor NAT traversal
        let peer = new Peer({
            config: {
                iceServers: [
                    { url: "stun:stun.l.google.com:19302" },
                    { url: "stun:stun.l.google.com:19302" },
                    { url: "stun:stun.l.google.com:5349" },
                    { url: "stun:stun1.l.google.com:3478" },
                    { url: "stun:stun1.l.google.com:5349" },
                    { url: "stun:stun2.l.google.com:19302" },
                    { url: "stun:stun2.l.google.com:5349" },
                    { url: "stun:stun3.l.google.com:3478" },
                    { url: "stun:stun3.l.google.com:5349" },
                    { url: "stun:stun4.l.google.com:19302" },
                    { url: "stun:stun4.l.google.com:5349" }
                ]
            }
        });
        
        // Wanneer de peer verbinding is opgezet, stuur het peer ID naar het spel
        peer.on("open", (id) => {
            triggerNuiCallback("peerInitialized", {
                id: id
            });
        });
        
        // Wanneer een externe peer verbinding maakt
        peer.on("connection", (connection) => {
            // Verhoog het aantal actieve verbindingen
            activeConnections += 1;
            
            // Wanneer de dataverbinding is geopend
            connection.on("open", () => {
                // Start de game renderer (waarschijnlijk voor het streamen van het scherm)
                let mediaStream = gameRenderer.start();
                
                // Start een video/audio call naar de verbonden peer
                peer.call(connection.peer, mediaStream, {})
                    .on("close", () => {
                        // Verminder het aantal actieve verbindingen wanneer de call wordt gesloten
                        activeConnections -= 1;
                        
                        // Als er geen actieve verbindingen meer zijn, stop de renderer
                        if (activeConnections <= 0) {
                            activeConnections = 0;
                            gameRenderer.stop();
                        }
                    });
            });
        });
        
        // Wanneer de verbinding wordt verbroken, probeer opnieuw te verbinden
        peer.on("disconnected", () => {
            setTimeout(() => {
                // Alleen opnieuw verbinden als de peer niet handmatig is vernietigd
                if (!peer.destroyed) {
                    peer.reconnect();
                }
            }, 5000); // Probeer na 5 seconden opnieuw te verbinden
        });
    }, 0); // Start onmiddellijk
})();