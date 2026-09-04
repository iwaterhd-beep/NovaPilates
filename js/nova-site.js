/** Datos públicos compartidos de NŌVA (fácil de ajustar). */
const NOVA_INSTAGRAM_URL = 'https://www.instagram.com/novapilatestudios/';
const NOVA_INSTAGRAM_DM_URL = 'https://ig.me/m/novapilatestudios';

const NOVA_MEMBERSHIPS = [
  {
    id: 'nova-essential',
    web_tag: '2 DÍAS · HORARIO LIMITADO',
    nombre: 'NŌVA ESSENTIAL',
    precio: 70,
    periodo_label: '/mes',
    lema: 'Una forma sencilla de incorporar NŌVA a tu rutina.',
    highlights: [
      '2 días a la semana',
      'Horario limitado: clases con mayor disponibilidad',
      'Incluye Yoga, Pilates suelo, Barre y Sculpt',
      'No incluye Reformer',
      'Vigencia de 28 días',
      'Sin contrato anual'
    ]
  },
  {
    id: 'nova-balance',
    web_tag: '2 DÍAS · HORARIO COMPLETO',
    nombre: 'NŌVA BALANCE',
    precio: 130,
    periodo_label: '/mes',
    lema: 'Todas las disciplinas, con constancia a tu ritmo.',
    highlights: [
      '2 días a la semana',
      'Horario completo',
      'Reformer, Pilates suelo, Yoga, Barre y Sculpt',
      'Vigencia de 28 días',
      'Sin contrato anual'
    ]
  },
  {
    id: 'nova-move',
    web_tag: '3 DÍAS · HORARIO COMPLETO',
    nombre: 'NŌVA MOVE',
    precio: 160,
    periodo_label: '/mes',
    lema: 'Más movimiento. Más constancia. Más NŌVA.',
    highlights: [
      '3 días a la semana',
      'Horario completo',
      'Reformer, Pilates suelo, Yoga, Barre y Sculpt',
      'Vigencia de 28 días',
      'Sin contrato anual'
    ]
  },
  {
    id: 'priority-membership',
    web_tag: 'DÍAS ILIMITADOS · CONTRATO ANUAL',
    nombre: 'PRIORITY MEMBERSHIP',
    precio: 170,
    periodo_label: '/mes · contrato anual',
    is_priority: true,
    lema: 'La membresía más completa de NŌVA. Única con compromiso anual.',
    highlights: [
      'Contrato anual',
      'Días ilimitados',
      'Todas las disciplinas',
      'Prioridad en lista de espera',
      'Recordatorio de clases 24 h antes',
      'Nutricionista incluido',
      'Todos los talleres incluidos'
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
