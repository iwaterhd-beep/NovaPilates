/** Datos públicos compartidos de NŌVA (fácil de ajustar). */
const NOVA_INSTAGRAM_URL = 'https://www.instagram.com/novapilatestudios/';
const NOVA_INSTAGRAM_DM_URL = 'https://ig.me/m/novapilatestudios';

const NOVA_MEMBERSHIPS = [
  {
    id: 'nova-morning',
    web_tag: 'HORARIO DE MAÑANA',
    nombre: 'NŌVA Morning Membership',
    precio: null,
    periodo_label: 'en recepción',
    lema: 'Todas las disciplinas, solo en la franja de mañana.',
    highlights: [
      'Acceso a todas las disciplinas',
      'Horario de mañana: desde la apertura hasta la última clase de esa franja',
      'El horario exacto se confirma en el estudio'
    ]
  },
  {
    id: 'priority-membership',
    web_tag: 'HORARIO COMPLETO',
    nombre: 'NŌVA Priority Membership',
    precio: 170,
    periodo_label: '/mes',
    is_priority: true,
    lema: 'Todas las disciplinas, todo el horario de apertura.',
    highlights: [
      'Acceso a todas las disciplinas durante el horario de apertura',
      'Talleres, promociones y experiencias especiales',
      'Nutrición mensual como parte de la experiencia NŌVA',
      '5 bebidas al mes'
    ]
  }
];

function closeNovaNav() {
  const nav = document.querySelector('.nav');
  const toggle = document.querySelector('.nav-toggle');
  if (!nav) return;
  nav.classList.remove('is-open');
  document.body.classList.remove('nav-lock');
  if (toggle) {
    toggle.setAttribute('aria-expanded', 'false');
    toggle.setAttribute('aria-label', 'Abrir menú');
  }
}

function initNovaNav() {
  const nav = document.querySelector('.nav');
  const toggle = document.querySelector('.nav-toggle');
  if (!nav || !toggle || toggle.dataset.bound === '1') return;
  toggle.dataset.bound = '1';
  toggle.addEventListener('click', () => {
    const open = !nav.classList.contains('is-open');
    nav.classList.toggle('is-open', open);
    document.body.classList.toggle('nav-lock', open);
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    toggle.setAttribute('aria-label', open ? 'Cerrar menú' : 'Abrir menú');
  });
  nav.querySelectorAll('.nav-links a').forEach((link) => {
    link.addEventListener('click', closeNovaNav);
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeNovaNav();
  });
  window.addEventListener('resize', () => {
    if (window.innerWidth > 960) closeNovaNav();
  });
}
