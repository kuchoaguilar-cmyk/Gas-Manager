# GasManager — Referencia de Integración (Webhooks + Puente)

> Qué es: los puntos de integración de GasManager. No es una API REST pública para
> terceros; son **webhooks entrantes** (cobro) y el **contrato del puente** App A↔Motor.
> **URL base (App A):** `https://TU-APP.vercel.app` (reemplaza tras el deploy).
> Formato: JSON. Estado: **beta**.

---

## 1. Autenticación

No hay API keys de cliente. Cada integración se valida distinto:

| Integración | Cómo se valida |
|---|---|
| **Stripe** | Header `Stripe-Signature` verificado con `STRIPE_WEBHOOK_SECRET` (firma HMAC). |
| **GoHighLevel** | Header `x-ghl-secret` que debe coincidir con `GHL_WEBHOOK_SECRET`. |
| **Puente App A→Motor** | Header `x-bridge-secret` compartido (planificado). |

> Los secretos viven en variables de entorno del servidor — nunca en el cliente.

---

## 2. Inicio rápido (cobro real en 4 pasos)

1. Corre `db/001_suscripciones.sql` en Supabase ("Gerente de Gas").
2. En Vercel, setea env: `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_PRO`, `STRIPE_PRICE_AGENTE`.
3. En Stripe → Webhooks, apunta a `https://TU-APP.vercel.app/api/webhooks/billing` y suscribe `customer.subscription.*`. En la suscripción incluye `metadata.org_id` (el id de la organización del instalador).
4. Paga una suscripción de prueba → la tabla `suscripciones` se actualiza → la app desbloquea el plan automáticamente.

---

## 3. Referencia de endpoints

### POST /api/webhooks/billing

Recibe eventos de cobro y actualiza el entitlement (`suscripciones`) de la organización.

**Auth:** `Stripe-Signature` **o** `x-ghl-secret`.

#### Camino A — Stripe

Eventos soportados: `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`.
Requisito: la suscripción debe traer `metadata.org_id`. El plan se deduce del `price.id` (mapeo `STRIPE_PRICE_PRO`/`STRIPE_PRICE_AGENTE`).

```bash
# Stripe firma el request; en local se prueba con la Stripe CLI:
stripe listen --forward-to https://TU-APP.vercel.app/api/webhooks/billing
stripe trigger customer.subscription.updated
```

#### Camino B — GoHighLevel (JSON simple)

```bash
curl -X POST "https://TU-APP.vercel.app/api/webhooks/billing" \
  -H "Content-Type: application/json" \
  -H "x-ghl-secret: TU_GHL_WEBHOOK_SECRET" \
  -d '{
    "org_id": "00000000-0000-0000-0000-000000000000",
    "plan": "agente",
    "extra_proyectos": 50,
    "status": "active"
  }'
```

**Parámetros (camino GHL)**

| Nombre | Tipo | Requerido | Descripción |
|---|---|---|---|
| org_id | uuid | Sí | Organización (instalador) a actualizar |
| plan | enum | No | `basico` \| `pro` \| `agente` (default `basico`) |
| extra_proyectos | int | No | Proyectos extra comprados (suma al tope) |
| status | string | No | `active` \| `canceled` (default `active`) |

**Respuesta 200**
```json
{ "received": true }
```

**Errores**

| Código | Mensaje | Resolución |
|---|---|---|
| 400 | firma inválida | Revisa `STRIPE_WEBHOOK_SECRET` (debe coincidir con el del endpoint en Stripe). |
| 400 | falta org_id | Incluye `org_id` (Stripe: en `metadata.org_id`). |
| 500 | error | Revisa `SUPABASE_SERVICE_ROLE_KEY` y que exista la tabla `suscripciones`. |
| 200 | ok (sin firma/secret) | Aún no configuraste secretos; el webhook hace ack sin escribir. |

---

### POST /api/webhooks/installer-signup  *(puente — planificado)*

Al dar de alta un instalador en App A, provisiona su `workspace` + agente en el Motor.

**Auth:** `x-bridge-secret`.

```bash
curl -X POST "https://TU-MOTOR.vercel.app/api/webhooks/installer-signup" \
  -H "Content-Type: application/json" \
  -H "x-bridge-secret: TU_BRIDGE_SECRET" \
  -d '{
    "org_id": "00000000-0000-0000-0000-000000000000",
    "nombre_empresa": "Gasfíter Pérez SpA",
    "owner_email": "perez@ejemplo.cl"
  }'
```

**Respuesta esperada**
```json
{ "workspace_id": "11111111-1111-1111-1111-111111111111", "agent_id": "..." }
```

Esto crea el mapeo `organización(org_id) ↔ workspace(workspace_id)` que usa el Cockpit
para controlar el agente del instalador.

---

## 4. Mapa de integración (resumen)

```
Stripe/GHL ──(pago)──▶ /api/webhooks/billing ──▶ suscripciones ──▶ App A aplica tope/plan
App A (alta instalador) ──▶ /api/webhooks/installer-signup (Motor) ──▶ workspace + agente
Cockpit (tú) ──▶ edita prompt/business-info del workspace ──▶ agente responde a clientes del instalador
```

---

## 5. Lista de verificación

```
- [ ] db/001_suscripciones.sql aplicado
- [ ] Env de Stripe seteadas en Vercel
- [ ] Webhook de Stripe apuntando a /api/webhooks/billing con metadata.org_id
- [ ] Prueba de pago actualiza suscripciones
- [ ] (Puente) installer-signup crea workspace+agente y guarda el mapeo
- [ ] Secretos solo en env del servidor (nunca en cliente)
```

### Registro de cambios
- **beta (2026-06):** webhook de cobro (Stripe + GHL). Puente installer-signup: planificado.
