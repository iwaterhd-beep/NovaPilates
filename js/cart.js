// NŌVA · carrito local (listo para sincronizar con Medusa Cart API)
const NOVA_CART_KEY = 'nova_shop_cart_v1';

function cartRead() {
  try {
    const raw = localStorage.getItem(NOVA_CART_KEY);
    if (!raw) return { items: [] };
    const data = JSON.parse(raw);
    return {
      items: Array.isArray(data.items) ? data.items : [],
    };
  } catch {
    return { items: [] };
  }
}

function cartWrite(cart) {
  localStorage.setItem(NOVA_CART_KEY, JSON.stringify({ items: cart.items || [] }));
  window.dispatchEvent(new CustomEvent('nova:cart-change', { detail: cart }));
}

function cartLineKey(product) {
  const base = String(product.variantId || product.id || '');
  const size = product.size ? `::${String(product.size)}` : '';
  return `${base}${size}`;
}

/**
 * @param {{id:string,variantId?:string|null,title:string,price:number|null,currency:string,thumbnail?:string|null,size?:string|null,sizeLabel?:string|null}} product
 * @param {number} [qty]
 */
function cartAdd(product, qty = 1) {
  const key = cartLineKey(product);
  if (!key) return cartRead();
  const cart = cartRead();
  const n = Math.max(1, Math.min(99, Number(qty) || 1));
  const existing = cart.items.find((i) => i.key === key);
  if (existing) {
    existing.qty = Math.min(99, existing.qty + n);
  } else {
    cart.items.push({
      key,
      id: product.id,
      variantId: product.variantId || null,
      title: product.title || 'Producto',
      price: product.price == null ? null : Number(product.price),
      currency: product.currency || 'eur',
      thumbnail: product.thumbnail || null,
      size: product.size || null,
      sizeLabel: product.sizeLabel || 'Talla',
      qty: n,
    });
  }
  cartWrite(cart);
  return cart;
}

function cartSetQty(key, qty) {
  const cart = cartRead();
  const item = cart.items.find((i) => i.key === key);
  if (!item) return cart;
  const n = Math.floor(Number(qty));
  if (!Number.isFinite(n) || n <= 0) {
    cart.items = cart.items.filter((i) => i.key !== key);
  } else {
    item.qty = Math.min(99, n);
  }
  cartWrite(cart);
  return cart;
}

function cartRemove(key) {
  const cart = cartRead();
  cart.items = cart.items.filter((i) => i.key !== key);
  cartWrite(cart);
  return cart;
}

function cartClear() {
  const cart = { items: [] };
  cartWrite(cart);
  return cart;
}

function cartCount(cart = cartRead()) {
  return cart.items.reduce((sum, i) => sum + (Number(i.qty) || 0), 0);
}

function cartSubtotal(cart = cartRead()) {
  return cart.items.reduce((sum, i) => {
    const price = Number(i.price);
    if (!Number.isFinite(price)) return sum;
    return sum + price * (Number(i.qty) || 0);
  }, 0);
}

function cartCurrency(cart = cartRead()) {
  const first = cart.items[0];
  return (first && first.currency) || 'eur';
}

function cartMoney(n) {
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return `${v.toFixed(0)} €`;
}

function cartRenderDrawer() {
  const lines = document.getElementById('cartLines');
  const badge = document.getElementById('cartBadge');
  const totalEl = document.getElementById('cartTotal');
  if (!lines) return;
  const cart = cartRead();
  const n = cartCount(cart);
  if (badge) {
    badge.hidden = n < 1;
    badge.textContent = String(n);
  }
  if (totalEl) totalEl.textContent = cartMoney(cartSubtotal(cart));
  if (!cart.items.length) {
    lines.innerHTML = '<p class="cart-empty">Tu carrito está vacío.</p>';
    return;
  }
  lines.innerHTML = cart.items.map((i) => `
    <div class="cart-line" data-key="${escShopSafe(i.key)}">
      <div class="cart-line-media">${i.thumbnail
        ? `<img src="${escShopSafe(i.thumbnail)}" alt="">`
        : `<span class="cart-line-letter">${escShopSafe((i.title || 'N').slice(0, 1))}</span>`}</div>
      <div>
        <div class="cart-line-title">${escShopSafe(i.title)}</div>
        <div class="cart-line-price">${cartMoney(i.price)}</div>
        <div class="cart-line-qty">
          <button type="button" class="cart-qty-btn" data-act="minus" aria-label="Quitar">−</button>
          <span class="cart-qty-val">${escShopSafe(i.qty)}</span>
          <button type="button" class="cart-qty-btn" data-act="plus" aria-label="Añadir">+</button>
          <button type="button" class="cart-line-remove" data-act="rm">Quitar</button>
        </div>
      </div>
    </div>
  `).join('');
}

function escShopSafe(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function cartSetOpen(open) {
  const drawer = document.getElementById('cartDrawer');
  const backdrop = document.getElementById('cartBackdrop');
  const btn = document.getElementById('cartOpenBtn');
  if (!drawer) return;
  drawer.hidden = !open;
  if (backdrop) backdrop.hidden = !open;
  requestAnimationFrame(() => {
    drawer.classList.toggle('is-open', open);
    if (backdrop) backdrop.classList.toggle('is-open', open);
  });
  if (btn) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
}

function initCartDrawer() {
  const drawer = document.getElementById('cartDrawer');
  if (!drawer || drawer.dataset.ready === '1') return;
  drawer.dataset.ready = '1';
  document.getElementById('cartOpenBtn')?.addEventListener('click', () => cartSetOpen(true));
  document.getElementById('cartCloseBtn')?.addEventListener('click', () => cartSetOpen(false));
  document.getElementById('cartBackdrop')?.addEventListener('click', () => cartSetOpen(false));
  document.getElementById('cartClearBtn')?.addEventListener('click', () => {
    cartClear();
    cartRenderDrawer();
  });
  document.getElementById('cartLines')?.addEventListener('click', (e) => {
    const line = e.target.closest('.cart-line');
    if (!line) return;
    const act = e.target.getAttribute('data-act');
    const item = cartRead().items.find((i) => i.key === line.dataset.key);
    if (!item || !act) return;
    if (act === 'plus') cartSetQty(item.key, item.qty + 1);
    if (act === 'minus') cartSetQty(item.key, item.qty - 1);
    if (act === 'rm') cartRemove(item.key);
    cartRenderDrawer();
  });
  window.addEventListener('nova:cart-change', cartRenderDrawer);
  cartRenderDrawer();
}

document.addEventListener('DOMContentLoaded', initCartDrawer);
initCartDrawer();
