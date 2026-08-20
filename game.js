(() => {
  "use strict";

  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");
  const ui = {
    gold: document.getElementById("gold"),
    lives: document.getElementById("lives"),
    wave: document.getElementById("wave"),
    preview: document.getElementById("preview"),
    shop: document.getElementById("shop"),
    bench: document.getElementById("bench"),
    start: document.getElementById("start"),
    merge: document.getElementById("merge"),
    sell: document.getElementById("sell"),
    reroll: document.getElementById("reroll"),
    reset: document.getElementById("reset"),
    banner: document.getElementById("banner")
  };

  const BOARD = { x: 84, y: 94, cols: 6, rows: 3, cellW: 118, cellH: 116 };
  const MAX_WAVES = 8;
  const TYPES = {
    corn: { name: "玉米", icon: "🌽", cost: 3, color: "#f2c84b", detail: "快速单体输出", damage: 12, interval: 0.9, hp: 78 },
    chili: { name: "辣椒", icon: "🌶️", cost: 4, color: "#e95e43", detail: "命中产生溅射", damage: 8, interval: 1.35, hp: 72 },
    potato: { name: "土豆", icon: "🥔", cost: 3, color: "#b88a52", detail: "高生命路障", damage: 0, interval: 9, hp: 230 },
    coffee: { name: "咖啡", icon: "☕", cost: 4, color: "#9a6a44", detail: "波后额外产金", damage: 0, interval: 9, hp: 68 }
  };
  const TYPE_KEYS = Object.keys(TYPES);
  const STAR_MULT = [0, 1, 2.15, 4.8];

  let state;
  let lastTime = performance.now();
  let toastTimer = 0;
  let audioContext = null;

  function makeUnit(type, star = 1) {
    return { id: crypto.randomUUID?.() || `${Date.now()}-${Math.random()}`, type, star, cooldown: Math.random() * 0.25, hp: maxUnitHp(type, star) };
  }

  function maxUnitHp(type, star) {
    return Math.round(TYPES[type].hp * (1 + (star - 1) * 0.7));
  }

  function resetGame() {
    state = {
      gold: 14,
      lives: 5,
      wave: 1,
      phase: "planning",
      grid: Array.from({ length: BOARD.rows }, () => Array(BOARD.cols).fill(null)),
      bench: Array(6).fill(null),
      shop: [],
      enemies: [],
      projectiles: [],
      particles: [],
      selected: null,
      mergeGroup: null,
      spawnQueue: [],
      spawnClock: 0,
      waveReward: 0,
      elapsed: 0
    };
    rollShop(false);
    hideBanner();
    updateAllUI();
  }

  function rollShop(charge = true) {
    if (state.phase !== "planning") return;
    if (charge) {
      if (state.gold < 1) return showToast("金币不足");
      state.gold -= 1;
      beep(240, 0.05);
    }
    state.shop = Array.from({ length: 5 }, () => TYPE_KEYS[Math.floor(Math.random() * TYPE_KEYS.length)]);
    renderShop();
    updateStatus();
  }

  function buyShop(index) {
    if (state.phase !== "planning") return;
    const type = state.shop[index];
    if (!type) return;
    const def = TYPES[type];
    const empty = state.bench.findIndex(v => !v);
    if (empty < 0) return showToast("备战区已满，请部署或出售单位");
    if (state.gold < def.cost) return showToast("金币不足");
    state.gold -= def.cost;
    state.bench[empty] = makeUnit(type);
    state.shop[index] = null;
    beep(420, 0.06);
    updateAllUI();
    const group = firstMergeGroup();
    if (group) showToast(`可以合成 ${TYPES[group.type].name}${"★".repeat(group.star)} 了！`);
  }

  function allUnitLocations() {
    const out = [];
    state.bench.forEach((unit, index) => unit && out.push({ zone: "bench", index, unit }));
    state.grid.forEach((row, r) => row.forEach((unit, c) => unit && out.push({ zone: "grid", row: r, col: c, unit })));
    return out;
  }

  function firstMergeGroup() {
    const buckets = new Map();
    for (const loc of allUnitLocations()) {
      if (loc.unit.star >= 3) continue;
      const key = `${loc.unit.type}:${loc.unit.star}`;
      if (!buckets.has(key)) buckets.set(key, []);
      buckets.get(key).push(loc);
    }
    for (const locations of buckets.values()) {
      if (locations.length >= 3) return { type: locations[0].unit.type, star: locations[0].unit.star, locations };
    }
    return null;
  }

  function beginMerge() {
    if (state.phase !== "planning") return;
    state.mergeGroup = firstMergeGroup();
    if (!state.mergeGroup) return;
    state.selected = null;
    showToast("请选择合成后要保留的位置");
    renderBench();
    updateButtons();
  }

  function mergeAt(targetLoc) {
    const group = state.mergeGroup;
    if (!group) return;
    const target = getUnit(targetLoc);
    if (!target || target.type !== group.type || target.star !== group.star) return;
    const others = group.locations.filter(loc => loc.unit.id !== target.id).slice(0, 2);
    others.forEach(removeUnitAt);
    target.star += 1;
    target.hp = maxUnitHp(target.type, target.star);
    target.cooldown = 0;
    state.mergeGroup = null;
    beep(660, 0.08);
    setTimeout(() => beep(880, 0.12), 70);
    burstAtLocation(targetLoc, TYPES[target.type].color);
    showToast(`${TYPES[target.type].name} 升到 ${"★".repeat(target.star)}！`);
    updateAllUI();
  }

  function getUnit(loc) {
    if (!loc) return null;
    return loc.zone === "bench" ? state.bench[loc.index] : state.grid[loc.row][loc.col];
  }

  function setUnit(loc, unit) {
    if (loc.zone === "bench") state.bench[loc.index] = unit;
    else state.grid[loc.row][loc.col] = unit;
  }

  function removeUnitAt(loc) { setUnit(loc, null); }

  function sameLocation(a, b) {
    if (!a || !b || a.zone !== b.zone) return false;
    return a.zone === "bench" ? a.index === b.index : a.row === b.row && a.col === b.col;
  }

  function selectOrMove(loc) {
    if (state.phase !== "planning") return;
    if (state.mergeGroup) return mergeAt(loc);
    const clicked = getUnit(loc);
    if (!state.selected) {
      if (clicked) state.selected = loc;
    } else if (sameLocation(state.selected, loc)) {
      state.selected = null;
    } else if (!clicked) {
      const moving = getUnit(state.selected);
      setUnit(loc, moving);
      removeUnitAt(state.selected);
      state.selected = null;
      beep(310, 0.04);
    } else {
      state.selected = loc;
    }
    renderBench();
    updateButtons();
  }

  function sellSelected() {
    if (state.phase !== "planning" || !state.selected) return;
    const unit = getUnit(state.selected);
    if (!unit) return;
    const value = Math.max(1, Math.floor(TYPES[unit.type].cost * Math.pow(2.2, unit.star - 1) * 0.65));
    state.gold += value;
    removeUnitAt(state.selected);
    state.selected = null;
    beep(520, 0.05);
    showToast(`出售获得 ${value} 金币`);
    updateAllUI();
  }

  function waveComposition(wave) {
    const normal = 3 + wave;
    const fast = Math.max(0, wave - 1);
    const armor = Math.max(0, Math.floor((wave - 2) / 2));
    return { normal, fast, armor };
  }

  function previewText(wave) {
    if (wave > MAX_WAVES) return "全部完成";
    const comp = waveComposition(wave);
    const parts = [`普通鼠 × ${comp.normal}`];
    if (comp.fast) parts.push(`飞毛腿 × ${comp.fast}`);
    if (comp.armor) parts.push(`锅盖鼠 × ${comp.armor}`);
    return parts.join("　");
  }

  function startWave() {
    if (state.phase !== "planning") return;
    if (!allUnitLocations().some(loc => loc.zone === "grid")) return showToast("请先部署至少一个单位");
    state.phase = "combat";
    state.selected = null;
    state.mergeGroup = null;
    state.enemies = [];
    state.projectiles = [];
    state.spawnQueue = buildSpawnQueue(state.wave);
    state.spawnClock = 0.45;
    state.waveReward = 0;
    beep(180, 0.12);
    updateAllUI();
  }

  function buildSpawnQueue(wave) {
    const comp = waveComposition(wave);
    const types = [
      ...Array(comp.normal).fill("normal"),
      ...Array(comp.fast).fill("fast"),
      ...Array(comp.armor).fill("armor")
    ];
    for (let i = types.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [types[i], types[j]] = [types[j], types[i]];
    }
    return types.map((type, i) => ({ type, delay: i === 0 ? 0.3 : 0.72 + Math.random() * 0.46 }));
  }

  function spawnEnemy(type) {
    const defs = {
      normal: { name: "普通鼠", hp: 48, speed: 29, damage: 20, reward: 1, color: "#91877d", icon: "🐭" },
      fast: { name: "飞毛腿", hp: 31, speed: 54, damage: 16, reward: 1, color: "#d1a568", icon: "🐁" },
      armor: { name: "锅盖鼠", hp: 112, speed: 20, damage: 28, reward: 2, color: "#7c8589", icon: "🐭" }
    };
    const base = defs[type];
    const scale = 1 + (state.wave - 1) * 0.12;
    state.enemies.push({ ...base, type, row: Math.floor(Math.random() * BOARD.rows), x: canvas.width + 28, hp: Math.round(base.hp * scale), maxHp: Math.round(base.hp * scale), attackClock: 0 });
  }

  function unitCenter(row, col) {
    return { x: BOARD.x + col * BOARD.cellW + BOARD.cellW / 2, y: BOARD.y + row * BOARD.cellH + BOARD.cellH / 2 };
  }

  function update(dt) {
    state.elapsed += dt;
    if (toastTimer > 0) {
      toastTimer -= dt;
      if (toastTimer <= 0 && state.phase !== "won" && state.phase !== "lost") hideBanner();
    }
    updateParticles(dt);
    if (state.phase !== "combat") return;

    state.spawnClock -= dt;
    if (state.spawnQueue.length && state.spawnClock <= 0) {
      const next = state.spawnQueue.shift();
      spawnEnemy(next.type);
      state.spawnClock = state.spawnQueue[0]?.delay ?? 0;
    }

    updateUnits(dt);
    updateProjectiles(dt);
    updateEnemies(dt);

    state.enemies = state.enemies.filter(e => e.hp > 0 && e.x > 24);
    if (!state.spawnQueue.length && !state.enemies.length) finishWave();
  }

  function updateUnits(dt) {
    for (let r = 0; r < BOARD.rows; r++) {
      for (let c = 0; c < BOARD.cols; c++) {
        const unit = state.grid[r][c];
        if (!unit) continue;
        unit.cooldown -= dt;
        if (unit.type === "potato" || unit.type === "coffee" || unit.cooldown > 0) continue;
        const center = unitCenter(r, c);
        const target = state.enemies
          .filter(e => e.row === r && e.hp > 0 && e.x > center.x - 12)
          .sort((a, b) => a.x - b.x)[0];
        if (!target) continue;
        const def = TYPES[unit.type];
        unit.cooldown = Math.max(0.28, def.interval - (unit.star - 1) * 0.12);
        state.projectiles.push({ x: center.x + 20, y: center.y - 7, row: r, type: unit.type, star: unit.star, targetId: target, speed: unit.type === "chili" ? 250 : 330 });
        beep(unit.type === "chili" ? 185 : 330, 0.018, 0.018);
      }
    }
  }

  function updateProjectiles(dt) {
    for (const p of state.projectiles) {
      p.x += p.speed * dt;
      const hit = state.enemies.find(e => e === p.targetId && e.hp > 0 && Math.abs(e.x - p.x) < 18);
      if (!hit) continue;
      const damage = TYPES[p.type].damage * STAR_MULT[p.star];
      hit.hp -= damage;
      if (p.type === "chili") {
        for (const other of state.enemies) {
          if (other !== hit && other.row === hit.row && Math.abs(other.x - hit.x) < 72) other.hp -= damage * 0.55;
        }
        burst(hit.x, laneY(hit.row), "#ef6c48", 8);
      } else {
        burst(hit.x, laneY(hit.row), "#f5d457", 4);
      }
      p.dead = true;
      if (hit.hp <= 0) {
        state.gold += hit.reward;
        state.waveReward += hit.reward;
        burst(hit.x, laneY(hit.row), "#d9bf8f", 12);
      }
    }
    state.projectiles = state.projectiles.filter(p => !p.dead && p.x < canvas.width + 30);
  }

  function updateEnemies(dt) {
    for (const enemy of state.enemies) {
      if (enemy.hp <= 0) continue;
      const blocker = findBlocker(enemy);
      if (blocker) {
        enemy.attackClock -= dt;
        if (enemy.attackClock <= 0) {
          blocker.unit.hp -= enemy.damage;
          enemy.attackClock = 0.72;
          beep(95, 0.025, 0.025);
          if (blocker.unit.hp <= 0) {
            burst(blocker.x, laneY(enemy.row), "#c99f61", 14);
            state.grid[enemy.row][blocker.col] = null;
          }
        }
      } else {
        enemy.x -= enemy.speed * dt;
      }
      if (enemy.x <= 42 && enemy.hp > 0) {
        enemy.hp = 0;
        state.lives -= 1;
        beep(70, 0.18, 0.08);
        showToast("有老鼠闯进粮仓了！", 1.15);
        if (state.lives <= 0) loseGame();
      }
    }
    updateStatus();
  }

  function findBlocker(enemy) {
    for (let c = BOARD.cols - 1; c >= 0; c--) {
      const unit = state.grid[enemy.row][c];
      if (!unit) continue;
      const x = unitCenter(enemy.row, c).x;
      if (enemy.x <= x + 43 && enemy.x >= x - 10) return { unit, col: c, x };
    }
    return null;
  }

  function finishWave() {
    if (state.phase !== "combat") return;
    const coffeeIncome = allUnitLocations()
      .filter(loc => loc.unit.type === "coffee")
      .reduce((sum, loc) => sum + loc.unit.star * 2, 0);
    const clearBonus = 3 + state.wave;
    state.gold += clearBonus + coffeeIncome;
    const finished = state.wave;
    if (finished >= MAX_WAVES) {
      state.phase = "won";
      showBanner(`守住了！粮仓安全\n总计获得 ${state.gold} 金币`);
      beep(620, 0.12);
      setTimeout(() => beep(820, 0.18), 100);
    } else {
      state.wave += 1;
      state.phase = "planning";
      rollShop(false);
      showToast(`第 ${finished} 波完成：奖励 ${clearBonus}${coffeeIncome ? `，咖啡收益 ${coffeeIncome}` : ""}`, 1.8);
    }
    updateAllUI();
  }

  function loseGame() {
    state.phase = "lost";
    state.enemies = [];
    state.projectiles = [];
    showBanner(`粮仓失守……\n坚持到第 ${state.wave} 波`);
    updateAllUI();
  }

  function laneY(row) { return BOARD.y + row * BOARD.cellH + BOARD.cellH / 2; }

  function burstAtLocation(loc, color) {
    if (loc.zone === "grid") {
      const p = unitCenter(loc.row, loc.col);
      burst(p.x, p.y, color, 22);
    }
  }

  function burst(x, y, color, count) {
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 24 + Math.random() * 85;
      state.particles.push({ x, y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: 0.35 + Math.random() * 0.45, maxLife: 0.8, color });
    }
  }

  function updateParticles(dt) {
    for (const p of state.particles) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 80 * dt;
    }
    state.particles = state.particles.filter(p => p.life > 0);
  }

  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    drawBackground();
    drawGrid();
    drawUnits();
    drawEnemies();
    drawProjectiles();
    drawParticles();
    drawPhaseLabel();
  }

  function drawBackground() {
    const g = ctx.createLinearGradient(0, 0, 0, canvas.height);
    g.addColorStop(0, "#a68554");
    g.addColorStop(1, "#675137");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#403221";
    ctx.fillRect(0, 0, 62, canvas.height);
    ctx.fillStyle = "#d4a64f";
    ctx.fillRect(12, 64, 38, 380);
    ctx.fillStyle = "#fff1bd";
    ctx.font = "700 17px Microsoft YaHei";
    ctx.textAlign = "center";
    ctx.fillText("粮", 31, 238);
    ctx.fillText("仓", 31, 266);
    ctx.fillStyle = "rgba(53, 40, 25, .34)";
    for (let x = 78; x < canvas.width; x += 130) ctx.fillRect(x, 0, 3, canvas.height);
  }

  function drawGrid() {
    for (let r = 0; r < BOARD.rows; r++) {
      const y = BOARD.y + r * BOARD.cellH;
      ctx.fillStyle = r % 2 ? "rgba(238, 210, 143, .24)" : "rgba(255, 235, 176, .31)";
      ctx.fillRect(BOARD.x - 8, y, canvas.width - BOARD.x + 8, BOARD.cellH - 5);
      for (let c = 0; c < BOARD.cols; c++) {
        const x = BOARD.x + c * BOARD.cellW;
        const loc = { zone: "grid", row: r, col: c };
        const unit = state.grid[r][c];
        const selected = state.selected && sameLocation(state.selected, loc);
        const mergeTarget = state.mergeGroup && unit && unit.type === state.mergeGroup.type && unit.star === state.mergeGroup.star;
        ctx.fillStyle = selected ? "rgba(255, 219, 91, .34)" : mergeTarget ? "rgba(113, 220, 98, .28)" : "rgba(41, 31, 21, .15)";
        ctx.fillRect(x + 4, y + 4, BOARD.cellW - 8, BOARD.cellH - 13);
        ctx.strokeStyle = selected ? "#ffe16b" : mergeTarget ? "#8fe77f" : "rgba(74, 55, 34, .42)";
        ctx.lineWidth = selected || mergeTarget ? 3 : 1;
        ctx.strokeRect(x + 4.5, y + 4.5, BOARD.cellW - 9, BOARD.cellH - 14);
      }
    }
    ctx.fillStyle = "rgba(37, 28, 18, .65)";
    ctx.font = "14px Microsoft YaHei";
    ctx.textAlign = "left";
    ctx.fillText("← 老鼠从右侧来袭", 744, 72);
  }

  function drawUnits() {
    for (let r = 0; r < BOARD.rows; r++) {
      for (let c = 0; c < BOARD.cols; c++) {
        const unit = state.grid[r][c];
        if (!unit) continue;
        const def = TYPES[unit.type];
        const p = unitCenter(r, c);
        ctx.save();
        ctx.translate(p.x, p.y - 7);
        ctx.fillStyle = "rgba(27, 20, 13, .25)";
        ctx.beginPath(); ctx.ellipse(0, 35, 35, 12, 0, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = def.color;
        ctx.globalAlpha = 0.2;
        ctx.beginPath(); ctx.arc(0, 0, 40 + unit.star * 3, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = 1;
        ctx.font = `${43 + unit.star * 5}px "Segoe UI Emoji"`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(def.icon, 0, -2);
        ctx.font = "700 13px Microsoft YaHei";
        ctx.fillStyle = "#ffdc57";
        ctx.fillText("★".repeat(unit.star), 0, -44);
        ctx.restore();
        drawHealthBar(p.x - 32, p.y + 39, 64, unit.hp / maxUnitHp(unit.type, unit.star), "#6fbd61");
      }
    }
  }

  function drawEnemies() {
    for (const e of state.enemies) {
      if (e.hp <= 0) continue;
      const y = laneY(e.row);
      ctx.fillStyle = "rgba(31, 22, 15, .25)";
      ctx.beginPath(); ctx.ellipse(e.x, y + 31, 28, 9, 0, 0, Math.PI * 2); ctx.fill();
      ctx.font = e.type === "armor" ? "52px Segoe UI Emoji" : "45px Segoe UI Emoji";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(e.icon, e.x, y);
      if (e.type === "armor") {
        ctx.font = "25px Segoe UI Emoji";
        ctx.fillText("🍳", e.x + 5, y - 24);
      }
      drawHealthBar(e.x - 29, y - 42, 58, e.hp / e.maxHp, "#d85e4c");
    }
  }

  function drawHealthBar(x, y, width, ratio, color) {
    ctx.fillStyle = "rgba(31, 24, 17, .68)";
    ctx.fillRect(x, y, width, 6);
    ctx.fillStyle = color;
    ctx.fillRect(x, y, width * Math.max(0, Math.min(1, ratio)), 6);
  }

  function drawProjectiles() {
    for (const p of state.projectiles) {
      ctx.fillStyle = p.type === "chili" ? "#ff6047" : "#f8db55";
      ctx.beginPath();
      ctx.arc(p.x, p.y, 4 + p.star, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function drawParticles() {
    for (const p of state.particles) {
      ctx.globalAlpha = Math.max(0, p.life / p.maxLife);
      ctx.fillStyle = p.color;
      ctx.fillRect(p.x, p.y, 4, 4);
    }
    ctx.globalAlpha = 1;
  }

  function drawPhaseLabel() {
    ctx.fillStyle = "rgba(35, 27, 18, .75)";
    ctx.fillRect(78, 20, 190, 48);
    ctx.fillStyle = state.phase === "combat" ? "#ffcf6a" : "#d7efb4";
    ctx.font = "700 18px Microsoft YaHei";
    ctx.textAlign = "left";
    const label = state.phase === "combat" ? `第 ${state.wave} 波进攻中` : state.phase === "planning" ? "准备阶段" : state.phase === "won" ? "胜利" : "失败";
    ctx.fillText(label, 94, 51);
  }

  function renderShop() {
    ui.shop.innerHTML = "";
    state.shop.forEach((type, index) => {
      const button = document.createElement("button");
      button.className = "shop-card";
      if (!type) {
        button.disabled = true;
        button.innerHTML = '<span class="slot-icon">✓</span><strong>已购买</strong><small>刷新后补货</small>';
      } else {
        const def = TYPES[type];
        button.disabled = state.phase !== "planning" || state.gold < def.cost;
        button.innerHTML = `<span class="slot-icon">${def.icon}</span><strong>${def.name}</strong><small>${def.detail}</small><span class="cost">🪙 ${def.cost}</span>`;
        button.addEventListener("click", () => buyShop(index));
      }
      ui.shop.appendChild(button);
    });
  }

  function renderBench() {
    ui.bench.innerHTML = "";
    state.bench.forEach((unit, index) => {
      const button = document.createElement("button");
      const loc = { zone: "bench", index };
      button.className = `slot${unit ? "" : " empty"}`;
      if (state.selected && sameLocation(state.selected, loc)) button.classList.add("selected");
      if (state.mergeGroup && unit && unit.type === state.mergeGroup.type && unit.star === state.mergeGroup.star) button.classList.add("merge-target");
      if (unit) {
        const def = TYPES[unit.type];
        button.innerHTML = `<span class="slot-icon">${def.icon}</span><span class="slot-name">${def.name} <span class="stars">${"★".repeat(unit.star)}</span></span>`;
        button.addEventListener("click", () => selectOrMove(loc));
      } else if (state.selected && state.phase === "planning") {
        button.addEventListener("click", () => selectOrMove(loc));
      }
      ui.bench.appendChild(button);
    });
  }

  function updateStatus() {
    ui.gold.textContent = state.gold;
    ui.lives.textContent = state.lives;
    ui.wave.textContent = `${Math.min(state.wave, MAX_WAVES)}/${MAX_WAVES}`;
    ui.preview.textContent = previewText(state.phase === "combat" ? Math.min(MAX_WAVES, state.wave + 1) : state.wave);
  }

  function updateButtons() {
    const planning = state.phase === "planning";
    const merge = firstMergeGroup();
    ui.start.disabled = !planning;
    ui.start.textContent = state.phase === "won" ? "已守住粮仓" : state.phase === "lost" ? "粮仓失守" : state.phase === "combat" ? `第 ${state.wave} 波进行中` : `开始第 ${state.wave} 波`;
    ui.reroll.disabled = !planning || state.gold < 1;
    ui.sell.disabled = !planning || !state.selected;
    ui.merge.disabled = !planning || !merge;
    ui.merge.classList.toggle("ready", Boolean(planning && merge));
    ui.merge.textContent = state.mergeGroup ? "选择保留位置" : merge ? `合成 ${TYPES[merge.type].name}${"★".repeat(merge.star)}` : "暂无可合成";
  }

  function updateAllUI() {
    updateStatus();
    renderShop();
    renderBench();
    updateButtons();
  }

  function showToast(text, seconds = 1.4) {
    ui.banner.textContent = text;
    ui.banner.hidden = false;
    toastTimer = seconds;
  }

  function showBanner(text) {
    ui.banner.textContent = text;
    ui.banner.style.whiteSpace = "pre-line";
    ui.banner.hidden = false;
    toastTimer = 0;
  }

  function hideBanner() {
    ui.banner.hidden = true;
    ui.banner.style.whiteSpace = "normal";
  }

  function beep(frequency, duration = 0.04, volume = 0.035) {
    try {
      audioContext ||= new AudioContext();
      const oscillator = audioContext.createOscillator();
      const gain = audioContext.createGain();
      oscillator.type = "sine";
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(volume, audioContext.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, audioContext.currentTime + duration);
      oscillator.connect(gain).connect(audioContext.destination);
      oscillator.start();
      oscillator.stop(audioContext.currentTime + duration);
    } catch { /* Audio is optional. */ }
  }

  function canvasLocation(event) {
    const rect = canvas.getBoundingClientRect();
    const x = (event.clientX - rect.left) * canvas.width / rect.width;
    const y = (event.clientY - rect.top) * canvas.height / rect.height;
    const col = Math.floor((x - BOARD.x) / BOARD.cellW);
    const row = Math.floor((y - BOARD.y) / BOARD.cellH);
    if (row < 0 || row >= BOARD.rows || col < 0 || col >= BOARD.cols) return null;
    return { zone: "grid", row, col };
  }

  canvas.addEventListener("click", event => {
    const loc = canvasLocation(event);
    if (loc) selectOrMove(loc);
  });
  ui.start.addEventListener("click", startWave);
  ui.merge.addEventListener("click", beginMerge);
  ui.sell.addEventListener("click", sellSelected);
  ui.reroll.addEventListener("click", () => rollShop(true));
  ui.reset.addEventListener("click", resetGame);

  function frame(now) {
    const dt = Math.min(0.033, (now - lastTime) / 1000);
    lastTime = now;
    update(dt);
    draw();
    requestAnimationFrame(frame);
  }

  resetGame();
  requestAnimationFrame(frame);
})();
