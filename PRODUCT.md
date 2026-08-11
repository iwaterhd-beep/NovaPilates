# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Static HTML/CSS/JS with Supabase backend. Public marketing pages load section HTML into `index.html`; authenticated areas use portal dashboards. Deployed on Vercel.

## Users

Primary: adults in Sevilla seeking Pilates Reformer, mat, yoga, or barre who want to discover the studio, understand plans, and book or manage classes online.

Secondary: existing clients managing bonos, calendar, shop, and profile; studio staff operating the admin dashboard.

## Product Purpose

NŌVA Pilates Studio helps people start and sustain a conscious movement practice. The site explains Reformer, suelo, and equilibrio offerings, sells bonos/plans, shows merch, and routes visitors into login to reserve classes and manage their bono.

Success: a first-time visitor understands what NŌVA offers, picks a way to start, and reaches reservation or contact; returning clients manage classes without friction.

## Positioning

A Sevilla studio combining Reformer, mat work, yoga, and barre with online bono activation and reservation limits tied to the contracted plan. Local presence plus a personal client space.

## Constraints

- Preserve Spanish copy voice where it already exists; keep IA anchors (`#empezar`, `#bonos`, `#donde`, `#contacto`) and routes (`/bonos`, `/tienda`, `login.html`).
- Keep Supabase-driven plan and shop grids functional (`#plansGrid`, `#homeShopGrid`).
- Preserve branding assets under `assets/branding/` and hero video `assets/video/nova-hero.mp4`.
- Logo mark (circle + line isotipo) and name NŌVA must remain recognizable.
- Legal pages and cookie consent stay reachable.
- Accessibility: readable contrast, keyboard focus, respect `prefers-reduced-motion` for ambient video/motion.

## Brand

Confirmed name: NŌVA Pilates Studio. Isotipo SVG and logo PNGs in `assets/branding/`. Tagline in use: "Desconecta de lo de fuera. Conecta contigo."

## Evidence

Plans and shop content load from Supabase with local fallbacks in `js/home.js`. Location presented as Sevilla with Google Maps search link. Opening hours in schema: Mon–Fri 08:00–21:00.

## Open Decisions

- Exact street address and contact channels for the contact section (currently soft).
- Visual identity replacement authorized by redesign brief (colors, type, layout free to change; product truth preserved).
