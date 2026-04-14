# NŌVA PILATES STUDIO - Deploy en Vercel

## 1) Añadir logos al proyecto
Coloca tus dos logos en:

- `assets/branding/logo-nova-main.png`
- `assets/branding/logo-nova-mark.png`

## 2) Crear repo en GitHub (web)
1. Ve a [https://github.com/new](https://github.com/new)
2. Nombre sugerido: `nova-pilates-studio`
3. Crear sin README (porque ya existe repo local)

## 3) Conectar este proyecto con GitHub
Ejecuta estos comandos en la carpeta del proyecto:

```bash
git remote add origin https://github.com/TU_USUARIO/nova-pilates-studio.git
git branch -M main
git push -u origin main
```

## 4) Desplegar en Vercel
1. Ve a [https://vercel.com/new](https://vercel.com/new)
2. Importa el repo `nova-pilates-studio`
3. Framework preset: `Other`
4. Deploy

## 5) Variables de entorno (si luego usas frontend con env)
En Vercel > Project Settings > Environment Variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
