function escShop(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const RITUAL_PRODUCTS = [
  {
    id: 'ritual-botella',
    title: 'Botella NŌVA Acero Inoxidable',
    category: 'Accesorios & Hidratación',
    description: 'Botella térmica de acero inoxidable de doble pared libre de BPA. Mantiene tus bebidas frías 24h o calientes 12h para acompañar tus sesiones de Reformer y suelo.',
    price: 28,
    img: '/assets/shop/botella-nova.png',
    details: ['Capacidades: 500 ml y 750 ml', 'Acabado mate antideslizante', 'Tapón hermético a prueba de fugas']
  },
  {
    id: 'ritual-tote',
    title: 'Tote Bag NŌVA Studio',
    category: 'Accesorios',
    description: 'Bolsa de algodón orgánico de alto gramaje con compartimento interior diseñado para transportar toalla, esterilla enrollada, muda y botella.',
    price: 32,
    img: '/assets/shop/tote-studio.png',
    details: ['100% Algodón orgánico premium', 'Asas reforzadas para hombro', 'Medidas: 42 cm x 38 cm x 16 cm']
  },
  {
    id: 'ritual-camiseta',
    title: 'Camiseta Técnica Suave',
    category: 'Textil & Movimiento',
    description: 'Camiseta transpirable con tecnología de secado rápido y tacto segunda piel. Patronaje ergonómico pensado para permitir total libertad en cada extensión.',
    price: 35,
    img: '/assets/shop/camiseta-tecnica.png',
    details: ['Tallas: XS, S, M, L, XL', 'Tejido elástico en 4 direcciones', 'Marca NŌVA serigrafiada en tono sutil']
  },
  {
    id: 'ritual-bandas',
    title: 'Set de Bandas Elásticas de Tela',
    category: 'Movimiento Consciente',
    description: 'Pack de 3 bandas elásticas textiles con interior de agarre antideslizante. Ideales para activación de glúteo, trabajo en Barre y clases de Sculpt.',
    price: 22,
    img: '/assets/shop/banda-resistencia.png',
    details: ['3 niveles de resistencia: Ligera, Media, Intensa', 'No se enrollan ni pellizcan', 'Incluye bolsita de transporte transpirable']
  }
];

let selectedProduct = null;

function renderShopGrid() {
  const grid = document.getElementById('shopGrid');
  if (!grid) return;
  grid.innerHTML = RITUAL_PRODUCTS.map((p) => `
    <article class="shop-card">
      <div class="shop-card-media" onclick="openProductModal('${p.id}')">
        <img class="shop-card-img" src="${p.img}" alt="${escShop(p.title)}" onerror="this.src='/assets/branding/logo-circulo-nova.png'" loading="lazy" />
      </div>
      <div class="shop-card-body">
        <span class="shop-card-tag">${escShop(p.category)}</span>
        <h3 class="shop-card-title">${escShop(p.title)}</h3>
        <p class="shop-card-price">${p.price} €</p>
        <p class="shop-card-desc">${escShop(p.description)}</p>
        <span class="shop-card-carta-note">Disponible en el estudio</span>
      </div>
    </article>
  `).join('');
}

function ensureProductModal() {
  if (document.getElementById('productDetailModal')) return;
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="product-modal-backdrop" id="productModalBackdrop" onclick="closeProductModal()"></div>
    <div class="product-modal" id="productDetailModal" role="dialog" aria-modal="true" aria-labelledby="modalProdTitle" hidden>
      <div class="product-modal-layout">
        <button type="button" class="product-modal-close" onclick="closeProductModal()" aria-label="Cerrar">×</button>
        <div class="product-modal-gallery">
          <img class="product-modal-img" id="modalProdImg" src="" alt="" />
        </div>
        <div class="product-modal-info">
          <span class="product-modal-tag" id="modalProdTag"></span>
          <h2 class="product-modal-title" id="modalProdTitle"></h2>
          <p class="product-modal-price" id="modalProdPrice"></p>
          <p class="product-modal-desc" id="modalProdDesc"></p>
          <ul id="modalProdDetails" style="list-style:none; padding:0; margin:0 0 1rem; display:flex; flex-direction:column; gap:.35rem; font-size:.85rem; color:var(--ink-soft);"></ul>
          <div style="margin-top:auto; padding-top:1rem; border-top:1px dashed var(--line);">
            <p style="font-size:.85rem; color:var(--dash); margin-bottom:.75rem;">
              ✨ Puedes consultar, probarte o adquirir este producto directamente en la recepción del centro durante tu visita.
            </p>
            <button type="button" class="btn btn-primary" style="width:100%;" onclick="closeProductModal()">
              Cerrar detalle
            </button>
          </div>
        </div>
      </div>
    </div>`;
  while (wrap.firstChild) document.body.appendChild(wrap.firstChild);
}

window.openProductModal = function(id) {
  ensureProductModal();
  const prod = RITUAL_PRODUCTS.find(p => p.id === id);
  if (!prod) return;
  selectedProduct = prod;

  const img = document.getElementById('modalProdImg');
  const tag = document.getElementById('modalProdTag');
  const title = document.getElementById('modalProdTitle');
  const price = document.getElementById('modalProdPrice');
  const desc = document.getElementById('modalProdDesc');
  const details = document.getElementById('modalProdDetails');

  if (img) img.src = prod.img;
  if (tag) tag.textContent = prod.category;
  if (title) title.textContent = prod.title;
  if (price) price.textContent = `${prod.price} €`;
  if (desc) desc.textContent = prod.description;
  if (details) {
    details.innerHTML = (prod.details || []).map(d => `<li style="position:relative; padding-left:1rem;"><span style="position:absolute; left:0; color:var(--accent);">•</span> ${escShop(d)}</li>`).join('');
  }

  const modal = document.getElementById('productDetailModal');
  const backdrop = document.getElementById('productModalBackdrop');
  if (modal && backdrop) {
    modal.hidden = false;
    requestAnimationFrame(() => {
      modal.classList.add('is-open');
      backdrop.classList.add('is-open');
    });
  }
};

window.closeProductModal = function() {
  const modal = document.getElementById('productDetailModal');
  const backdrop = document.getElementById('productModalBackdrop');
  if (!modal) return;
  modal.classList.remove('is-open');
  if (backdrop) backdrop.classList.remove('is-open');
  setTimeout(() => {
    modal.hidden = true;
  }, 250);
};

async function loadTiendaSections() {
  const root = document.getElementById('page-root');
  if (!root) return;
  try {
    const res = await fetch('sections/tienda_zen.html');
    if (!res.ok) throw new Error('No se pudo cargar la vista de NŌVA Ritual.');
    root.innerHTML = await res.text();
    renderShopGrid();
  } catch (err) {
    console.error(err);
  }
}

loadTiendaSections();
