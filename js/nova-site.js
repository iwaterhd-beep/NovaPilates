/** Datos públicos compartidos de NŌVA (fácil de ajustar). */
const NOVA_INSTAGRAM_URL = 'https://www.instagram.com/novapilatestudios/';
const NOVA_INSTAGRAM_DM_URL = 'https://ig.me/m/novapilatestudios';

const NOVA_MEMBERSHIPS = [
  {
    id: 'nova-morning',
    web_tag: 'HORARIO DE MAÑANA',
    nombre: 'Morning',
    precio: 84,
    periodo_label: '/ 28 días',
    lema: '20 clases por ciclo (hasta 5 por semana).',
    highlights: [
      'Horario de mañana: de 8:00 a 12:00 h',
      'Última clase a las 11:00 h'
    ]
  },
  {
    id: 'nova-essential',
    web_tag: '8 CLASES',
    nombre: 'Essential',
    precio: 99,
    periodo_label: '/ 28 días',
    lema: '8 clases por ciclo (2 por semana).',
    highlights: [
      'Sin restricción de horarios',
      'Acceso a las diferentes disciplinas'
    ]
  },
  {
    id: 'nova-priority',
    web_tag: 'EXPERIENCIA COMPLETA',
    nombre: 'Priority',
    precio: 147,
    periodo_label: '/ 28 días',
    is_priority: true,
    lema: '20 clases por ciclo (hasta 5 por semana).',
    highlights: [
      'Sin restricción de horarios',
      'Acceso a todas las disciplinas',
      'Experiencia NŌVA completa: talleres, eventos, regalos, productos, sorteos y beneficios exclusivos'
    ]
  }
];

const NOVA_MEMBERSHIP_CONDITIONS = [
  'Validez: 28 días desde la activación.',
  'Sin permanencia.',
  'Pago flexible: domiciliación bancaria con renovación automática cada 28 días o pago presencial en recepción, sin renovación automática.',
  'La renovación automática puede cancelarse antes del siguiente cobro.'
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
