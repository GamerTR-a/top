const STORAGE_KEY_HISTORY = 'sosyo_history_v3';
let historyData = JSON.parse(localStorage.getItem(STORAGE_KEY_HISTORY)) || {};

const dateToStr = (date) => `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
const getTodayStr = () => dateToStr(new Date());

const addDaysToDate = (baseDateStr, daysOffset) => {
    const parts = baseDateStr.split('-');
    const date = new Date(parts[0], parts[1] - 1, parts[2]);
    date.setDate(date.getDate() + daysOffset);
    return date;
};

// DOM Seçimleri
const container = document.getElementById('slider-container');
const track = document.getElementById('slider-track');
const template = document.getElementById('card-template');
const btnReturnToday = document.getElementById('btn-return-today');
const canvas = document.getElementById('stardust');
const ctx = canvas.getContext('2d');

// Doğal Yaşam Temaları ve Hayvanlar (Gerçekçi görseller için etiketler)
const themes = [
    { class: 'theme-forest', keyword: 'forest,dark' },
    { class: 'theme-snow', keyword: 'snow,mountain,night' },
    { class: 'theme-desert', keyword: 'desert,night' }
];
const animals = ['🐰', '🦊', '🐻', '🐼', '🐯', '🐸', '🦉', '🦌'];

const futureDrafts = [
    "Görev: Serini koru!",
    "Doğa Yürüyüşü!",
    "Derin Nefes Al.",
    "Hedef: Yeni rekor kır!",
    "Bugün mola ver."
];

let todayStr = getTodayStr();
let cardsMap = new Map();

function getDayLabel(date, offset) {
    if (offset === 0) return "Bugün";
    if (offset === -1) return "Dün";
    if (offset === 1) return "Yarın";
    const monthNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    return `${date.getDate()} ${monthNames[date.getMonth()]}`;
}

// Güne ve ofsete bağlı tutarlı 'rastgele' indeks oluşturma
function getSeededRandom(offset) {
    return Math.abs(offset * 13 + 7);
}

function createCard(offset) {
    const cardDate = addDaysToDate(todayStr, offset);
    const dateStr = dateToStr(cardDate);
    const dayData = historyData[dateStr] || { count: 0, streak: 0 };
    
    const clone = template.content.cloneNode(true);
    const cardElement = clone.querySelector('.habitat-card');
    
    // Doğal Yaşam Teması ve Hayvan Ataması
    const seed = getSeededRandom(offset);
    const selectedTheme = themes[seed % themes.length];
    const selectedAnimal = animals[seed % animals.length];
    
    // Gerçekçi Arka Plan Görseli Ataması (LoremFlickr)
    // Benzersiz olması için seed parametresini kullanıyoruz:
    const randomImageUrl = `https://loremflickr.com/400/600/${selectedTheme.keyword}?lock=${seed}`;
    const habitatBg = cardElement.querySelector('.habitat-bg');
    habitatBg.style.backgroundImage = `url('${randomImageUrl}')`;
    
    cardElement.classList.add(selectedTheme.class);
    
    const animalEmoji = cardElement.querySelector('.animal-emoji');
    animalEmoji.textContent = selectedAnimal;
    
    cardElement.style.animationDelay = `${(Math.random() * -5).toFixed(2)}s`;

    // İçerik Doldurma
    const dayLabel = cardElement.querySelector('.day-label');
    const totalCount = cardElement.querySelector('.neon-number');
    const streakText = cardElement.querySelector('.streak-text');
    const streakBadge = cardElement.querySelector('.streak-badge');
    const btn = cardElement.querySelector('.neon-btn');
    const statusMessage = cardElement.querySelector('.status-message');
    const taskDraft = cardElement.querySelector('.task-draft-text');
    const taskNeon = taskDraft.querySelector('.neon-text');

    dayLabel.textContent = getDayLabel(cardDate, offset);
    totalCount.textContent = dayData.count;
    streakText.textContent = `Seri: ${dayData.streak} Gün`;
    if (dayData.streak > 0) streakBadge.classList.add('active');

    // Durum Belirleme
    if (offset < 0) {
        cardElement.classList.add('past');
        if (dayData.count === 0) totalCount.textContent = "-";
    } else if (offset > 0) {
        cardElement.classList.add('future');
        let randOffset = Math.abs(offset) % futureDrafts.length;
        taskNeon.textContent = futureDrafts[randOffset];
    } else {
        cardElement.classList.add('today');
        cardElement.id = 'today-card';
        btn.addEventListener('click', (e) => handlePopClick(e, dateStr, totalCount, streakText, streakBadge, statusMessage));
    }

    cardElement.dataset.offset = offset;
    return cardElement;
}

function initSlider() {
    track.innerHTML = '';
    cardsMap.clear();

    for (let i = -15; i <= 15; i++) {
        const card = createCard(i);
        track.appendChild(card);
        cardsMap.set(i, card);
    }

    setTimeout(() => {
        scrollToToday();
        update3DEffect();
    }, 100);
}

function scrollToToday() {
    const todayCard = document.getElementById('today-card');
    if (todayCard) {
        const scrollLeft = todayCard.offsetLeft - (container.clientWidth / 2) + (todayCard.clientWidth / 2);
        container.scrollTo({ left: scrollLeft, behavior: 'smooth' });
    }
}

// BUGÜNE DÖN BUTONU DİNLENCİSİ
btnReturnToday.addEventListener('click', () => {
    scrollToToday();
});

function handlePopClick(e, todayStr, countEl, streakEl, badgeEl, msgEl) {
    let dayData = historyData[todayStr] || { count: 0, streak: 0 };
    
    if (dayData.count === 0) {
        const yesterdayStr = dateToStr(addDaysToDate(todayStr, -1));
        const yesterdayData = historyData[yesterdayStr] || { count: 0, streak: 0 };
        dayData.streak = yesterdayData.count > 0 ? yesterdayData.streak + 1 : 1;
    }
    
    dayData.count += 1;
    historyData[todayStr] = dayData;
    localStorage.setItem(STORAGE_KEY_HISTORY, JSON.stringify(historyData));

    countEl.textContent = dayData.count;
    streakEl.textContent = `Seri: ${dayData.streak} Gün`;
    if (dayData.streak > 0) badgeEl.classList.add('active');

    countEl.classList.remove('pop');
    void countEl.offsetWidth; 
    countEl.classList.add('pop');
    
    createParticles(e);
    
    msgEl.textContent = "Harikasın! 🌱";
    msgEl.classList.add('show');
    setTimeout(() => msgEl.classList.remove('show'), 2000);
}

function createParticles(e) {
    const btn = e.currentTarget;
    const rect = btn.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;

    for (let i = 0; i < 6; i++) {
        const particle = document.createElement('div');
        particle.classList.add('floating-particle');
        
        const angle = Math.random() * Math.PI * 2;
        const radius = 50 + Math.random() * 50;
        particle.style.setProperty('--tx', `${Math.cos(angle) * radius}px`);
        particle.style.setProperty('--ty', `${Math.sin(angle) * radius}px`);
        
        particle.style.left = `${centerX}px`;
        particle.style.top = `${centerY}px`;
        
        const size = 6 + Math.random() * 6;
        particle.style.width = `${size}px`;
        particle.style.height = `${size}px`;
        
        const colors = ['#FFD700', '#FFFFFF', '#A0E2FF'];
        particle.style.background = colors[Math.floor(Math.random() * colors.length)];

        document.body.appendChild(particle);
        setTimeout(() => particle.remove(), 1000);
    }
}

// --- 3D SİLİNDİR VE AKTİF KART KONTROLÜ ---
let activeOffset = 0;

function update3DEffect() {
    const containerCenter = container.scrollLeft + (container.clientWidth / 2);
    let minDistance = Infinity;
    let closestOffset = 0;

    cardsMap.forEach((card, offset) => {
        const cardCenter = card.offsetLeft + (card.clientWidth / 2);
        const distance = cardCenter - containerCenter;
        const absDistance = Math.abs(distance);
        
        if (absDistance < minDistance) {
            minDistance = absDistance;
            closestOffset = offset;
        }

        const rotateY = distance * 0.05; 
        const translateZ = -absDistance * 0.6;
        const scale = Math.max(0.7, 1 - (absDistance * 0.0006));

        card.style.transform = `translateZ(${translateZ}px) rotateY(${rotateY}deg) scale(${scale})`;
        card.style.zIndex = Math.floor(100 - absDistance); 
        
        if (absDistance < 120) {
            card.classList.add('active-card');
        } else {
            card.classList.remove('active-card');
        }
    });

    // Bugüne Dön butonunun görünürlüğü
    if (closestOffset !== 0) {
        btnReturnToday.classList.add('visible');
    } else {
        btnReturnToday.classList.remove('visible');
    }
}

container.addEventListener('scroll', () => {
    requestAnimationFrame(update3DEffect);
});

// --- YILDIZ TOZU (PARALLAX BACKGROUND) EFEKTİ ---
let stars = [];
const numStars = 150;

function resizeCanvas() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
}

class Star {
    constructor() { this.reset(); }
    reset() {
        this.x = Math.random() * canvas.width;
        this.y = Math.random() * canvas.height;
        this.z = Math.random() * 2 + 0.1; 
        this.size = Math.random() * 1.5 + 0.5;
        this.alpha = Math.random() * 0.8 + 0.2;
        this.speedY = 0.5 / this.z; 
    }
    update() {
        this.y -= this.speedY;
        if (this.y < 0) {
            this.y = canvas.height;
            this.x = Math.random() * canvas.width;
        }
    }
    draw() {
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(200, 240, 255, ${this.alpha})`;
        ctx.fill();
        if (this.z < 1) {
            ctx.shadowBlur = 10;
            ctx.shadowColor = '#00F0FF';
        } else {
            ctx.shadowBlur = 0;
        }
    }
}

function initStars() {
    resizeCanvas();
    stars = [];
    for (let i = 0; i < numStars; i++) stars.push(new Star());
}

function animateStars() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    for (let star of stars) {
        star.update();
        star.draw();
    }
    requestAnimationFrame(animateStars);
}

document.addEventListener('mousemove', (e) => {
    const deltaX = (e.clientX - window.innerWidth / 2) * 0.05;
    const deltaY = (e.clientY - window.innerHeight / 2) * 0.05;
    for (let star of stars) {
        star.x -= deltaX / star.z * 0.05;
        star.y -= deltaY / star.z * 0.05;
    }
});

// START
initStars();
animateStars();
initSlider();
