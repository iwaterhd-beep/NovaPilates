function escHome(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatPlanPrice(b) {
  const n = Number(b.precio || 0);
  const formatted = Number.isInteger(n)
    ? String(n)
    : n.toFixed(2).replace('.', ',');
  const monthly =
    ['mensual', 'trimestral'].includes(b.periodicidad) &&
    (b.sesiones == null || Number(b.sesiones) > 1);
  return monthly ? `${formatted} €/mes` : `${formatted} €`;
}

function renderPlansFallback(grid) {
  if (!grid) return;
  grid.innerHTML = `
    <article class="card plan-card">
      <p class="plan-tag">Primera experiencia</p>
      <h3 class="plan-title">Clase de prueba</h3>
      <p class="plan-price">25 €</p>
      <p>Descubre la experiencia NŌVA antes de elegir tu plan. Disponible una única vez por persona.</p>
    </article>
    <article class="card plan-card">
      <p class="plan-tag">Flow 01</p>
      <h3 class="plan-title">NŌVA FLOW</h3>
      <p class="plan-meta">2 días / semana</p>
      <p class="plan-price">145 €/mes</p>
      <p>Ideal para comenzar y crear una rutina constante con la flexibilidad que necesitas.</p>
    </article>
    <article class="card plan-card">
      <p class="plan-tag">Flow 02</p>
      <h3 class="plan-title">NŌVA BALANCE</h3>
      <p class="plan-meta">3 días / semana</p>
      <p class="plan-price">185 €/mes</p>
      <p>El equilibrio perfecto entre compromiso, progreso y tiempo para ti.</p>
    </article>
    <article class="card plan-card">
      <p class="plan-tag">Flow 03</p>
      <h3 class="plan-title">NŌVA SIGNATURE</h3>
      <p class="plan-meta">5 días / semana</p>
      <p class="plan-price">225 €/mes</p>
      <p>La experiencia más completa para integrar el movimiento en tu estilo de vida.</p>
    </article>
  `;
}

async function loadPublicPlans() {
  const grid = document.getElementById('plansGrid');
  if (!grid || typeof novaSupabase === 'undefined') {
    renderPlansFallback(grid);
    return;
  }
  try {
    const { data, error } = await novaSupabase
      .from('tipos_bono')
      .select('nombre,descripcion,precio,sesiones,periodicidad,orden,web_tag,web_meta')
      .eq('visible_web', true)
      .eq('activo', true)
      .order('orden', { ascending: true });
    if (error) throw error;
    if (!data || !data.length) {
      renderPlansFallback(grid);
      return;
    }
    grid.innerHTML = data.map((b) => `
      <article class="card plan-card">
        <p class="plan-tag">${escHome(b.web_tag || 'Plan')}</p>
        <h3 class="plan-title">${escHome(b.nombre)}</h3>
        ${b.web_meta ? `<p class="plan-meta">${escHome(b.web_meta)}</p>` : ''}
        <p class="plan-price">${escHome(formatPlanPrice(b))}</p>
        <p>${escHome(b.descripcion || '')}</p>
      </article>
    `).join('');
  } catch (err) {
    console.warn('Planes web:', err);
    renderPlansFallback(grid);
  }
}

async function loadHomeSections() {
  const root = document.getElementById('page-root');
  if (!root) return;

  try {
    const response = await fetch('sections/home_zen.html');
    if (!response.ok) throw new Error('No se pudo cargar la home.');
    root.innerHTML = await response.text();
    await loadPublicPlans();
  } catch (error) {
    root.innerHTML = `
      <section class="section">
        <div class="container">
          <h1 style="font-family: var(--font-display); margin-bottom: 1rem;">NŌVA PILATES STUDIO</h1>
          <p>No se pudo cargar la portada. Revisa el archivo <code>sections/home_zen.html</code>.</p>
        </div>
      </section>
    `;
    console.error(error);
  }
}

loadHomeSections();
