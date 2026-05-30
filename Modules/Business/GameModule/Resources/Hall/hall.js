(function () {
  const manifest = window.GAME_MANIFEST || { games: [] };
  const list = document.getElementById('game-list');
  const countTag = document.getElementById('section-count');
  const heroSub = document.getElementById('hero-sub');

  function fmtSize(bytes) {
    if (!bytes) return '';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(0) + ' KB';
    return (bytes / 1024 / 1024).toFixed(1) + ' MB';
  }

  // 占位渐变色:按 title 首字哈希挑一组,避免图标加载前白茬
  const GRADIENTS = [
    ['#34C759', '#07C160'],
    ['#5AC8FA', '#007AFF'],
    ['#FFCC00', '#FF9500'],
    ['#FF6B6B', '#FF3B30'],
    ['#BF5AF2', '#AF52DE'],
    ['#FF9500', '#FF6B00'],
  ];
  function gradFor(s) {
    let h = 0;
    for (const c of s) h = (h + c.charCodeAt(0)) & 0xffff;
    return GRADIENTS[h % GRADIENTS.length];
  }

  if (manifest.games.length === 0) {
    list.innerHTML = `
      <div class="empty">
        <div class="empty-icon">🎮</div>
        <div>暂无游戏,稍后再试</div>
      </div>`;
    countTag.textContent = '';
    return;
  }

  countTag.textContent = `共 ${manifest.games.length} 款`;
  heroSub.textContent = `${manifest.games.length} 款精选 · 即点即玩`;

  manifest.games.forEach(game => {
    const [c1, c2] = gradFor(game.title || game.id);
    const isInstalled = !!game.downloaded;
    const badge = isInstalled
      ? '<span class="badge-mini installed">已下载</span>'
      : '<span class="badge-mini new">NEW</span>';
    const action = isInstalled
      ? '<div class="action play">开始</div>'
      : '<div class="action download">下载</div>';
    const subtitle = game.subtitle && game.subtitle.length > 0
      ? game.subtitle
      : '小游戏';

    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <img class="icon" src="${game.icon}"
           style="background: linear-gradient(135deg, ${c1}, ${c2});"
           onerror="this.outerHTML='<div class=&quot;icon&quot; data-fallback=&quot;true&quot; style=&quot;background: linear-gradient(135deg, ${c1}, ${c2});&quot;>${(game.title || game.id || '?').charAt(0)}</div>';" />
      <div class="meta">
        <div class="title-row">
          <span class="title">${game.title}</span>
          ${badge}
        </div>
        <div class="sub">
          <span>${subtitle}</span>
          <span class="dot">·</span>
          <span>${fmtSize(game.size)}</span>
        </div>
      </div>
      ${action}
    `;
    card.onclick = () => {
      location.href = `wechat://game/run?id=${encodeURIComponent(game.id)}`;
    };
    list.appendChild(card);
  });
})();
