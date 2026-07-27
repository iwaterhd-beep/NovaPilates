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
