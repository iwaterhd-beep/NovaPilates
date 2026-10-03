/** Listado de clases estilo app (franja de días + tarjetas). */
(function (global) {
  const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  const MESES_FULL = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  const DIAS_L = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
  const DIAS_FULL = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  function esc(s) {
    if (typeof escHtml === 'function') return escHtml(s);
    return String(s ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function startOfWeek(d) {
    const date = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    const day = date.getDay();
    const diff = day === 0 ? -6 : 1 - day;
    date.setDate(date.getDate() + diff);
    return date;
  }

  function parseKey(key) {
    const [y, m, d] = String(key || '').split('-').map(Number);
    if (!y || !m || !d) return new Date();
    return new Date(y, m - 1, d);
  }

  function fmtDateKey(date) {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }

  function weekKeys(weekStart) {
    return [...Array(7)].map((_, i) => {
      const day = new Date(weekStart);
      day.setDate(day.getDate() + i);
      return fmtDateKey(day);
    });
  }

  function padTime(d) {
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  }

  function endTime(iso, dur) {
    const d = new Date(iso);
    d.setMinutes(d.getMinutes() + (Number(dur) || 60));
    return padTime(d);
  }

  function prettyDay(d) {
    return `${DIAS_FULL[d.getDay()]} ${d.getDate()} de ${MESES_FULL[d.getMonth()].toLowerCase()}`;
  }

  function shortRange(weekStart) {
    const end = new Date(weekStart);
    end.setDate(end.getDate() + 6);
    const a = `${weekStart.getDate()} ${MESES[weekStart.getMonth()]}`;
    const b = `${end.getDate()} ${MESES[end.getMonth()]}`;
    return `${a} — ${b}`;
  }

  function claseFoto(c) {
    const n = `${c.titulo || ''} ${c.disciplina?.nombre || ''}`.toLowerCase();
    if (n.includes('reformer')) return '/assets/branding/icon-reformer.png?v=3';
    if (n.includes('suelo') || n.includes('esterilla')) return '/assets/branding/icon-esterilla.png?v=3';
    if (n.includes('yoga') || n.includes('barre') || n.includes('sculpt')) return '/assets/branding/icon-equilibrio.png?v=3';
    return '/assets/branding/logo-circulo-nova.png';
  }

  function badgeLabel(c) {
    return c.disciplina?.nombre || c.sala?.nombre || 'NŌVA';
  }

  function createBooker(root, options) {
    const opts = options || {};
    const state = {
      weekStart: startOfWeek(new Date()),
      selectedDateKey: fmtDateKey(new Date()),
      clases: [],
      reservasMap: new Map(),
      ocupacion: {},
      perfilId: opts.perfilId,
      isPriority: !!opts.isPriority,
      isEssential: !!opts.isEssential,
      margenReservaDias: 0,
      margenCancelacionDias: 0,
      filtro: '',
      proxima: null
    };

    root.classList.add('book-app');
    root.innerHTML = `
      <div class="book-month">
        <button type="button" class="book-month-nav js-book-prev" aria-label="Semana anterior">‹</button>
        <div class="book-month-mid">
          <h2 class="book-month-label"></h2>
          <p class="book-month-range"></p>
        </div>
        <div class="book-month-actions">
          <button type="button" class="book-hoy js-book-hoy">Hoy</button>
          <button type="button" class="book-month-nav js-book-next" aria-label="Semana siguiente">›</button>
        </div>
      </div>
      <div class="book-days" role="tablist" aria-label="Días de la semana"></div>
      <div class="book-dayhead">
        <h3 class="book-dayhead-title"></h3>
        <span class="book-dayhead-meta"></span>
      </div>
      <div class="book-chips" hidden></div>
      <div class="book-list"></div>
    `;

    const els = {
      month: root.querySelector('.book-month-label'),
      range: root.querySelector('.book-month-range'),
      hoy: root.querySelector('.js-book-hoy'),
      days: root.querySelector('.book-days'),
      dayTitle: root.querySelector('.book-dayhead-title'),
      dayMeta: root.querySelector('.book-dayhead-meta'),
      chips: root.querySelector('.book-chips'),
      list: root.querySelector('.book-list')
    };

    function notify(msg, type) {
      if (typeof showToast === 'function') showToast(msg, type);
      else if (typeof toast === 'function') toast(msg, type);
    }

    function daysWithClasses() {
      const set = new Set();
      state.clases.forEach((c) => set.add(fmtDateKey(new Date(c.fecha_hora))));
      return set;
    }

    async function fetchData() {
      if (typeof showPageSpinner === 'function') showPageSpinner(true);
      try {
        const weekEnd = new Date(state.weekStart);
        weekEnd.setDate(weekEnd.getDate() + 7);
        const nowIso = new Date().toISOString();
        const [{ data: clases, error: e1 }, { data: reservas, error: e2 }, { data: ajustes, error: e3 }, { data: prox }] = await Promise.all([
          novaSupabase
            .from('clases')
            .select('id,titulo,fecha_hora,duracion_min,aforo_max,disciplina:disciplina_id(nombre,color_hex),sala:sala_id(nombre)')
            .eq('cancelada', false)
            .gte('fecha_hora', state.weekStart.toISOString())
            .lt('fecha_hora', weekEnd.toISOString())
            .order('fecha_hora', { ascending: true }),
          novaSupabase
            .from('reservas')
            .select('id,clase_id,estado,lista_espera,posicion_espera')
            .eq('perfil_id', state.perfilId)
            .in('estado', ['confirmada', 'asistida']),
          novaSupabase
            .from('ajustes_centro')
            .select('margen_reserva_dias,margen_cancelacion_dias')
            .eq('id', 1)
            .maybeSingle(),
          novaSupabase
            .from('clases')
            .select('id,titulo,fecha_hora,disciplina:disciplina_id(nombre)')
            .eq('cancelada', false)
            .gte('fecha_hora', nowIso)
            .order('fecha_hora', { ascending: true })
            .limit(1)
        ]);
        if (e1) throw e1;
        if (e2) throw e2;
        if (e3) console.warn('Ajustes centro:', e3.message);
        state.clases = clases || [];
        state.reservasMap = new Map((reservas || []).map((r) => [r.clase_id, r]));
        state.margenReservaDias = ajustes?.margen_reserva_dias ?? 0;
        state.margenCancelacionDias = ajustes?.margen_cancelacion_dias ?? 0;
        state.proxima = (prox && prox[0]) || null;

        const ids = state.clases.map((c) => c.id);
        state.ocupacion = {};
        if (ids.length) {
          const { data: occ } = await novaSupabase.rpc('ocupacion_clases', { p_clase_ids: ids });
          (occ || []).forEach((row) => {
            state.ocupacion[row.clase_id] = Number(row.ocupadas) || 0;
          });
        }
      } finally {
        if (typeof showPageSpinner === 'function') showPageSpinner(false);
      }
    }

    function shiftWeek(delta) {
      const keep = parseKey(state.selectedDateKey);
      const dow = keep.getDay();
      state.weekStart.setDate(state.weekStart.getDate() + delta * 7);
      const next = new Date(state.weekStart);
      const mondayOffset = dow === 0 ? 6 : dow - 1;
      next.setDate(state.weekStart.getDate() + mondayOffset);
      state.selectedDateKey = fmtDateKey(next);
    }

    async function goToDate(date) {
      state.weekStart = startOfWeek(date);
      state.selectedDateKey = fmtDateKey(date);
      await fetchData();
      render();
    }

    function renderMonth() {
      const selected = parseKey(state.selectedDateKey);
      els.month.textContent = `${MESES_FULL[selected.getMonth()]} ${selected.getFullYear()}`;
      els.range.textContent = shortRange(state.weekStart);
      const todayKey = fmtDateKey(new Date());
      els.hoy.hidden = state.selectedDateKey === todayKey && weekKeys(state.weekStart).includes(todayKey);
    }

    function renderDays() {
      const todayKey = fmtDateKey(new Date());
      const keys = weekKeys(state.weekStart);
      if (!keys.includes(state.selectedDateKey)) {
        state.selectedDateKey = keys.includes(todayKey) ? todayKey : keys[0];
      }
      const withClass = daysWithClasses();
      els.days.innerHTML = keys.map((key, i) => {
        const day = new Date(state.weekStart);
        day.setDate(day.getDate() + i);
        const selected = key === state.selectedDateKey ? ' is-selected' : '';
        const today = key === todayKey ? ' is-today' : '';
        const has = withClass.has(key) ? ' has-class' : '';
        const past = key < todayKey ? ' is-past' : '';
        return `<button type="button" class="book-day${selected}${today}${has}${past}" data-key="${esc(key)}" role="tab" aria-selected="${key === state.selectedDateKey}">
          <span class="book-day-l">${DIAS_L[day.getDay()]}</span>
          <span class="book-day-n">${day.getDate()}</span>
          <span class="book-day-dot" aria-hidden="true"></span>
        </button>`;
      }).join('');
    }

    function renderDayHead(count) {
      const d = parseKey(state.selectedDateKey);
      els.dayTitle.textContent = prettyDay(d);
      if (!count) els.dayMeta.textContent = 'Sin sesiones';
      else els.dayMeta.textContent = count === 1 ? '1 sesión' : `${count} sesiones`;
    }

    function renderChips() {
      const names = [...new Set(state.clases.map((c) => c.disciplina?.nombre).filter(Boolean))];
      if (names.length < 2) {
        els.chips.hidden = true;
        return;
      }
      els.chips.hidden = false;
      const all = `<button type="button" class="book-chip${state.filtro ? '' : ' is-on'}" data-filtro="">Todas</button>`;
      els.chips.innerHTML = all + names.map((n) =>
        `<button type="button" class="book-chip${state.filtro === n ? ' is-on' : ''}" data-filtro="${esc(n)}">${esc(n)}</button>`
      ).join('');
    }

    function plazasHtml(c) {
      const aforo = Number(c.aforo_max) || 0;
      if (!aforo) return '';
      const ocup = state.ocupacion[c.id];
      if (ocup == null) return `<span class="book-card-spots">Hasta ${aforo} plazas</span>`;
      const libres = Math.max(0, aforo - ocup);
      if (!libres) return `<span class="book-card-spots is-full">Completa · lista de espera</span>`;
      return `<span class="book-card-spots">${libres} de ${aforo} plazas libres</span>`;
    }

    function emptyHtml() {
      const withClass = daysWithClasses();
      const keys = weekKeys(state.weekStart);
      const other = keys.find((k) => withClass.has(k) && k !== state.selectedDateKey);
      if (other) {
        const d = parseKey(other);
        const n = state.clases.filter((c) => fmtDateKey(new Date(c.fecha_hora)) === other).length;
        return `<div class="book-empty-card">
          <p class="book-empty-kicker">Este día</p>
          <h3>No hay clases el ${DIAS_FULL[parseKey(state.selectedDateKey).getDay()].toLowerCase()}</h3>
          <p>Hay horario otro día de esta semana.</p>
          <button type="button" class="btn btn-outline btn-sm js-book-jump" data-key="${esc(other)}">Ver ${DIAS_FULL[d.getDay()].toLowerCase()} · ${n} ${n === 1 ? 'sesión' : 'sesiones'}</button>
        </div>`;
      }
      if (state.proxima) {
        const d = new Date(state.proxima.fecha_hora);
        const nombre = state.proxima.titulo || state.proxima.disciplina?.nombre || 'Clase';
        return `<div class="book-empty-card">
          <p class="book-empty-kicker">Horario</p>
          <h3>Esta semana aún no hay sesiones</h3>
          <p>La próxima clase publicada es <strong>${esc(nombre)}</strong> el ${esc(prettyDay(d).toLowerCase())} a las ${esc(padTime(d))}.</p>
          <button type="button" class="btn btn-primary btn-sm js-book-jump" data-key="${esc(fmtDateKey(d))}">Ir a esa fecha</button>
        </div>`;
      }
      return `<div class="book-empty-card">
        <p class="book-empty-kicker">Horario</p>
        <h3>Aún no hay clases publicadas</h3>
        <p>Cuando el estudio cuelgue el horario, las sesiones aparecerán aquí para reservar plaza.</p>
      </div>`;
    }

    function renderList() {
      const list = state.clases.filter((c) => {
        if (fmtDateKey(new Date(c.fecha_hora)) !== state.selectedDateKey) return false;
        if (state.filtro && c.disciplina?.nombre !== state.filtro) return false;
        return true;
      });
      renderDayHead(list.length);
      if (!list.length) {
        els.list.innerHTML = emptyHtml();
        return;
      }
      els.list.innerHTML = list.map((c) => {
        const start = new Date(c.fecha_hora);
        const finMs = start.getTime() + (Number(c.duracion_min) || 60) * 60000;
        const isPast = finMs < Date.now();
        const reserva = state.reservasMap.get(c.id);
        const isReserved = reserva?.estado === 'confirmada' || reserva?.estado === 'asistida';
        const isWaitlist = isReserved && reserva?.lista_espera;
        const when = `${padTime(start)} – ${endTime(c.fecha_hora, c.duracion_min)} · ${Number(c.duracion_min) || 60} min`;
        let btn = '';
        if (isPast && !isReserved) {
          btn = '<span class="book-card-ended">Finalizada</span>';
        } else {
          const btnLabel = isReserved ? (isWaitlist ? 'Salir espera' : 'Cancelar') : 'Reservar';
          const btnClass = isReserved ? 'btn btn-outline btn-sm' : 'btn btn-primary btn-sm';
          btn = `<button type="button" class="${btnClass} book-card-btn" data-clase-id="${esc(c.id)}">${btnLabel}</button>`;
        }
        const wait = isWaitlist
          ? `<p class="book-card-wait">Lista de espera · posición ${esc(reserva.posicion_espera ?? '-')}</p>`
          : '';
        return `<article class="book-card${isReserved ? ' is-reserved' : ''}${isPast ? ' is-past' : ''}">
          <img class="book-card-photo" src="${esc(claseFoto(c))}" alt="" onerror="this.src='/assets/branding/logo-circulo-nova.png'" />
          <div class="book-card-body">
            <p class="book-card-when">${esc(when)}</p>
            <h3 class="book-card-title">${esc(c.titulo || c.disciplina?.nombre || 'Clase')}</h3>
            <p class="book-card-place">${esc(c.sala?.nombre || 'Sala')}</p>
            ${plazasHtml(c)}
            ${wait}
            ${btn}
          </div>
          <span class="book-card-badge">${esc(badgeLabel(c))}</span>
        </article>`;
      }).join('');
    }

    function render() {
      renderMonth();
      renderDays();
      renderChips();
      renderList();
    }

    async function onReserveClick(claseId) {
      const c = state.clases.find((x) => x.id === claseId);
      if (!c) return;
      const reserva = state.reservasMap.get(c.id);
      const isReserved = reserva?.estado === 'confirmada' || reserva?.estado === 'asistida';
      const isWaitlist = isReserved && reserva?.lista_espera;
      const canReserve = state.margenReservaDias === 0 || new Date(c.fecha_hora).getTime() >= Date.now() + state.margenReservaDias * 86400000;
      const canCancel = state.margenCancelacionDias === 0 || new Date(c.fecha_hora).getTime() >= Date.now() + state.margenCancelacionDias * 86400000;
      const isReformer = (c.sala?.nombre || '').toLowerCase().includes('reformer') || (c.titulo || '').toLowerCase().includes('reformer');

      try {
        if (!isReserved && state.isEssential && isReformer) {
          notify('Tu membresía no incluye Reformer. Amplía en recepción.', 'warning');
          return;
        }
        if (!isReserved && !canReserve) {
          notify('Debes reservar con más antelación.', 'info');
          return;
        }
        if (isReserved && !isWaitlist && !canCancel) {
          notify('Ya no se puede cancelar esta reserva.', 'info');
          return;
        }
        if (typeof showPageSpinner === 'function') showPageSpinner(true);
        if (isReserved) {
          const ok = typeof showConfirm === 'function'
            ? await showConfirm(isWaitlist ? '¿Salir de la lista de espera?' : '¿Cancelar esta reserva?')
            : true;
          if (!ok) return;
          await cancelarReservaSegura(reserva.id);
          notify(isWaitlist ? 'Has salido de la lista de espera.' : 'Reserva cancelada.', 'success');
        } else {
          const result = await crearReservaSegura(c.id);
          if (result?.en_espera) {
            notify(`Clase completa. Estás en lista de espera (#${result.posicion_espera}).`, 'info');
          } else {
            notify('Reserva confirmada.', 'success');
          }
        }
        await fetchData();
        render();
      } catch (e) {
        notify(typeof friendlyError === 'function' ? friendlyError(e) : (e.message || 'No se pudo completar'), 'error');
      } finally {
        if (typeof showPageSpinner === 'function') showPageSpinner(false);
      }
    }

    root.addEventListener('click', (e) => {
      const jump = e.target.closest('.js-book-jump');
      if (jump) {
        goToDate(parseKey(jump.dataset.key));
        return;
      }
      const dayBtn = e.target.closest('.book-day');
      if (dayBtn) {
        state.selectedDateKey = dayBtn.dataset.key;
        render();
        return;
      }
      const chip = e.target.closest('.book-chip');
      if (chip) {
        state.filtro = chip.dataset.filtro || '';
        render();
        return;
      }
      const btn = e.target.closest('.book-card-btn');
      if (btn) onReserveClick(btn.dataset.claseId);
    });

    root.querySelector('.js-book-prev').addEventListener('click', async () => {
      shiftWeek(-1);
      await fetchData();
      render();
    });
    root.querySelector('.js-book-next').addEventListener('click', async () => {
      shiftWeek(1);
      await fetchData();
      render();
    });
    els.hoy.addEventListener('click', () => goToDate(new Date()));

    return {
      async start() {
        await fetchData();
        const todayKey = fmtDateKey(new Date());
        const keys = weekKeys(state.weekStart);
        state.selectedDateKey = keys.includes(todayKey) ? todayKey : keys[0];
        if (!state.clases.length && state.proxima) {
          const d = new Date(state.proxima.fecha_hora);
          state.weekStart = startOfWeek(d);
          state.selectedDateKey = fmtDateKey(d);
          await fetchData();
        }
        render();
      }
    };
  }

  global.initNovaClassBooker = async function (root, options) {
    if (!root) return null;
    const booker = createBooker(root, options || {});
    await booker.start();
    return booker;
  };
})(window);
