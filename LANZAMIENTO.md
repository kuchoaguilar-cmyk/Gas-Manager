# GasManager — Guía de Lanzamiento

> Lo que es **código** está terminado y con build verde. Lo de abajo es lo único que
> queda, y **depende de tus cuentas/keys/pagos** (yo no manejo credenciales).

---

## ✅ Listo (código, verificado)

- **App A (gas)** — auth, instalaciones (CRUD + detalle), mapa, certificaciones, agenda, equipo, plan, **importador de e-declarador**, **webhook de cobro** (Stripe + GHL).
- **Motor (Replai)** — Cockpit superadmin + agentes WhatsApp, con **endpoint de puente** `installer-signup`.
- **Puente** — App A llama al Motor cuando un instalador sube a plan **Agente** → crea su workspace + agente.
- **Docs** — `GHL_Playbook…`, `API_Integracion`, `Centro_de_Ayuda`, `TyC_y_Privacidad_BORRADOR`, `Auditoria_Completitud…`, y el CSV de 2.183 instaladores.

---

## ⏳ Pasos de lanzamiento (tuyos)

### A. Base de datos de App A ("Gerente de Gas")
1. Supabase → SQL Editor → pega `gasmanager-app/db/001_suscripciones.sql` → **Correr**.

### B. Desplegar App A (gas) en Vercel
1. Sube `gasmanager-app` a un repo (GitHub) e impórtalo en Vercel.
2. Variables de entorno (Vercel → Settings → Environment Variables):
   - `NEXT_PUBLIC_SUPABASE_URL` = `https://vkfpvravrsluqmrgvdxz.supabase.co`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` = *(tu anon key de "Gerente de Gas")*
   - `SUPABASE_SERVICE_ROLE_KEY` = *(service_role de "Gerente de Gas")*
   - `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_PRO`, `STRIPE_PRICE_AGENTE`
   - `BRIDGE_URL` = URL del Motor (paso C) · `BRIDGE_SECRET` = *(ver paso E)*
   - `NEXT_PUBLIC_GHL_CHECKOUT_URL` = tu funnel de GHL
3. Deploy.

### C. Desplegar el Motor ("Replai")
Sigue `whatsapp-saas-main/INSTALAR.md` (está hecho para esto). Resumen:
1. Keys de Supabase **"Replai"**: URL, anon, service_role, **password de la DB**.
2. Aplica las **19 migraciones**: `supabase db push` (o el script `setup.mjs db-push`).
3. Env en Vercel del Motor: las 3 de Supabase + `OPENROUTER_API_KEY`, `ENCRYPTION_KEY`, `ENCRYPTION_KEY_VERSION=v1`, `NEXT_PUBLIC_APP_URL`, **`BRIDGE_SECRET`** (paso E).
4. Crea tu **super admin**: `ADMIN_EMAIL=... ADMIN_PASSWORD=... node scripts/seed-admin.mjs`.
5. Agenda el **cron** del buffer (`setup.mjs cron-apply`).

### D. Cobro real (Stripe + GHL)
1. En Stripe crea los **precios** Pro y Agente → ponlos en `STRIPE_PRICE_PRO/AGENTE` (App A).
2. Stripe → Webhooks → endpoint `https://TU-APP-A.vercel.app/api/webhooks/billing`,
   eventos `customer.subscription.*`. En la suscripción incluye `metadata.org_id`.
3. GHL: funnel + checkout (ver `GHL_Playbook…`). Opcional: webhook GHL al mismo endpoint con header `x-ghl-secret`.

### E. Conectar el puente (un secreto compartido)
1. Genera el secreto: `node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"`
2. Pon **el mismo valor** en `BRIDGE_SECRET` de **App A** y del **Motor**.
3. `BRIDGE_URL` (en App A) = la URL pública del Motor.

---

## Checklist final
```
- [ ] db/001_suscripciones.sql corrido en "Gerente de Gas"
- [ ] App A desplegada en Vercel con su env (anon + service_role + Stripe + BRIDGE)
- [ ] Motor desplegado en "Replai" (19 migraciones + env + super admin + cron)
- [ ] BRIDGE_SECRET idéntico en App A y Motor; BRIDGE_URL apunta al Motor
- [ ] Precios de Stripe creados y webhook conectado (metadata.org_id)
- [ ] Funnel de GHL publicado
- [ ] Prueba E2E: alta instalador → paga plan Agente → se crea su workspace+agente → editas su prompt en el Cockpit → su agente responde por WhatsApp
- [ ] TyC + Privacidad revisados por abogado y publicados
- [ ] Cumplimiento de outreach (A2P / plantillas WhatsApp / opt-out)
```

> Cuando tengas las keys a mano, dime y te acompaño paso a paso (puedo manejar el navegador
> en los dashboards; los secretos los pegas tú).
