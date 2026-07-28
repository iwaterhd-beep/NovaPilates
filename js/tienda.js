function escShop(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatShopPrice(amount, currency) {
  if (amount == null || Number.isNaN(Number(amount))) return '—';
  const n = Number(amount);
  const formatted = Number.isInteger(n)
    ? String(n)
    : n.toFixed(2).replace('.', ',');
  const cur = String(currency || 'eur').toLowerCase();
  if (cur === 'eur') return `${formatted} €`;
  return `${formatted} ${cur.toUpperCase()}`;
}

/** Catálogo de vista previa hasta conectar Medusa Cloud / backend. */
const SHOP_PREVIEW_PRODUCTS = [
  {
    id: 'preview-botella',
    variantId: 'preview-botella',
    title: 'Botella NŌVA',
    description: 'Hidratación ligera para antes y después de clase.',
    thumbnail: '/assets/shop/botella-nova.jpg?v=2',
    images: ['/assets/shop/botella-nova.jpg?v=2'],
    price: 28,
    currency: 'eur',
    collection: 'Accesorios',
    sizeLabel: 'Capacidad',
    sizes: ['500 ml', '750 ml'],
    sizeChart: {
      title: 'Guía de capacidad',
      note: 'Medidas aproximadas del envase.',
      headers: ['Opción', 'Volumen', 'Altura', 'Uso'],
      rows: [
        ['500 ml', '500 ml', '22 cm', 'Día a día / clase'],
        ['750 ml', '750 ml', '26 cm', 'Sesiones largas'],
      ],
    },
  },
  {
    id: 'preview-tote',
    variantId: 'preview-tote',
    title: 'Tote Studio',
    description: 'Bolsa de lona para esterilla, muda y lo esencial.',
    thumbnail: '/assets/shop/tote-studio.jpg?v=2',
    images: ['/assets/shop/tote-studio.jpg?v=2'],
    price: 32,
    currency: 'eur',
    collection: 'Accesorios',
    sizeLabel: 'Talla',
    sizes: ['Única'],
    sizeChart: {
      title: 'Medidas del tote',
      note: 'Capacidad pensada para esterilla enrollada y muda.',
      headers: ['Talla', 'Ancho', 'Alto', 'Fondo', 'Asas'],
      rows: [
        ['Única', '42 cm', '38 cm', '16 cm', '62 cm'],
      ],
    },
  },
  {
    id: 'preview-camiseta',
    variantId: 'preview-camiseta',
    title: 'Camiseta técnica',
    description: 'Tejido moisture-wicking y quick-dry, marca discreta.',
    thumbnail: '/assets/shop/camiseta-tecnica.jpg?v=2',
    images: ['/assets/shop/camiseta-tecnica.jpg?v=2'],
    price: 38,
    currency: 'eur',
    collection: 'Ropa',
    sizeLabel: 'Talla',
    sizes: ['XS', 'S', 'M', 'L', 'XL'],
    sizeChart: {
      title: 'Tabla de tallas',
      note: 'Medidas en cm. Si estás entre dos tallas, elige la superior.',
      headers: ['Talla', 'Pecho', 'Cintura', 'Largo'],
      rows: [
        ['XS', '82–86', '66–70', '64'],
        ['S', '86–90', '70–74', '66'],
        ['M', '90–96', '74–80', '68'],
        ['L', '96–102', '80–86', '70'],
        ['XL', '102–108', '86–92', '72'],
      ],
    },
  },
  {
    id: 'preview-banda',
    variantId: 'preview-banda',
    title: 'Banda de resistencia',
    description: 'Loop de tela para suelo o casa. Elige la intensidad.',
    thumbnail: '/assets/shop/banda-resistencia.jpg?v=2',
    images: ['/assets/shop/banda-resistencia.jpg?v=2'],
    price: 18,
    currency: 'eur',
    collection: 'Movimiento',
    sizeLabel: 'Resistencia',
    sizes: ['Light', 'Medium', 'Hard'],
    sizeChart: {
      title: 'Guía de resistencia',
      note: 'Empieza por Light si eres principiante; Medium es el punto de partida habitual.',
      headers: ['Nivel', 'Tensión', 'Ideal para'],
      rows: [
        ['Light', 'Baja', 'Movilidad y activación'],
        ['Medium', 'Media', 'Fuerza controlada'],
        ['Hard', 'Alta', 'Trabajo avanzado'],
      ],
    },
  },
];

let shopCatalogByKey = new Map();
let productModalKey = null;
let productModalIndex = 0;
let productModalSize = null;
let productModalQty = 1;

function shopProductKey(p) {
  return String(p.variantId || p.id || '');
}

function productImages(p) {
  if (!p) return [];
  const list = Array.isArray(p.images)
    ? p.images.map((img) => (typeof img === 'string' ? img : img && img.url)).filter(Boolean)
    : [];
  if (list.length) return [...new Set(list)];
  if (p.thumbnail) return [p.thumbnail];
  return [];
}


function productSizes(p) {
  return Array.isArray(p?.sizes) ? p.sizes.filter(Boolean) : [];
}

function productSizeLabel(p) {
  return (p && p.sizeLabel) || 'Talla';
}

function productRequiresSize(p) {
  return productSizes(p).length > 0;
}

function selectedSizeFromModal() {
  const active = document.querySelector('#productModalSizes .product-size-btn.is-active');
  return active ? active.getAttribute('data-size') : productModalSize;
}

function indexShopCatalog(products) {
  shopCatalogByKey = new Map();
  (products || []).forEach((p) => {
    const key = shopProductKey(p);
    if (key) shopCatalogByKey.set(key, p);
  });
}

function renderShopProducts(grid, products) {
  if (!grid) return;
  indexShopCatalog(products);
  grid.innerHTML = products
    .map((p) => {
      const key = shopProductKey(p);
      const tag = p.collection || 'Merch';
      const thumb = productImages(p)[0] || p.thumbnail || null;
      const media = thumb
        ? `<img class="shop-card-img" src="${escShop(thumb)}" alt="${escShop(p.title || '')}" loading="lazy" decoding="async" />`
        : `<div class="shop-card-placeholder" aria-hidden="true"><span>${escShop((p.title || 'N').charAt(0))}</span></div>`;
      return `
      <article class="shop-card reveal" data-product-key="${escShop(key)}">
        <button type="button" class="shop-card-media" data-open-product="${escShop(key)}" aria-label="Ver ${escShop(p.title || 'producto')}">
          ${media}
        </button>
        <div class="shop-card-body">
          <button type="button" class="shop-card-open" data-open-product="${escShop(key)}">
            <p class="shop-card-tag">${escShop(tag)}</p>
            <h3 class="shop-card-title">${escShop(p.title)}</h3>
            <p class="shop-card-price">${escShop(formatShopPrice(p.price, p.currency))}</p>
            <p class="shop-card-desc">${escShop(p.description || '')}</p>
          </button>
          <button type="button" class="btn btn-outline shop-card-cta" data-add-to-cart="${escShop(key)}">Añadir al carrito</button>
        </div>
      </article>`;
    })
    .join('');
}

function ensureProductModal() {
  if (document.getElementById('productModal')) return;
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="product-modal-backdrop" id="productModalBackdrop" hidden></div>
    <div class="product-modal" id="productModal" role="dialog" aria-modal="true" aria-labelledby="productModalTitle" hidden>
      <div class="product-modal-layout">
        <button type="button" class="product-modal-close" id="productModalClose" aria-label="Cerrar">×</button>
        <div class="product-modal-gallery">
          <button type="button" class="product-modal-nav product-modal-prev" id="productModalPrev" aria-label="Foto anterior">‹</button>
          <div class="product-modal-frame">
            <img id="productModalImg" class="product-modal-img" alt="" />
          </div>
          <button type="button" class="product-modal-nav product-modal-next" id="productModalNext" aria-label="Foto siguiente">›</button>
          <div class="product-modal-dots" id="productModalDots" hidden></div>
        </div>
        <div class="product-modal-info">
          <p class="product-modal-tag" id="productModalTag"></p>
          <h2 class="product-modal-title" id="productModalTitle"></h2>
          <p class="product-modal-price" id="productModalPrice"></p>
          <p class="product-modal-desc" id="productModalDesc"></p>
          <div class="product-modal-options" id="productModalOptions" hidden>
            <div class="product-size-row">
              <div class="product-size-head">
                <span class="product-size-label" id="productModalSizeLabel">Talla</span>
                <button type="button" class="product-size-guide-btn" id="productModalGuideBtn" hidden>Guía de tallas</button>
              </div>
              <div class="product-size-list" id="productModalSizes" role="listbox" aria-label="Elegir talla"></div>
              <p class="product-size-hint" id="productModalSizeHint" hidden>Elige una opción para continuar.</p>
            </div>
            <div class="product-size-chart" id="productModalChart" hidden></div>
            <div class="product-qty-row">
              <span class="product-size-label">Cantidad</span>
              <div class="product-qty-controls">
                <button type="button" class="product-qty-btn" id="productModalQtyDec" aria-label="Quitar uno">−</button>
                <span class="product-qty-val" id="productModalQty">1</span>
                <button type="button" class="product-qty-btn" id="productModalQtyInc" aria-label="Añadir uno">+</button>
              </div>
            </div>
          </div>
          <button type="button" class="btn btn-primary product-modal-cta" id="productModalAdd">Añadir al carrito</button>
        </div>
      </div>
    </div>`;
  while (wrap.firstChild) document.body.appendChild(wrap.firstChild);
}

function isProductModalOpen() {
  const modal = document.getElementById('productModal');
  return Boolean(modal && !modal.hidden);
}

function renderProductModalGallery() {
  const product = productModalKey ? shopCatalogByKey.get(productModalKey) : null;
  const images = productImages(product);
  const img = document.getElementById('productModalImg');
  const prev = document.getElementById('productModalPrev');
  const next = document.getElementById('productModalNext');
  const dots = document.getElementById('productModalDots');
  if (!img) return;

  if (!images.length) {
    img.removeAttribute('src');
    img.alt = '';
    img.hidden = true;
  } else {
    const i = ((productModalIndex % images.length) + images.length) % images.length;
    productModalIndex = i;
    img.hidden = false;
    img.src = images[i];
    img.alt = product?.title || '';
  }

  const multi = images.length > 1;
  if (prev) prev.hidden = !multi;
  if (next) next.hidden = !multi;
  if (dots) {
    dots.hidden = !multi;
    if (multi) {
      dots.innerHTML = images
        .map(
          (_, i) =>
            `<button type="button" class="product-modal-dot${i === productModalIndex ? ' is-active' : ''}" data-product-dot="${i}" aria-label="Foto ${i + 1}"></button>`
        )
        .join('');
    } else {
      dots.innerHTML = '';
    }
  }
}

function renderProductModalOptions(product) {
  const options = document.getElementById('productModalOptions');
  const sizesEl = document.getElementById('productModalSizes');
  const labelEl = document.getElementById('productModalSizeLabel');
  const guideBtn = document.getElementById('productModalGuideBtn');
  const chartEl = document.getElementById('productModalChart');
  const hint = document.getElementById('productModalSizeHint');
  const qtyEl = document.getElementById('productModalQty');
  if (!options || !sizesEl) return;

  const sizes = productSizes(product);
  productModalQty = 1;
  if (qtyEl) qtyEl.textContent = '1';

  if (!sizes.length) {
    options.hidden = true;
    productModalSize = null;
    sizesEl.innerHTML = '';
    if (guideBtn) guideBtn.hidden = true;
    if (chartEl) {
      chartEl.hidden = true;
      chartEl.innerHTML = '';
    }
    if (hint) hint.hidden = true;
    return;
  }

  options.hidden = false;
  if (labelEl) labelEl.textContent = productSizeLabel(product);
  productModalSize = sizes.length === 1 ? sizes[0] : null;
  sizesEl.innerHTML = sizes
    .map((size) => {
      const active = size === productModalSize ? ' is-active' : '';
      return `<button type="button" class="product-size-btn${active}" role="option" aria-selected="${size === productModalSize ? 'true' : 'false'}" data-size="${escShop(size)}">${escShop(size)}</button>`;
    })
    .join('');

  const chart = product.sizeChart;
  if (guideBtn) guideBtn.hidden = !chart;
  if (chartEl) {
    chartEl.hidden = true;
    if (chart) {
      const headers = (chart.headers || []).map((h) => `<th>${escShop(h)}</th>`).join('');
      const rows = (chart.rows || [])
        .map((row) => `<tr>${(row || []).map((cell) => `<td>${escShop(cell)}</td>`).join('')}</tr>`)
        .join('');
      chartEl.innerHTML =
        `<p class="product-size-chart-title">${escShop(chart.title || 'Guía de tallas')}</p>` +
        (chart.note ? `<p class="product-size-chart-note">${escShop(chart.note)}</p>` : '') +
        `<div class="product-size-chart-scroll"><table><thead><tr>${headers}</tr></thead><tbody>${rows}</tbody></table></div>`;
    } else {
      chartEl.innerHTML = '';
    }
  }
  if (hint) hint.hidden = true;
  if (guideBtn) guideBtn.textContent = 'Guía de tallas';
}

function openProductModal(key) {
  const product = shopCatalogByKey.get(key);
  if (!product) return;
  ensureProductModal();
  productModalKey = key;
  productModalIndex = 0;

  const tag = document.getElementById('productModalTag');
  const title = document.getElementById('productModalTitle');
  const price = document.getElementById('productModalPrice');
  const desc = document.getElementById('productModalDesc');
  if (tag) tag.textContent = product.collection || 'Merch';
  if (title) title.textContent = product.title || '';
  if (price) price.textContent = formatShopPrice(product.price, product.currency);
  if (desc) desc.textContent = product.description || '';

  renderProductModalOptions(product);
  renderProductModalGallery();

  const modal = document.getElementById('productModal');
  const backdrop = document.getElementById('productModalBackdrop');
  if (!modal) return;
  modal.hidden = false;
  if (backdrop) backdrop.hidden = false;
  document.body.classList.add('product-modal-open');
  requestAnimationFrame(() => {
    modal.classList.add('is-open');
    if (backdrop) backdrop.classList.add('is-open');
  });
  document.getElementById('productModalClose')?.focus();
}

function closeProductModal() {
  const modal = document.getElementById('productModal');
  const backdrop = document.getElementById('productModalBackdrop');
  if (!modal || modal.hidden) return;
  modal.classList.remove('is-open');
  if (backdrop) backdrop.classList.remove('is-open');
  document.body.classList.remove('product-modal-open');
  window.setTimeout(() => {
    modal.hidden = true;
    if (backdrop) backdrop.hidden = true;
    productModalKey = null;
    productModalIndex = 0;
    productModalSize = null;
    productModalQty = 1;
  }, 240);
}

function stepProductModal(delta) {
  const product = productModalKey ? shopCatalogByKey.get(productModalKey) : null;
  const images = productImages(product);
  if (images.length < 2) return;
  productModalIndex = (productModalIndex + delta + images.length) % images.length;
  renderProductModalGallery();
}

function addProductToCart(key, btn, opts = {}) {
  const product = shopCatalogByKey.get(key);
  if (!product || typeof cartAdd !== 'function') return false;
  const sizes = productSizes(product);
  let size = opts.size != null ? opts.size : null;
  let qty = opts.qty != null ? opts.qty : 1;

  if (sizes.length) {
    if (!size) {
      if (key === productModalKey) size = selectedSizeFromModal();
      if (!size && sizes.length === 1) size = sizes[0];
    }
    if (!size) {
      const hint = document.getElementById('productModalSizeHint');
      if (hint && isProductModalOpen() && key === productModalKey) {
        hint.hidden = false;
        hint.textContent = 'Elige ' + productSizeLabel(product).toLowerCase() + ' para continuar.';
      }
      if (!isProductModalOpen() || key !== productModalKey) openProductModal(key);
      return false;
    }
  }

  if (key === productModalKey) qty = productModalQty || qty;

  cartAdd(
    {
      id: product.id,
      variantId: product.variantId || product.id,
      title: product.title,
      price: product.price,
      currency: product.currency,
      thumbnail: productImages(product)[0] || product.thumbnail,
      size: size || null,
      sizeLabel: productSizeLabel(product),
    },
    qty
  );
  flashAddFeedback(btn);
  updateCartBadge();
  if (isCartOpen()) renderCartDrawer();
  return true;
}

function setShopStatus(text) {
  const el = document.getElementById('shopStatus');
  if (el) el.textContent = text || '';
}

function updateCartBadge() {
  const badge = document.getElementById('cartBadge');
  if (!badge || typeof cartCount !== 'function') return;
  const n = cartCount();
  badge.hidden = n <= 0;
  badge.textContent = String(n);
}

function renderCartDrawer() {
  const linesEl = document.getElementById('cartLines');
  const totalEl = document.getElementById('cartTotal');
  const clearBtn = document.getElementById('cartClearBtn');
  if (!linesEl || typeof cartRead !== 'function') return;

  const cart = cartRead();
  updateCartBadge();

  if (!cart.items.length) {
    linesEl.innerHTML = '<p class="cart-empty">Tu carrito está vacío.</p>';
    if (totalEl) totalEl.textContent = formatShopPrice(0, 'eur');
    if (clearBtn) clearBtn.disabled = true;
    return;
  }

  if (clearBtn) clearBtn.disabled = false;
  linesEl.innerHTML = cart.items
    .map((item) => {
      const media = item.thumbnail
        ? `<img src="${escShop(item.thumbnail)}" alt="" loading="lazy" decoding="async" />`
        : `<span class="cart-line-letter" aria-hidden="true">${escShop((item.title || 'N').charAt(0))}</span>`;
      const lineTotal =
        item.price == null ? null : Number(item.price) * (Number(item.qty) || 0);
      return `
      <div class="cart-line" data-cart-key="${escShop(item.key)}">
        <div class="cart-line-media">${media}</div>
        <div class="cart-line-info">
          <p class="cart-line-title">${escShop(item.title)}</p>
          ${item.size ? `<p class="cart-line-meta">${escShop(item.sizeLabel || 'Talla')}: ${escShop(item.size)}</p>` : ''}
          <p class="cart-line-price">${escShop(formatShopPrice(lineTotal, item.currency))}</p>
          <div class="cart-line-qty">
            <button type="button" class="cart-qty-btn" data-cart-dec="${escShop(item.key)}" aria-label="Quitar uno">−</button>
            <span class="cart-qty-val">${escShop(item.qty)}</span>
            <button type="button" class="cart-qty-btn" data-cart-inc="${escShop(item.key)}" aria-label="Añadir uno">+</button>
            <button type="button" class="cart-line-remove" data-cart-remove="${escShop(item.key)}">Quitar</button>
          </div>
        </div>
      </div>`;
    })
    .join('');

  if (totalEl) {
    totalEl.textContent = formatShopPrice(cartSubtotal(cart), cartCurrency(cart));
  }
}

function isCartOpen() {
  const drawer = document.getElementById('cartDrawer');
  return Boolean(drawer && !drawer.hidden);
}

function openCart() {
  const drawer = document.getElementById('cartDrawer');
  const backdrop = document.getElementById('cartBackdrop');
  const openBtn = document.getElementById('cartOpenBtn');
  if (!drawer) return;
  renderCartDrawer();
  drawer.hidden = false;
  if (backdrop) backdrop.hidden = false;
  requestAnimationFrame(() => {
    drawer.classList.add('is-open');
    if (backdrop) backdrop.classList.add('is-open');
  });
  if (openBtn) openBtn.setAttribute('aria-expanded', 'true');
  document.body.classList.add('cart-open');
  const closeBtn = document.getElementById('cartCloseBtn');
  if (closeBtn) closeBtn.focus();
}

function closeCart() {
  const drawer = document.getElementById('cartDrawer');
  const backdrop = document.getElementById('cartBackdrop');
  const openBtn = document.getElementById('cartOpenBtn');
  if (!drawer) return;
  drawer.classList.remove('is-open');
  if (backdrop) backdrop.classList.remove('is-open');
  if (openBtn) openBtn.setAttribute('aria-expanded', 'false');
  document.body.classList.remove('cart-open');
  window.setTimeout(() => {
    drawer.hidden = true;
    if (backdrop) backdrop.hidden = true;
  }, 280);
  if (openBtn) openBtn.focus();
}

function flashAddFeedback(btn) {
  if (!btn) return;
  const prev = btn.textContent;
  btn.textContent = 'Añadido';
  btn.classList.add('is-added');
  window.setTimeout(() => {
    btn.textContent = prev;
    btn.classList.remove('is-added');
  }, 900);
}

function initCartUi() {
  if (initCartUi._ready) {
    updateCartBadge();
    renderCartDrawer();
    return;
  }
  initCartUi._ready = true;

  updateCartBadge();
  renderCartDrawer();

  document.getElementById('cartOpenBtn')?.addEventListener('click', openCart);
  document.getElementById('cartCloseBtn')?.addEventListener('click', closeCart);
  document.getElementById('cartBackdrop')?.addEventListener('click', closeCart);

  document.getElementById('cartClearBtn')?.addEventListener('click', () => {
    if (!cartRead().items.length) return;
    cartClear();
    renderCartDrawer();
  });

  document.getElementById('cartLines')?.addEventListener('click', (e) => {
    const t = e.target;
    if (!(t instanceof Element)) return;
    const dec = t.getAttribute('data-cart-dec');
    const inc = t.getAttribute('data-cart-inc');
    const rem = t.getAttribute('data-cart-remove');
    if (dec) {
      const item = cartRead().items.find((i) => i.key === dec);
      cartSetQty(dec, (item ? item.qty : 1) - 1);
      renderCartDrawer();
    } else if (inc) {
      const item = cartRead().items.find((i) => i.key === inc);
      cartSetQty(inc, (item ? item.qty : 0) + 1);
      renderCartDrawer();
    } else if (rem) {
      cartRemove(rem);
      renderCartDrawer();
    }
  });

  document.getElementById('shopGrid')?.addEventListener('click', (e) => {
    const t = e.target;
    if (!(t instanceof Element)) return;
    const addKey = t.closest('[data-add-to-cart]')?.getAttribute('data-add-to-cart');
    if (addKey) {
      const product = shopCatalogByKey.get(addKey);
      if (product && productRequiresSize(product) && productSizes(product).length > 1) {
        openProductModal(addKey);
        return;
      }
      addProductToCart(addKey, t.closest('[data-add-to-cart]'));
      return;
    }
    const openKey = t.closest('[data-open-product]')?.getAttribute('data-open-product');
    if (openKey) openProductModal(openKey);
  });

  ensureProductModal();
  document.getElementById('productModalClose')?.addEventListener('click', closeProductModal);
  document.getElementById('productModalBackdrop')?.addEventListener('click', closeProductModal);
  document.getElementById('productModalPrev')?.addEventListener('click', () => stepProductModal(-1));
  document.getElementById('productModalNext')?.addEventListener('click', () => stepProductModal(1));
  document.getElementById('productModalDots')?.addEventListener('click', (e) => {
    const t = e.target;
    if (!(t instanceof Element)) return;
    const i = t.getAttribute('data-product-dot');
    if (i == null) return;
    productModalIndex = Number(i) || 0;
    renderProductModalGallery();
  });
  document.getElementById('productModalSizes')?.addEventListener('click', (e) => {
    const t = e.target;
    if (!(t instanceof Element)) return;
    const btn = t.closest('[data-size]');
    if (!btn) return;
    productModalSize = btn.getAttribute('data-size');
    document.querySelectorAll('#productModalSizes .product-size-btn').forEach((el) => {
      const on = el === btn;
      el.classList.toggle('is-active', on);
      el.setAttribute('aria-selected', on ? 'true' : 'false');
    });
    const hint = document.getElementById('productModalSizeHint');
    if (hint) hint.hidden = true;
  });
  document.getElementById('productModalGuideBtn')?.addEventListener('click', () => {
    const chart = document.getElementById('productModalChart');
    const btn = document.getElementById('productModalGuideBtn');
    if (!chart || chart.childNodes.length === 0) return;
    const open = chart.hidden;
    chart.hidden = !open;
    if (btn) btn.textContent = open ? 'Ocultar guía' : 'Guía de tallas';
  });
  document.getElementById('productModalQtyDec')?.addEventListener('click', () => {
    productModalQty = Math.max(1, (productModalQty || 1) - 1);
    const el = document.getElementById('productModalQty');
    if (el) el.textContent = String(productModalQty);
  });
  document.getElementById('productModalQtyInc')?.addEventListener('click', () => {
    productModalQty = Math.min(99, (productModalQty || 1) + 1);
    const el = document.getElementById('productModalQty');
    if (el) el.textContent = String(productModalQty);
  });
  document.getElementById('productModalAdd')?.addEventListener('click', (e) => {
    if (!productModalKey) return;
    const ok = addProductToCart(productModalKey, e.currentTarget);
    if (ok) closeProductModal();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      if (isProductModalOpen()) {
        closeProductModal();
        return;
      }
      if (isCartOpen()) closeCart();
      return;
    }
    if (!isProductModalOpen()) return;
    if (e.key === 'ArrowLeft') stepProductModal(-1);
    if (e.key === 'ArrowRight') stepProductModal(1);
  });

  window.addEventListener('nova:cart-change', () => {
    updateCartBadge();
    if (isCartOpen()) renderCartDrawer();
  });
}

function initShopMotion() {
  const nav = document.querySelector('.nav');
  const onScroll = () => {
    if (!nav) return;
    nav.classList.toggle('is-scrolled', window.scrollY > 12);
  };
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const nodes = document.querySelectorAll('.reveal');
  if (reduce || !('IntersectionObserver' in window)) {
    nodes.forEach((n) => n.classList.add('is-in'));
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-in');
          io.unobserve(entry.target);
        }
      });
    },
    { rootMargin: '0px 0px -8% 0px', threshold: 0.12 }
  );
  nodes.forEach((n) => io.observe(n));
}

async function loadShopCatalog() {
  const grid = document.getElementById('shopGrid');
  if (!grid) return;

  if (typeof medusaIsConfigured === 'function' && medusaIsConfigured()) {
    setShopStatus('Cargando catálogo…');
    try {
      const products = await medusaListProducts();
      if (!products.length) {
        renderShopProducts(grid, SHOP_PREVIEW_PRODUCTS);
        setShopStatus('Sin productos en Medusa · mostrando vista previa');
      } else {
        renderShopProducts(grid, products);
        setShopStatus('Catálogo Medusa');
      }
    } catch (err) {
      console.warn('[tienda] Medusa:', err);
      renderShopProducts(grid, SHOP_PREVIEW_PRODUCTS);
      setShopStatus('Medusa no disponible · vista previa');
    }
  } else {
    renderShopProducts(grid, SHOP_PREVIEW_PRODUCTS);
    setShopStatus('Vista previa · conecta Medusa en js/medusa.js');
  }

  initCartUi();
  initShopMotion();
}

async function loadShopPage() {
  const root = document.getElementById('page-root');
  if (!root) return;
  try {
    const response = await fetch('sections/tienda_zen.html');
    if (!response.ok) throw new Error('No se pudo cargar la tienda.');
    root.innerHTML = await response.text();
    await loadShopCatalog();
  } catch (err) {
    console.error(err);
    root.innerHTML =
      '<div class="container" style="padding:6rem 2rem"><p>No se pudo cargar la tienda. Recarga la página.</p></div>';
  }
}

async function bootShop() {
  // Panel cliente: el HTML ya incluye #shopGrid
  if (document.getElementById('shopGrid') && !document.getElementById('page-root')) {
    await loadShopCatalog();
    return;
  }
  await loadShopPage();
}

document.addEventListener('DOMContentLoaded', bootShop);
