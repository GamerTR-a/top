/**
 * Orbit Guardian: Elemental Strike
 * Core Game Logic
 */

const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');

// UI Elements
const scoreEl = document.getElementById('score');
const comboEl = document.getElementById('combo');
const finalScoreEl = document.getElementById('final-score');
const menuScreen = document.getElementById('menu-screen');
const gameoverScreen = document.getElementById('gameover-screen');
const startBtn = document.getElementById('start-btn');
const restartBtn = document.getElementById('restart-btn');
const healthOrbs = document.querySelectorAll('.life-orb');

// Game Constants
const STATE_MENU = 'MENU';
const STATE_PLAYING = 'PLAYING';
const STATE_GAMEOVER = 'GAMEOVER';

// Configuration
let config = {
    state: STATE_MENU,
    score: 0,
    combo: 1,
    lives: 3,
    difficulty: 1,
    spawnRate: 2000, // ms
    lastSpawn: 0,
    screenShake: 0
};
let xModeActive = false;

// Assets
const assets = {
    vessel: new Image(),
    fist: new Image(),
    planet: new Image(),
    processedFist: null // For background removal
};
assets.vessel.src = 'assets/vessel.png';
assets.fist.src = 'assets/fist.png';
assets.planet.src = 'assets/planet_bg.png';

// Background Removal Helper
assets.fist.onload = () => {
    assets.processedFist = document.createElement('canvas');
    assets.processedFist.width = assets.fist.width;
    assets.processedFist.height = assets.fist.height;
    const fctx = assets.processedFist.getContext('2d');
    fctx.drawImage(assets.fist, 0, 0);
    const imageData = fctx.getImageData(0, 0, assets.fist.width, assets.fist.height);
    const data = imageData.data;
    for (let i = 0; i < data.length; i += 4) {
        // If pixel is black (or very close to it), make it transparent
        if (data[i] < 30 && data[i+1] < 30 && data[i+2] < 30) {
            data[i+3] = 0;
        }
    }
    fctx.putImageData(imageData, 0, 0);
};

// Mouse tracking
const mouse = { x: 0, y: 0 };
let fistTrail = []; // Main fist trail
window.addEventListener('mousemove', (e) => {
    mouse.x = e.clientX;
    mouse.y = e.clientY;
    
    // Add to trail
    if (config.state === STATE_PLAYING) {
        fistTrail.unshift({x: mouse.x, y: mouse.y, life: 1});
        if (fistTrail.length > 20) fistTrail.pop();
    }
});

// Rocket Punch Class
class RocketPunch {
    constructor(x, y, vx, vy, angle) {
        this.x = x;
        this.y = y;
        this.vx = vx;
        this.vy = vy;
        this.angle = angle;
        this.size = 50;
        this.trail = [];
        this.active = true;
    }
    update() {
        this.x += this.vx;
        this.y += this.vy;
        
        this.trail.unshift({x: this.x, y: this.y, life: 1});
        if (this.trail.length > 15) this.trail.pop();
        
        // Deactivate if off-screen
        if (this.x < -100 || this.x > canvas.width + 100 || this.y < -100 || this.y > canvas.height + 100) {
            this.active = false;
        }
    }
    draw() {
        // Draw Trail
        ctx.save();
        ctx.lineWidth = 15;
        this.trail.forEach((point, i) => {
            ctx.globalAlpha = (1 - i / this.trail.length) * 0.5;
            ctx.strokeStyle = '#00f3ff';
            ctx.shadowBlur = 15;
            ctx.shadowColor = '#00f3ff';
            if (i > 0) {
                ctx.beginPath();
                ctx.moveTo(this.trail[i-1].x, this.trail[i-1].y);
                ctx.lineTo(point.x, point.y);
                ctx.stroke();
            }
        });
        ctx.restore();

        // Draw Fist
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.angle);
        ctx.shadowBlur = 20;
        ctx.shadowColor = '#00f3ff';
        const img = assets.processedFist || assets.fist;
        if (img.complete || assets.processedFist) {
            ctx.drawImage(img, -this.size/2, -this.size/2, this.size, this.size);
        }
        ctx.restore();
    }
}

let rocketPunches = [];

// Click for Rocket Blast
canvas.addEventListener('mousedown', (e) => {
    if (config.state !== STATE_PLAYING) return;
    
    const speed = 15;
    // 4 directions: 0, 90, 180, 270 degrees
    rocketPunches.push(new RocketPunch(mouse.x, mouse.y, speed, 0, 0)); // East
    rocketPunches.push(new RocketPunch(mouse.x, mouse.y, -speed, 0, Math.PI)); // West
    rocketPunches.push(new RocketPunch(mouse.x, mouse.y, 0, -speed, -Math.PI/2)); // North
    rocketPunches.push(new RocketPunch(mouse.x, mouse.y, 0, speed, Math.PI/2)); // South
    
    config.screenShake = 15;
});

// Resize handler
function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
}
window.addEventListener('resize', resize);
resize();

// Particle System
class Particle {
    constructor(x, y, color) {
        this.x = x;
        this.y = y;
        this.color = color;
        this.size = Math.random() * 4 + 1;
        this.speedX = (Math.random() - 0.5) * 10;
        this.speedY = (Math.random() - 0.5) * 10;
        this.life = 1;
        this.decay = Math.random() * 0.02 + 0.01;
    }
    update() {
        this.x += this.speedX;
        this.y += this.speedY;
        this.life -= this.decay;
        this.size *= 0.95;
    }
    draw() {
        ctx.save();
        ctx.globalAlpha = this.life;
        ctx.fillStyle = this.color;
        ctx.shadowBlur = 10;
        ctx.shadowColor = this.color;
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }
}

let particles = [];

// Background Fireworks
class Firework {
    constructor() {
        this.x = Math.random() * canvas.width;
        this.y = Math.random() * canvas.height;
        this.color = `hsl(${Math.random() * 360}, 100%, 60%)`;
        this.particles = [];
        for (let i = 0; i < 40; i++) {
            this.particles.push({
                dx: this.x,
                dy: this.y,
                vx: (Math.random() - 0.5) * 20,
                vy: (Math.random() - 0.5) * 20,
                life: 1,
                decay: 0.01 + Math.random() * 0.02
            });
        }
        this.rotation = 0;
        this.rotSpeed = (Math.random() - 0.5) * 0.2;
    }
    update() {
        this.rotation += this.rotSpeed;
        let alive = false;
        this.particles.forEach(p => {
            p.dx += p.vx;
            p.dy += p.vy;
            p.vy += 0.2; // roughly gravity
            p.life -= p.decay;
            if (p.life > 0) alive = true;
        });
        return alive;
    }
    draw() {
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        ctx.translate(-this.x, -this.y);
        ctx.shadowBlur = 15;
        ctx.shadowColor = this.color;
        this.particles.forEach(p => {
            if (p.life <= 0) return;
            ctx.globalAlpha = p.life;
            ctx.fillStyle = this.color;
            ctx.beginPath();
            ctx.arc(p.dx, p.dy, Math.max(0.1, p.life * 5), 0, Math.PI * 2);
            ctx.fill();
        });
        ctx.restore();
    }
}
let fireworks = [];

window.addEventListener('keydown', (e) => {
    if (e.key.toLowerCase() === 'x' && !xModeActive) { // Activate once
        xModeActive = true;
        if (config.spawnRate > 666) config.spawnRate = 666;
        for (let i = 0; i < 8; i++) {
            fireworks.push(new Firework());
        }
        config.screenShake += 10;
    }
});

// Enemies
class Enemy {
    constructor() {
        // Spawn from corners or edges
        const side = Math.floor(Math.random() * 4);
        if (side === 0) { // Top
            this.x = Math.random() * canvas.width;
            this.y = -50;
        } else if (side === 1) { // Right
            this.x = canvas.width + 50;
            this.y = Math.random() * canvas.height;
        } else if (side === 2) { // Bottom
            this.x = Math.random() * canvas.width;
            this.y = canvas.height + 50;
        } else { // Left
            this.x = -50;
            this.y = Math.random() * canvas.height;
        }

        this.type = this.pickType();
        this.size = 20;
        this.speed = (xModeActive ? 4 + config.difficulty * 1.2 : 2 + config.difficulty * 0.5) * (this.type === 'TRIANGLE' ? 1.5 : 1);
        this.hp = this.type === 'SQUARE' ? 3 : 1;
        this.angle = 0;
        this.rotationSpeed = Math.random() * 0.1;
        
        // Target center (vessel)
        const dx = canvas.width / 2 - this.x;
        const dy = canvas.height / 2 - this.y;
        this.dirAngle = Math.atan2(dy, dx);
    }

    pickType() {
        const r = Math.random();
        if (r < 0.05) return 'STAR';
        if (r < 0.2) return 'HEXAGON';
        if (r < 0.5) return 'SQUARE';
        return 'TRIANGLE';
    }

    update() {
        this.x += Math.cos(this.dirAngle) * this.speed;
        this.y += Math.sin(this.dirAngle) * this.speed;
        this.angle += this.rotationSpeed;
    }

    draw() {
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.angle);
        ctx.lineWidth = 3;
        ctx.shadowBlur = 15;
        
        switch(this.type) {
            case 'TRIANGLE':
                ctx.strokeStyle = '#ff007f'; // Neon Pink
                ctx.shadowColor = '#ff007f';
                ctx.beginPath();
                ctx.moveTo(0, -this.size);
                ctx.lineTo(this.size, this.size);
                ctx.lineTo(-this.size, this.size);
                ctx.closePath();
                break;
            case 'SQUARE':
                ctx.strokeStyle = '#00f3ff'; // Neon Blue
                ctx.shadowColor = '#00f3ff';
                ctx.strokeRect(-this.size, -this.size, this.size*2, this.size*2);
                // Inner indicator for hp
                if (this.hp > 1) {
                    ctx.strokeRect(-this.size/2, -this.size/2, this.size, this.size);
                }
                break;
            case 'HEXAGON':
                ctx.strokeStyle = '#39ff14'; // Neon Green
                ctx.shadowColor = '#39ff14';
                ctx.beginPath();
                for (let i = 0; i < 6; i++) {
                    ctx.lineTo(this.size * Math.cos(i * Math.PI / 3), this.size * Math.sin(i * Math.PI / 3));
                }
                ctx.closePath();
                break;
            case 'STAR':
                ctx.strokeStyle = '#f0f353'; // Neon Yellow
                ctx.shadowColor = '#f0f353';
                ctx.beginPath();
                for (let i = 0; i < 5; i++) {
                    ctx.lineTo(this.size * Math.cos(i * 4 * Math.PI / 5), this.size * Math.sin(i * 4 * Math.PI / 5));
                }
                ctx.closePath();
                break;
        }
        ctx.stroke();
        ctx.restore();
    }
}

let enemies = [];

// Vessel (Ship)
const vessel = {
    x: 0,
    y: 0,
    orbitRadius: 150,
    orbitAngle: 0,
    speed: 0.01,
    size: 60,
    update() {
        this.orbitAngle += this.speed;
        this.x = canvas.width / 2 + Math.cos(this.orbitAngle) * this.orbitRadius;
        this.y = canvas.height / 2 + Math.sin(this.orbitAngle) * this.orbitRadius;
    },
    draw() {
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.orbitAngle + Math.PI / 2);
        
        // Draw Vessel Image
        if (assets.vessel.complete) {
            ctx.drawImage(assets.vessel, -this.size/2, -this.size/2, this.size, this.size);
        } else {
            // Fallback
            ctx.fillStyle = '#fff';
            ctx.beginPath(); ctx.moveTo(0, -20); ctx.lineTo(15, 20); ctx.lineTo(-15, 20); ctx.fill();
        }
        
        // Shield aura
        ctx.strokeStyle = 'rgba(0, 243, 255, 0.3)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(0, 0, this.size * 0.8, 0, Math.PI * 2);
        ctx.stroke();
        
        ctx.restore();
    }
};

// Functions
function spawnEnemy() {
    enemies.push(new Enemy());
    config.lastSpawn = Date.now();
    // Decrease spawn rate over time
    if (xModeActive) {
        if (config.spawnRate > 150) config.spawnRate -= 5;
    } else {
        if (config.spawnRate > 500) config.spawnRate -= 10;
    }
    config.difficulty += 0.01;
}

function createExplosion(x, y, color, count = 10) {
    for (let i = 0; i < count; i++) {
        particles.push(new Particle(x, y, color));
    }
    config.screenShake = 10;
}

function updateHUD() {
    scoreEl.innerText = config.score.toString().padStart(6, '0');
    comboEl.innerText = `x${config.combo}`;
    
    // Update health orbs
    healthOrbs.forEach((orb, i) => {
        if (i < config.lives) orb.classList.add('filled');
        else orb.classList.remove('filled');
    });
}

function gameOver() {
    config.state = STATE_GAMEOVER;
    finalScoreEl.innerText = config.score;
    gameoverScreen.classList.remove('hidden');
    document.getElementById('game-container').style.cursor = 'default';
}

function resetGame() {
    config.score = 0;
    config.combo = 1;
    config.lives = 3;
    config.difficulty = 1;
    config.spawnRate = 2000;
    xModeActive = false;
    enemies = [];
    fireworks = [];
    particles = [];
    rocketPunches = [];
    fistTrail = [];
    config.state = STATE_PLAYING;
    gameoverScreen.classList.add('hidden');
    menuScreen.classList.add('hidden');
    document.getElementById('game-container').style.cursor = 'none';
    updateHUD();
}

// Main Loop
function loop() {
    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Draw Background
    if (assets.planet.complete) {
        ctx.save();
        ctx.globalAlpha = 0.4;
        ctx.drawImage(assets.planet, canvas.width/2 - 400, canvas.height/2 - 400, 800, 800);
        ctx.restore();
    }

    if (config.state === STATE_PLAYING) {
        // Screen Shake
        let shook = false;
        if (config.screenShake > 0) {
            ctx.save();
            shook = true;
            ctx.translate((Math.random() - 0.5) * config.screenShake, (Math.random() - 0.5) * config.screenShake);
            config.screenShake *= 0.9;
            if (config.screenShake < 0.5) config.screenShake = 0;
        }

        // Spawn Enemies
        if (Date.now() - config.lastSpawn > config.spawnRate) {
            spawnEnemy();
        }

        // Update & Draw Fireworks
        fireworks = fireworks.filter(f => f.update());
        fireworks.forEach(f => f.draw());

        // Update & Draw Particles
        particles = particles.filter(p => p.life > 0);
        particles.forEach(p => { p.update(); p.draw(); });

        // Update & Draw Vessel
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
        ctx.beginPath();
        ctx.arc(canvas.width / 2, canvas.height / 2, vessel.orbitRadius, 0, Math.PI * 2);
        ctx.stroke();
        vessel.update();
        vessel.draw();

        // Update & Draw Rocket Punches
        rocketPunches = rocketPunches.filter(rp => rp.active);
        rocketPunches.forEach(rp => {
            rp.update();
            rp.draw();
            
            // Rocket Collision with Enemies
            enemies.forEach((enemy, eIndex) => {
                const dx = enemy.x - rp.x;
                const dy = enemy.y - rp.y;
                const dist = Math.sqrt(dx*dx + dy*dy);
                if (dist < enemy.size + 30) {
                    createExplosion(enemy.x, enemy.y, enemy.strokeStyle || '#00f3ff');
                    config.score += 200 * config.combo;
                    enemies.splice(eIndex, 1);
                    updateHUD();
                }
            });
        });

        // Update & Draw Enemies
        enemies.forEach((enemy, index) => {
            enemy.update();
            enemy.draw();

            // Collision with Fists
            let hit = false;
            let fistPositions = [];
            
            if (xModeActive) {
                const fistDist = 45;
                fistPositions = [
                    {x: mouse.x - fistDist, y: mouse.y - fistDist},
                    {x: mouse.x + fistDist, y: mouse.y - fistDist},
                    {x: mouse.x + fistDist, y: mouse.y + fistDist},
                    {x: mouse.x - fistDist, y: mouse.y + fistDist}
                ];
            } else {
                fistPositions = [{x: mouse.x, y: mouse.y}];
            }

            for (let fPos of fistPositions) {
                const dx = enemy.x - fPos.x;
                const dy = enemy.y - fPos.y;
                const dist = Math.sqrt(dx*dx + dy*dy);
                const hitRadius = enemy.size + (xModeActive ? 30 : 20);
                if (dist < hitRadius) { 
                    hit = true;
                    break;
                }
            }
            
            if (hit) { // Impact!
                enemy.hp--;
                if (enemy.hp <= 0) {
                    let explodeColor = '#ff007f';
                    let points = 100;
                    
                    if (enemy.type === 'TRIANGLE') explodeColor = '#ff007f';
                    else if (enemy.type === 'SQUARE') explodeColor = '#00f3ff';
                    else if (enemy.type === 'HEXAGON') {
                        explodeColor = '#39ff14';
                        // Split logic
                        for (let i = 0; i < 2; i++) {
                            const mini = new Enemy();
                            mini.x = enemy.x; mini.y = enemy.y;
                            mini.type = 'TRIANGLE';
                            mini.size = 10;
                            mini.speed *= 1.5;
                            enemies.push(mini);
                        }
                    }
                    else if (enemy.type === 'STAR') {
                        explodeColor = '#f0f353';
                        // Clear all enemies
                        enemies.forEach(e => createExplosion(e.x, e.y, e.strokeStyle));
                        enemies = [];
                        points = 1000;
                    }

                    createExplosion(enemy.x, enemy.y, explodeColor);
                    config.score += points * config.combo;
                    config.combo += 1;
                    enemies.splice(index, 1);
                    updateHUD();
                } else {
                    // Soft hit
                    createExplosion(enemy.x, enemy.y, '#00f3ff', 3);
                }
            }

            // Collision with Vessel
            const vdx = enemy.x - vessel.x;
            const vdy = enemy.y - vessel.y;
            const vdist = Math.sqrt(vdx*vdx + vdy*vdy);
            
            if (vdist < enemy.size + 30) {
                config.lives--;
                config.combo = 1;
                config.screenShake = 20;
                enemies.splice(index, 1);
                updateHUD();
                
                if (config.lives <= 0) {
                    gameOver();
                }
            }

            // Clean up off-screen enemies (if missed)
            if (enemy.x < -100 || enemy.x > canvas.width + 100 || enemy.y < -100 || enemy.y > canvas.height + 100) {
                enemies.splice(index, 1);
                config.combo = 1;
                updateHUD();
            }
        });

        // Determine Offsets for Fists
        let offsets = [];
        if (xModeActive) {
            const fistDist = 45;
            offsets = [
                {x: -fistDist, y: -fistDist},
                {x: fistDist, y: -fistDist},
                {x: fistDist, y: fistDist},
                {x: -fistDist, y: fistDist}
            ];
        } else {
            offsets = [{x: 0, y: 0}];
        }

        // Draw Main Fist Trails
        ctx.save();
        ctx.lineWidth = 10;
        offsets.forEach(offset => {
            fistTrail.forEach((point, i) => {
                ctx.globalAlpha = (1 - i / fistTrail.length) * 0.3;
                ctx.strokeStyle = '#00f3ff';
                ctx.shadowBlur = 10;
                ctx.shadowColor = '#00f3ff';
                if (i > 0) {
                    ctx.beginPath();
                    ctx.moveTo(fistTrail[i-1].x + offset.x, fistTrail[i-1].y + offset.y);
                    ctx.lineTo(point.x + offset.x, point.y + offset.y);
                    ctx.stroke();
                }
            });
        });
        ctx.restore();

        // Draw Guardian Fists
        ctx.save();
        ctx.translate(mouse.x, mouse.y);
        ctx.shadowBlur = 20;
        ctx.shadowColor = '#00f3ff';
        const mainImg = assets.processedFist || assets.fist;
        
        if (mainImg.complete || assets.processedFist) {
            offsets.forEach(offset => {
                ctx.save();
                ctx.translate(offset.x, offset.y);
                if (xModeActive) {
                    ctx.rotate(Date.now() * 0.015);
                }
                ctx.drawImage(mainImg, -30, -30, 60, 60);
                ctx.restore();
            });
        } else {
            ctx.fillStyle = 'rgba(0, 243, 255, 0.5)';
            offsets.forEach(offset => {
                ctx.beginPath(); 
                ctx.arc(offset.x, offset.y, 20, 0, Math.PI * 2); 
                ctx.fill();
            });
        }
        ctx.restore();

        if (shook) ctx.restore();
    }

    requestAnimationFrame(loop);
}

// Event Listeners
startBtn.addEventListener('click', resetGame);
restartBtn.addEventListener('click', resetGame);

// Initial HUD
updateHUD();
loop();
