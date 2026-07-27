// NŌVA · cliente Medusa (Store API)
// Rellena estas dos constantes cuando tengas Medusa Cloud / backend.
// No uses la clave admin en el navegador — solo publishable key.
const MEDUSA_BACKEND_URL = ''; // ej. 'https://tu-proyecto.medusajs.app'
const MEDUSA_PUBLISHABLE_KEY = ''; // ej. 'pk_...'

function medusaIsConfigured() {
  return Boolean(MEDUSA_BACKEND_URL && MEDUSA_PUBLISHABLE_KEY);
}

function medusaStoreUrl(path) {
  const base = String(MEDUSA_BACKEND_URL || '').replace(/\/$/, '');
  const p = path.startsWith('/') ? path : `/${path}`;
  return `${base}${p}`;
}

/**
 * Lista productos publicados del Store API (Medusa v2).
 * @returns {Promise<Array<{id:string,title:string,handle:string,description:string,thumbnail:string|null,price:number|null,currency:string,collection:string|null}>>}
 */
async function medusaListProducts() {
  if (!medusaIsConfigured()) {
    throw new Error('Medusa no configurado');
  }
  const url = medusaStoreUrl('/store/products?limit=50&fields=*variants.calculated_price,*collection');
  const res = await fetch(url, {
    headers: {
      Accept: 'application/json',
      'x-publishable-api-key': MEDUSA_PUBLISHABLE_KEY,
    },
  });
  if (!res.ok) {
    throw new Error(`Medusa Store API ${res.status}`);
  }
  const json = await res.json();
  const products = Array.isArray(json.products) ? json.products : [];
  return products.map((p) => {
    const variant = Array.isArray(p.variants) ? p.variants[0] : null;
    const calc = variant && variant.calculated_price ? variant.calculated_price : null;
    const amount =
      calc && typeof calc.calculated_amount === 'number'
        ? calc.calculated_amount / 100
        : null;
    const currency =
      (calc && calc.currency_code) ||
      (variant && variant.prices && variant.prices[0] && variant.prices[0].currency_code) ||
      'eur';
    const imageUrls = Array.isArray(p.images)
      ? p.images.map((img) => (img && img.url) || null).filter(Boolean)
      : [];
    if (p.thumbnail && !imageUrls.includes(p.thumbnail)) imageUrls.unshift(p.thumbnail);
    return {
      id: p.id,
      variantId: variant && variant.id ? variant.id : null,
      title: p.title || 'Producto',
      handle: p.handle || '',
      description: (p.description || '').replace(/<[^>]+>/g, '').trim(),
      thumbnail: p.thumbnail || imageUrls[0] || null,
      images: imageUrls,
      price: amount,
      currency: String(currency).toLowerCase(),
      collection: (p.collection && p.collection.title) || null,
    };
  });
}
