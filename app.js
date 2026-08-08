// Serdivan Yurt-Kampüs Öğrenci Rehberi - Core Application Logic

document.addEventListener("DOMContentLoaded", () => {
    // Check if MAP_DATA is loaded
    if (typeof MAP_DATA === "undefined") {
        console.error("MAP_DATA could not be loaded from data.js");
        return;
    }

    // --- STATE MANAGEMENT ---
    let currentCategory = "all";
    let searchQuery = "";
    let activeItemId = null;
    let selectedDormId = ""; // Wizard selection
    
    // Leaflet map objects
    let map = null;
    let currentTileLayer = null;
    let isDarkTheme = false; // Default: Light Theme
    let gpsMarker = null; // User current GPS marker
    
    // Store Leaflet objects for cleanup
    let markersGroup = [];
    let polylinesGroup = [];

    // Map Center focusing on the Yurt-Kampüs corridor (Kemalpaşa-Esentepe region)
    const CORRIDOR_CENTER = [40.750, 30.344];
    const DEFAULT_ZOOM = 14.5;

    // --- MAP TILES ---
    const lightTiles = L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
        subdomains: 'abcd',
        maxZoom: 20
    });

    const darkTiles = L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
        subdomains: 'abcd',
        maxZoom: 20
    });

    // --- INITIALIZE MAP ---
    function initMap() {
        map = L.map('map', {
            zoomControl: false,
            layers: [lightTiles]
        }).setView(CORRIDOR_CENTER, DEFAULT_ZOOM);
        
        currentTileLayer = lightTiles;

        // Position zoom control at bottom right
        L.control.zoom({
            position: 'bottomright'
        }).addTo(map);

        // Hook Leaflet location events
        map.on('locationfound', onLocationFound);
        map.on('locationerror', onLocationError);
    }

    // --- HELPER: CALCULATE DURATION FROM DISTANCE TEXT ---
    function getTravelTimes(lengthText) {
        let meters = 1000; // Default
        const cleanText = lengthText.toLowerCase();
        
        if (cleanText.includes("km")) {
            const parsed = parseFloat(cleanText.replace("yaklaşık", "").replace("km", "").trim());
            if (!isNaN(parsed)) meters = parsed * 1000;
        } else if (cleanText.includes("metre")) {
            const parsed = parseInt(cleanText.replace("yaklaşık", "").replace("metre", "").trim());
            if (!isNaN(parsed)) meters = parsed;
        }

        // Speed constants: Walking 5 km/h (83.3m/min), Cycling 15 km/h (250m/min)
        const walkTime = Math.round(meters / 83.3);
        const bikeTime = Math.round(meters / 250);

        return {
            walk: walkTime > 0 ? walkTime : 1,
            bike: bikeTime > 0 ? bikeTime : 1
        };
    }

    // --- FILTER DATA (WITH PROXIMITY SUPPORT) ---
    function getFilteredData() {
        let dormCoords = null;
        if (selectedDormId) {
            const dorm = MAP_DATA.locations.find(l => l.id === selectedDormId);
            if (dorm) dormCoords = L.latLng(dorm.coords);
        }

        // Filter Locations
        let filteredLocations = MAP_DATA.locations.filter(loc => {
            const matchesCategory = currentCategory === "all" || loc.category === currentCategory;
            const matchesSearch = searchQuery === "" || 
                loc.name.toLowerCase().includes(searchQuery) ||
                loc.address.toLowerCase().includes(searchQuery) ||
                loc.details.toLowerCase().includes(searchQuery);
            
            // Proximity Filter: If a dorm is selected, hide places that are further than 1.8km (excluding dorms themselves)
            let matchesProximity = true;
            if (dormCoords && loc.category !== "dorms") {
                const locLatLng = L.latLng(loc.coords);
                const distance = dormCoords.distanceTo(locLatLng); // distance in meters
                matchesProximity = distance <= 1800; // 1.8 km
            }

            return matchesCategory && matchesSearch && matchesProximity;
        });

        // Filter Routes
        let filteredRoutes = MAP_DATA.routesData.filter(route => {
            const matchesCategory = currentCategory === "all" || route.category === currentCategory;
            const matchesSearch = searchQuery === "" ||
                route.name.toLowerCase().includes(searchQuery) ||
                route.details.toLowerCase().includes(searchQuery);
            
            // If a dorm is selected, only show routes linked to that dorm or routes that are global
            let matchesProximity = true;
            if (selectedDormId && route.category === "transport") {
                matchesProximity = route.linkedDorms && route.linkedDorms.includes(selectedDormId);
            }

            return matchesCategory && matchesSearch && matchesProximity;
        });

        return { locations: filteredLocations, routes: filteredRoutes };
    }

    // --- CUSTOM MAP MARKERS ---
    function createCustomMarkerIcon(category, color) {
        const catConfig = MAP_DATA.categories[category];
        const iconName = catConfig ? catConfig.icon : "location-dot";
        
        return L.divIcon({
            html: `<div class="custom-marker-inner" style="background-color: ${color};"><i class="fa-solid fa-${iconName}"></i></div>`,
            className: 'custom-marker-div',
            iconSize: [34, 34],
            iconAnchor: [17, 17],
            popupAnchor: [0, -17]
        });
    }

    // --- RENDER MAP LAYERS (MARKERS & ROUTES) ---
    function renderMapLayers(locations, routes) {
        // Clear existing markers & routes
        markersGroup.forEach(marker => map.removeLayer(marker));
        markersGroup = [];
        
        polylinesGroup.forEach(line => map.removeLayer(line));
        polylinesGroup = [];

        // Plot locations
        locations.forEach(loc => {
            const catInfo = MAP_DATA.categories[loc.category];
            const markerColor = catInfo ? catInfo.color : "#4f46e5";
            const customIcon = createCustomMarkerIcon(loc.category, markerColor);
            
            const marker = L.marker(loc.coords, { icon: customIcon }).addTo(map);
            
            // Build custom popup
            const popupContent = `
                <div class="popup-container">
                    <div class="popup-header" style="color: ${markerColor}">${loc.name}</div>
                    <div class="popup-desc">${loc.details.substring(0, 80)}...</div>
                    <div class="popup-footer">
                        <span><i class="fa-solid fa-clock"></i> ${loc.hours || 'Aktif'}</span>
                        <button class="popup-btn" data-id="${loc.id}">Detaylar <i class="fa-solid fa-arrow-right"></i></button>
                    </div>
                </div>
            `;
            
            marker.bindPopup(popupContent);
            marker.id = loc.id;
            
            // Handle popup open detail click
            marker.on('popupopen', () => {
                const btn = document.querySelector(`.popup-btn[data-id="${loc.id}"]`);
                if (btn) {
                    btn.addEventListener("click", () => {
                        handleItemSelection(loc.id, false);
                        map.closePopup();
                    });
                }
            });

            markersGroup.push(marker);
        });

        // Plot routes (polylines)
        routes.forEach(route => {
            const isLinkedToSelectedDorm = selectedDormId && route.linkedDorms && route.linkedDorms.includes(selectedDormId);
            
            const polyline = L.polyline(route.path, {
                color: route.color,
                weight: isLinkedToSelectedDorm ? 8 : 5,
                opacity: (selectedDormId && !isLinkedToSelectedDorm) ? 0.2 : 0.8,
                lineJoin: 'round'
            }).addTo(map);

            // Hover styles
            polyline.on('mouseover', function() {
                this.setStyle({
                    weight: 9,
                    opacity: 1
                });
            });

            polyline.on('mouseout', function() {
                if (activeItemId !== route.id) {
                    const isLinkedToActive = activeItemId && route.linkedDorms && route.linkedDorms.includes(activeItemId);
                    const remainsHighlighted = isLinkedToActive || (selectedDormId && route.linkedDorms && route.linkedDorms.includes(selectedDormId));
                    
                    this.setStyle({
                        weight: remainsHighlighted ? 8 : 5,
                        opacity: remainsHighlighted ? 1 : ((selectedDormId && !remainsHighlighted) ? 0.2 : 0.8)
                    });
                }
            });

            // Route select click
            polyline.on('click', () => {
                handleItemSelection(route.id, true);
            });

            polyline.id = route.id;
            polylinesGroup.push(polyline);
        });
    }

    // --- RENDER SIDEBAR LIST ---
    function renderSidebarList(locations, routes) {
        const listContainer = document.getElementById("pois-list");
        const resultsCountEl = document.getElementById("results-count");
        
        listContainer.innerHTML = "";
        
        const totalItemsCount = locations.length + routes.length;
        resultsCountEl.innerText = totalItemsCount;

        if (totalItemsCount === 0) {
            listContainer.innerHTML = `
                <div class="details-placeholder">
                    <i class="fa-solid fa-ban"></i>
                    <p>Aradığınız kriterlere uygun sonuç bulunamadı.</p>
                </div>
            `;
            return;
        }

        // Get coordinates of selected dorm for distance annotations
        let dormLatLng = null;
        if (selectedDormId) {
            const dorm = MAP_DATA.locations.find(l => l.id === selectedDormId);
            if (dorm) dormLatLng = L.latLng(dorm.coords);
        }

        // Render Locations
        locations.forEach(loc => {
            const catInfo = MAP_DATA.categories[loc.category];
            const isActive = loc.id === activeItemId ? "active" : "";
            
            const card = document.createElement("div");
            card.className = `poi-card ${isActive}`;
            card.setAttribute("data-category", loc.category);
            card.setAttribute("data-id", loc.id);
            
            // Build distance tag if a dorm is selected
            let distanceHtml = "";
            if (dormLatLng && loc.id !== selectedDormId) {
                const locLatLng = L.latLng(loc.coords);
                const distanceMeters = Math.round(dormLatLng.distanceTo(locLatLng));
                const distanceText = distanceMeters >= 1000 
                    ? `${(distanceMeters / 1000).toFixed(1)} km` 
                    : `${distanceMeters} m`;
                distanceHtml = `<span class="meta-tag" style="background-color: rgba(79, 70, 229, 0.08); color: var(--accent-primary);"><i class="fa-solid fa-person-walking"></i> ${distanceText}</span>`;
            }

            const featureTags = loc.features.slice(0, 2).map(f => `<span class="meta-tag">${f}</span>`).join("");

            card.innerHTML = `
                <div class="card-icon"><i class="fa-solid fa-${catInfo.icon}"></i></div>
                <div class="card-info">
                    <h4>${loc.name}</h4>
                    <span class="address">${loc.address}</span>
                    <div class="card-meta-tags">
                        <span class="meta-tag" style="border: 1px solid ${catInfo.color}; color: ${catInfo.color}">${catInfo.name}</span>
                        ${distanceHtml}
                        ${featureTags}
                    </div>
                </div>
            `;

            card.addEventListener("click", () => {
                handleItemSelection(loc.id, false);
            });

            listContainer.appendChild(card);
        });

        // Render Routes
        routes.forEach(route => {
            const catInfo = MAP_DATA.categories[route.category];
            const isActive = route.id === activeItemId ? "active" : "";

            const times = getTravelTimes(route.length);

            const card = document.createElement("div");
            card.className = `poi-card ${isActive}`;
            card.setAttribute("data-category", route.category);
            card.setAttribute("data-id", route.id);

            card.innerHTML = `
                <div class="card-icon"><i class="fa-solid fa-${catInfo.icon}"></i></div>
                <div class="card-info">
                    <h4>${route.name}</h4>
                    <span class="address">${route.type} • ${route.length}</span>
                    <div class="card-meta-tags">
                        <span class="meta-tag" style="border: 1px solid ${route.color}; color: ${route.color}">Hat / Rota</span>
                        <span class="meta-tag" title="Yürüme Süresi"><i class="fa-solid fa-person-walking"></i> ~${times.walk} dk</span>
                        <span class="meta-tag" title="Bisiklet Süresi"><i class="fa-solid fa-bicycle"></i> ~${times.bike} dk</span>
                    </div>
                </div>
            `;

            card.addEventListener("click", () => {
                handleItemSelection(route.id, true);
            });

            listContainer.appendChild(card);
        });
    }

    // --- HANDLE SELECTION (CLICK ACTION) ---
    function handleItemSelection(id, isRoute) {
        activeItemId = id;
        
        // Highlight active card in sidebar list
        const allCards = document.querySelectorAll(".poi-card");
        allCards.forEach(c => c.classList.remove("active"));
        
        const selectedCard = document.querySelector(`.poi-card[data-id="${id}"]`);
        if (selectedCard) {
            selectedCard.classList.add("active");
            selectedCard.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }

        // Show details and apply route/marker highlight on map
        if (isRoute) {
            const route = MAP_DATA.routesData.find(r => r.id === id);
            if (route) {
                showDetailsPane(route, true);
                
                // Bold active polyline, dim others
                polylinesGroup.forEach(line => {
                    if (line.id === id) {
                        line.setStyle({ weight: 9, opacity: 1 });
                        map.fitBounds(line.getBounds(), { padding: [40, 40] });
                    } else {
                        line.setStyle({ weight: 5, opacity: 0.2 });
                    }
                });
            }
        } else {
            const loc = MAP_DATA.locations.find(l => l.id === id);
            if (loc) {
                showDetailsPane(loc, false);
                
                // Pan map to active marker
                map.setView(loc.coords, 16, { animate: true, duration: 0.8 });
                
                const marker = markersGroup.find(m => m.id === id);
                if (marker) {
                    marker.openPopup();
                }

                // If selected item is a KYK Dormitory, highlight its linked transit route to SAÜ Campus!
                if (loc.category === "dorms") {
                    const linkedRouteIds = MAP_DATA.routesData
                        .filter(r => r.linkedDorms && r.linkedDorms.includes(id))
                        .map(r => r.id);

                    polylinesGroup.forEach(line => {
                        if (linkedRouteIds.includes(line.id)) {
                            line.setStyle({ weight: 9, opacity: 1 });
                        } else {
                            line.setStyle({ weight: 5, opacity: 0.15 });
                        }
                    });
                } else {
                    // Dim/Highlight based on selectedDormId if any
                    polylinesGroup.forEach(line => {
                        const isLinkedToSelectedDorm = selectedDormId && MAP_DATA.routesData.find(r => r.id === line.id && r.linkedDorms && r.linkedDorms.includes(selectedDormId));
                        line.setStyle({
                            weight: isLinkedToSelectedDorm ? 8 : 5,
                            opacity: isLinkedToSelectedDorm ? 1 : (selectedDormId ? 0.2 : 0.6)
                        });
                    });
                }
            }
        }
    }

    // --- SHOW DETAIL PANEL ---
    function showDetailsPane(item, isRoute) {
        const detailsPane = document.getElementById("details-pane");
        const detailsBody = document.getElementById("details-body");
        
        const catInfo = MAP_DATA.categories[item.category];
        const categoryColor = isRoute ? item.color : (catInfo ? catInfo.color : "#4f46e5");
        const categoryIcon = catInfo ? catInfo.icon : "location-dot";
        const categoryName = isRoute ? `${catInfo.name} (${item.type})` : catInfo.name;

        let contentHtml = `
            <div class="details-header">
                <div class="details-header-icon" style="background-color: ${categoryColor}20; color: ${categoryColor}">
                    <i class="fa-solid fa-${categoryIcon}"></i>
                </div>
                <div class="details-header-title">
                    <h2>${item.name}</h2>
                    <span class="category-label" style="color: ${categoryColor}">${categoryName}</span>
                </div>
            </div>
            
            <div class="details-body">
                <p class="details-description">${item.details}</p>
        `;

        if (isRoute) {
            const times = getTravelTimes(item.length);
            contentHtml += `
                <div class="details-info-row">
                    <i class="fa-solid fa-route"></i>
                    <div><strong>Mesafe / Uzunluk:</strong> ${item.length}</div>
                </div>
                <div class="details-info-row">
                    <i class="fa-solid fa-gauge-simple-high"></i>
                    <div><strong>Ulaşım Kolaylığı / Zorluk:</strong> ${item.difficulty}</div>
                </div>
                <div class="details-info-row">
                    <i class="fa-solid fa-clock"></i>
                    <div><strong>Tahmini Süreler:</strong> 🚶 ~${times.walk} dk Yürüme &bull; 🚴 ~${times.bike} dk Bisiklet</div>
                </div>
            `;
            
            // Add offline intervals details if present
            if (item.intervals) {
                contentHtml += `
                    <div class="details-info-row">
                        <i class="fa-solid fa-clock-rotate-left"></i>
                        <div><strong>Sefer Sıklığı (SAKUS):</strong> ${item.intervals}</div>
                    </div>
                `;
            }
        } else {
            contentHtml += `
                <div class="details-info-row">
                    <i class="fa-solid fa-map-pin"></i>
                    <div><strong>Adres:</strong> ${item.address}</div>
                </div>
                <div class="details-info-row">
                    <i class="fa-solid fa-clock"></i>
                    <div><strong>Saat Detayları:</strong> ${item.hours}</div>
                </div>
            `;
        }

        // Render features if present
        if (item.features && item.features.length > 0) {
            const featuresHtml = item.features.map(f => `<span class="feature-pill">${f}</span>`).join("");
            contentHtml += `
                <div class="details-info-row" style="margin-top: 10px; flex-direction: column; gap: 4px;">
                    <strong>Öne Çıkan Detaylar:</strong>
                    <div class="details-features-list">
                        ${featuresHtml}
                    </div>
                </div>
            `;
        }

        // Add yol tarifi link and SAKUS buttons
        const mapUrl = isRoute 
            ? `https://www.google.com/maps/dir/?api=1&destination=${item.path[0][0]},${item.path[0][1]}`
            : `https://www.google.com/maps/search/?api=1&query=${item.coords[0]},${item.coords[1]}`;
            
        let sakusButtonsHtml = "";
        if (item.sakusUrls && item.sakusUrls.length > 0) {
            item.sakusUrls.forEach(link => {
                sakusButtonsHtml += `
                    <a href="${link.url}" target="_blank" class="btn-primary" style="text-decoration: none; background-color: #3498db; width: 100%;">
                        <i class="fa-solid fa-clock-rotate-left"></i> SAKUS ${link.name}
                    </a>
                `;
            });
        }

        contentHtml += `
                <div class="action-buttons-group" style="flex-direction: column; gap: 8px; align-items: stretch; width: 100%;">
                    <a href="${mapUrl}" target="_blank" class="btn-primary" style="text-decoration: none; width: 100%;">
                        <i class="fa-solid fa-diamond-turn-right"></i> Konuma Git / Yol Tarifi
                    </a>
                    ${sakusButtonsHtml}
                </div>
            </div>
        `;

        detailsBody.innerHTML = contentHtml;
        detailsPane.classList.add("active");
    }

    // --- POPULATE DORM SELECTOR OPTIONS ---
    function initDormSelector() {
        const selectEl = document.getElementById("dorm-select");
        if (!selectEl) return;

        // Fetch KYK dorms from MAP_DATA
        const dorms = MAP_DATA.locations.filter(l => l.category === "dorms");
        
        dorms.forEach(dorm => {
            const option = document.createElement("option");
            option.value = dorm.id;
            option.innerText = dorm.name;
            selectEl.appendChild(option);
        });

        selectEl.addEventListener("change", (e) => {
            selectedDormId = e.target.value;
            
            // Clear details drawer
            document.getElementById("details-pane").classList.remove("active");
            activeItemId = null;

            if (selectedDormId) {
                // Select and focus the selected dorm marker
                handleItemSelection(selectedDormId, false);
            } else {
                // If reset, clear marker selection highlights and recenter map
                polylinesGroup.forEach(line => line.setStyle({ weight: 5, opacity: 0.7 }));
                map.setView(CORRIDOR_CENTER, DEFAULT_ZOOM, { animate: true });
                updateApp();
            }
        });
    }

    // --- GPS LOCATION SUCCESS HANDLER ---
    function onLocationFound(e) {
        // Clear previous GPS marker
        if (gpsMarker) {
            map.removeLayer(gpsMarker);
        }

        // Custom pulsing dot GPS Icon
        const gpsIcon = L.divIcon({
            html: '<div class="gps-marker-inner"></div>',
            className: 'gps-marker-div',
            iconSize: [22, 22],
            iconAnchor: [11, 11]
        });

        gpsMarker = L.marker(e.latlng, { icon: gpsIcon }).addTo(map);
        gpsMarker.bindPopup("<b>Buradasınız!</b><br>Serdivan Akıllı Rehber").openPopup();
        
        map.setView(e.latlng, 16, { animate: true });
    }

    // --- GPS LOCATION ERROR HANDLER ---
    function onLocationError(e) {
        alert("Konumunuz alınamadı: " + e.message + "\nLütfen tarayıcınızın GPS / konum izinlerini açtığınızdan emin olun.");
    }

    // --- APPLY FILTERS & RE-RENDER ---
    function updateApp() {
        const data = getFilteredData();
        renderMapLayers(data.locations, data.routes);
        renderSidebarList(data.locations, data.routes);
    }

    // --- EVENT LISTENERS ---

    // Category pills filter
    const pills = document.querySelectorAll(".filter-pill");
    pills.forEach(pill => {
        pill.addEventListener("click", (e) => {
            pills.forEach(p => p.classList.remove("active"));
            
            const selectedPill = e.currentTarget;
            selectedPill.classList.add("active");
            
            currentCategory = selectedPill.getAttribute("data-category");
            
            // Clear selections
            activeItemId = null;
            document.getElementById("details-pane").classList.remove("active");
            
            updateApp();
            
            // Recenter view on category filter change
            if (selectedDormId) {
                const dorm = MAP_DATA.locations.find(l => l.id === selectedDormId);
                if (dorm) map.setView(dorm.coords, DEFAULT_ZOOM, { animate: true });
            } else {
                map.setView(CORRIDOR_CENTER, DEFAULT_ZOOM, { animate: true });
            }
        });
    });

    // Search bar filtering
    const searchInput = document.getElementById("poi-search");
    const clearSearchBtn = document.getElementById("clear-search");
    
    searchInput.addEventListener("input", (e) => {
        searchQuery = e.target.value.toLowerCase().trim();
        
        if (searchQuery.length > 0) {
            clearSearchBtn.style.display = "block";
        } else {
            clearSearchBtn.style.display = "none";
        }
        
        updateApp();
    });

    // Clear search query
    clearSearchBtn.addEventListener("click", () => {
        searchInput.value = "";
        searchQuery = "";
        clearSearchBtn.style.display = "none";
        updateApp();
    });

    // Recenter Map
    document.getElementById("recenter-map").addEventListener("click", () => {
        if (selectedDormId) {
            const dorm = MAP_DATA.locations.find(l => l.id === selectedDormId);
            if (dorm) map.setView(dorm.coords, DEFAULT_ZOOM, { animate: true, duration: 1.0 });
        } else {
            map.setView(CORRIDOR_CENTER, DEFAULT_ZOOM, { animate: true, duration: 1.0 });
        }
    });

    // Find My Location (GPS) Click
    document.getElementById("find-my-location").addEventListener("click", () => {
        map.locate({ setView: true, maxZoom: 16 });
    });

    // Toggle Theme (Light / Dark)
    document.getElementById("toggle-theme").addEventListener("click", () => {
        const themeBtnIcon = document.querySelector("#toggle-theme i");
        
        if (isDarkTheme) {
            // Switch to Light
            document.body.classList.remove("dark-theme");
            map.removeLayer(darkTiles);
            map.addLayer(lightTiles);
            themeBtnIcon.className = "fa-solid fa-moon";
            isDarkTheme = false;
        } else {
            // Switch to Dark
            document.body.classList.add("dark-theme");
            map.removeLayer(lightTiles);
            map.addLayer(darkTiles);
            themeBtnIcon.className = "fa-solid fa-sun";
            isDarkTheme = true;
        }
    });

    // Close Details Drawer
    document.getElementById("close-details").addEventListener("click", () => {
        document.getElementById("details-pane").classList.remove("active");
        
        // Reset polyline highlights
        polylinesGroup.forEach(line => {
            const isLinkedToSelectedDorm = selectedDormId && MAP_DATA.routesData.find(r => r.id === line.id && r.linkedDorms && r.linkedDorms.includes(selectedDormId));
            line.setStyle({
                weight: isLinkedToSelectedDorm ? 8 : 5,
                opacity: isLinkedToSelectedDorm ? 1 : (selectedDormId ? 0.2 : 0.7)
            });
        });
        activeItemId = null;
        
        const allCards = document.querySelectorAll(".poi-card");
        allCards.forEach(c => c.classList.remove("active"));
    });

    // --- INITIALIZE APPLICATION ---
    initMap();
    initDormSelector();
    updateApp();
});
