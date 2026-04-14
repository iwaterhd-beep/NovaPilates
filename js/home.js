async function loadHomeSections() {
  const root = document.getElementById('page-root');
  if (!root) return;

  try {
    const response = await fetch('sections/home.html');
    if (!response.ok) throw new Error('No se pudo cargar la home.');
    root.innerHTML = await response.text();
  } catch (error) {
    root.innerHTML = `
      <section class="section">
        <div class="container">
          <h1 style="font-family: var(--font-display); margin-bottom: 1rem;">NŌVA PILATES STUDIO</h1>
          <p>No se pudo cargar la portada. Revisa el archivo <code>sections/home.html</code>.</p>
        </div>
      </section>
    `;
    console.error(error);
  }
}

loadHomeSections();
