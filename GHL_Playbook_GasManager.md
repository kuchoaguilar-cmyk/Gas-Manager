# GasManager — Playbook GoHighLevel (Captación de Instaladores de Gas)

> **Ángulo maestro:** GasManager no es un gasto, es una **inversión que se paga sola**.
> Cada mensaje, página y automatización debe traducir el software a **horas y dinero
> recuperados** (menos papeleo, cero certificaciones vencidas, menos errores que cuestan multas).

> **Antes de enviar nada — Cumplimiento (no es opcional):**
> - **Twilio/LC Phone:** registra el **A2P 10DLC / Brand + Campaign** antes de mandar SMS. Sin esto, los SMS se bloquean.
> - **WhatsApp (LC – Meta):** el outreach en frío requiere **plantillas (templates) aprobadas** y, idealmente, opt-in previo. WhatsApp normal solo abre ventana de 24h tras respuesta del contacto.
> - **Listas importadas:** marca el origen y la base legal de contacto. Incluye **opt-out** ("responde BAJA") en cada SMS/WhatsApp.
> - Recomendación: trata la lista fría como **Email-first + un toque WhatsApp con plantilla de valor**, no como blast masivo.

---

## MÓDULO 1 — Estructura de Contactos: Custom Fields & Tags

Crea una carpeta de campos: **Settings → Custom Fields → carpeta "Instalador GasManager"**.

### Custom Fields (para hiper-personalizar)

| Campo | Tipo | Custom Value | Uso |
|---|---|---|---|
| Nombre Empresa | Text | `{{contact.nombre_empresa}}` | Personalización + Parte B del contrato |
| Tipo Instalador | Dropdown: `Autónomo`, `Dueño de Empresa` | `{{contact.tipo_instalador}}` | **Condicional If/Else del workflow** |
| Categoría / Clase Certificación | Dropdown (ej. `Clase 1`, `Clase 2`, `Clase 3`) | `{{contact.clase_cert}}` | Segmentación y prueba social específica |
| N° Registro / Licencia (SEC u órgano local) | Text | `{{contact.licencia}}` | Pre-llenado del contrato |
| Ciudad / Comuna | Text | `{{contact.ciudad}}` | Personalización local + prueba social regional |
| Región | Dropdown | `{{contact.region}}` | Segmentación geográfica |
| Instalaciones por mes | Number | `{{contact.instalaciones_mes}}` | **Cálculo de ROI personalizado** |
| Horas de papeleo / semana | Number | `{{contact.horas_papeleo}}` | **Hook de dolor cuantificado** |
| Software actual | Dropdown: `Papel/Excel`, `Otro software`, `Nada` | `{{contact.software_actual}}` | Ángulo del mensaje |
| Fecha vencimiento certificación | Date | `{{contact.fecha_venc_cert}}` | **Urgencia real** (disparador de recordatorio) |
| Origen Lista | Text | `{{contact.origen_lista}}` | Trazabilidad / cumplimiento |

> **Tip de import:** mapea las columnas del Excel a estos campos durante el **CSV import** de GHL.
> Si el Excel no trae "horas de papeleo" o "instalaciones/mes", deja un **valor por defecto conservador**
> (ej. 6 h/semana) para que el ROI del copy nunca quede vacío — el fallback se configura en el Custom Value.

### Tags (estados y segmentos)

**Segmento (estáticos):** `prospecto-instalador`, `perfil-autonomo`, `perfil-empresa`, `cert-por-vencer`

**Estado del embudo (dinámicos, los mueve el workflow):**
`secuencia-activa` → `interesado` → `demo-agendada` → `checkout-iniciado` → `pago-ok` → `contrato-enviado` → `contrato-firmado` → `cliente-activo`

**Negativos / control:** `no-responde`, `no-pago`, `baja-optout`, `churn`

> Regla de oro: **un tag = una intención de automatización.** No crees tags decorativos.

---

## MÓDULO 2 — Funnel de Ventas (GHL Funnels + Payments)

**Sites → Funnels → New Funnel → "GasManager – Inversión Instaladores".**

### Pre-requisito: Productos y Stripe
1. **Payments → Integrations → conecta Stripe** (modo live).
2. **Payments → Products → New Product:** "GasManager Pro".
   - Crea **2 precios:** Mensual (recurrente) y Anual (recurrente, con descuento = "2 meses gratis").
   - Marca el plan anual como recomendado (mejor LTV y menos churn).

### Página 1 — Landing ROI (One-Step Checkout)

Estructura de secciones (top → bottom):

1. **Hero**
   - **Headline (elige/testea):**
     - "Cómo los instaladores de gas en {{contact.region}} recuperan **10 horas de papeleo a la semana** (y nunca más una certificación vencida)."
     - "Tu próxima multa por certificación vencida cuesta más que **un año entero** de GasManager."
   - **Subhead:** "GasManager ordena tus instalaciones, certificaciones, memorias de cálculo y agenda en un solo lugar. Menos oficina, más terreno."
   - CTA ancla: "Quiero recuperar mis horas →" (scroll al checkout).
2. **Video / Loom** de 90s (demo del mapa + certificaciones por vencer).
3. **Problema (PAS):** "Hoy persigues vencimientos en una libreta o un Excel que nadie actualiza…"
4. **Agitación:** "…y basta **una memoria de cálculo traspapelada o un certificado vencido** para una multa, una obra detenida o un cliente perdido."
5. **Solución → ROI:** bloque de 3-4 features traducidas a dinero/tiempo:
   - *Certificaciones al día* → "Cero vencimientos sorpresa = cero multas."
   - *Memoria de cálculo y documentos centralizados* → "Encuentra cualquier instalación en 5 segundos."
   - *Agenda + Mapa* → "Optimiza visitas, menos viajes en vano."
   - *Reportes* → "Sabes qué vence este mes sin abrir un Excel."
6. **Caja de ROI explícita:** "Si facturas {{contact.instalaciones_mes}} instalaciones/mes y pierdes {{contact.horas_papeleo}} h/semana en papeleo, GasManager se paga con **recuperar 1 sola hora**."
7. **Testimonios** (3): nombre + comuna + foto + frase con número ("Antes perdía 2 tardes/semana; ahora cero"). *(Usa reales en cuanto los tengas; al inicio, testimonios de beta/piloto.)*
8. **Oferta como inversión:** precio mensual vs. costo de **una** multa/error. Garantía de 14 días.
9. **One-Step Order Form** (elemento de GHL):
   - Add Element → **Order Form (1-Step)**.
   - Campos en una pantalla: contacto + selección de plan + pago (Stripe).
   - Conecta el **Product** "GasManager Pro".
10. **FAQ** (objeciones: "¿y mis datos actuales?", "¿es difícil migrar?", "¿funciona en mi región?").
11. **Footer** legal + opt-out.

### Página 2 — Gracias + Redirección a Firma
- Mensaje: "✅ Pago confirmado, {{contact.first_name}}. Último paso: firma tu contrato (2 min) para activar tu cuenta."
- **Redirección inmediata:** botón grande + auto-redirect (Settings de la página → Redirect / o botón al enlace del contrato).
- El disparo real del contrato lo hace el **Workflow** (Módulo 5), no la página, para garantizar que el documento se genere con los datos ya guardados.

> **Order Submitted vs Order Form Submission:** usa **Order Form Submission** como trigger del workflow de post-venta (corre al enviar el formulario de pago). "Order Submitted" también dispara en upsells — útil si agregas bumps.

---

## MÓDULO 3 — Workflow Automatizado (mapa paso a paso)

Crea **2 workflows** separados (más limpio y mantenible):

### Workflow A — "Nutrición Prospecto Instalador"

**Trigger:** `Contact Tag` → **Tag Added = `prospecto-instalador`**
*(o `Contact Created` con filtro de tag, si etiquetas en el import).*

1. **Action – Add Tag:** `secuencia-activa`
2. **If/Else – Tipo Instalador** (custom field `Tipo Instalador`):

   **RAMA A · `Autónomo`** (mensaje: "deja de perder tardes de oficina, vuelve al terreno")
   - Day 0 — **Email** plantilla PAS (ver Módulo 4) + **Add Tag** `perfil-autonomo`
   - Wait 1 day → **If/Else: ¿respondió / abrió?**
     - Sí → Add Tag `interesado` → **Goto** sección "Cierre"
     - No → **SMS** corto (recordatorio + enlace landing)
   - Wait 2 days → **WhatsApp template** (valor: mini caso de éxito autónomo)
   - Wait 2 days → **Email** "caso de éxito" + CTA a la landing
   - Wait 2 days → **WhatsApp/SMS urgencia** (si `Fecha vencimiento cert` está cerca, refuerza)

   **RAMA B · `Dueño de Empresa`** (mensaje: "estandariza al equipo, controla vencimientos de toda la cuadrilla")
   - Mismos tiempos, copy enfocado en **equipo, control y escalar** (no en "tú solo").
   - Add Tag `perfil-empresa`.

3. **Sección "Cierre" (común):**
   - **If/Else:** ¿tag `demo-agendada`?
     - Sí → silenciar secuencia (Remove `secuencia-activa`), notificar a ventas.
     - No → enviar enlace de **calendario GHL** ("agenda 15 min").
4. **Goal / Event – salida:** si entra tag `checkout-iniciado` o `pago-ok` → **Remove** `secuencia-activa`, **End** este workflow (deja de nutrir a quien ya compró).

> **Opt-out global:** en Settings del workflow activa "Stop on response" donde aplique y respeta `baja-optout` como filtro de exclusión en TODOS los envíos.

### Workflow B — "Post-Pago → Contrato → Activación"  (ver Módulo 5)
**Trigger:** `Order Form Submission` (o `Payment Received` con Stripe).

---

## MÓDULO 4 — Plantillas de Mensaje (framework PAS)

> Todas usan Custom Values reales para sonar 1:1. Mantén el opt-out en SMS/WhatsApp.

### A) WhatsApp / SMS — corto y directo
*(versión plantilla aprobada para frío; en seguimiento puedes ser más informal)*

```
Hola {{contact.first_name}} 👋 Soy [Tu Nombre] de GasManager.

¿Cuántas horas a la semana pierdes en papeleo de certificaciones e instalaciones?
La mayoría de instaladores en {{contact.ciudad}} pierde varias… hasta que una
certificación vencida les cuesta una multa.

GasManager te avisa antes de cada vencimiento y deja tus memorias de cálculo y
documentos en un solo lugar. Se paga solo con recuperar 1 hora.

¿Te muestro cómo en 90 segundos? 👉 [enlace landing]
(Responde BAJA para no recibir más mensajes)
```

### B) Email — PAS desarrollado

**Asunto:** `{{contact.first_name}}, una certificación vencida cuesta más que un año de GasManager`
**Preheader:** `Recupera tus horas de oficina y vuelve al terreno.`

```
Hola {{contact.first_name}},

(P) Si eres como la mayoría de instaladores de {{contact.nombre_empresa}}, llevas
el control de instalaciones y certificaciones entre papel, WhatsApp y un Excel que
casi nunca está al día.

(A) El problema no es el desorden: es lo que cuesta. Una memoria de cálculo
traspapelada, un certificado vencido sin avisar, una visita agendada dos veces…
cada error son horas perdidas y, en el peor caso, una multa o una obra detenida.
Multiplícalo por tus ~{{contact.instalaciones_mes}} instalaciones al mes.

(S) GasManager es el sistema que ordena todo en un solo lugar:
 • Te avisa ANTES de cada vencimiento de certificación.
 • Centraliza memorias de cálculo y documentos (los encuentras en segundos).
 • Agenda + mapa de tus visitas para no viajar en vano.
 • Reportes que te dicen qué vence este mes sin abrir un Excel.

No es un gasto: con recuperar 1 sola hora de papeleo, ya se pagó.

👉 Mira cómo funciona (90 s) y actívalo hoy: [enlace landing]

— [Tu Nombre], GasManager
Instalaciones seguras, certificaciones al día.

Para no recibir más correos, haz clic aquí: {{unsubscribe_link}}
```

> **Variante por perfil:** en RAMA B (Dueño de Empresa) cambia "tú" por "tu equipo/cuadrilla"
> y agrega: *"controla los vencimientos de todos tus técnicos desde un panel."*

---

## MÓDULO 5 — Firma Contractual Bilateral (Parte A GasManager / Parte B Instalador)

**Confirmado en GHL nativo (Documents & Contracts, 2026):** soporta **e-firma legalmente vinculante**
con audit trail (certificado con datos del firmante, IP y timestamp), **múltiples destinatarios**
(puedes asignar campos de firma a más de un firmante en un mismo documento) e **incluir a tu propio
usuario de negocio como firmante** (= Parte A). Se puede **enviar el contrato desde un Workflow**. [Seguro]

> Matiz honesto: GHL nativo **no tiene un "auto-countersign" 100% automático** documentado.
> La Parte A (GasManager) se resuelve haciendo que el **representante firme una vez** (o dejando su
> firma/rol pre-asignado en la plantilla). Si necesitas que la Parte A quede **firmada sin intervención
> humana cada vez**, ahí conviene **PandaDoc/DocuSign vía webhook** (rol de remitente con firma aplicada
> automáticamente). [Probable]

### Opción 1 — Nativo GHL (recomendado para empezar)

1. **Payments/Documents → Templates → New:** "Contrato Suscripción GasManager".
2. En la plantilla agrega **2 firmantes (recipients):**
   - **Parte A — GasManager:** asígnalo a un **business user** (tu representante legal). Coloca su bloque de firma; puedes dejarla **pre-firmada** en la plantilla.
   - **Parte B — Instalador:** asígnalo al **{{contact}}**. Coloca su bloque de firma + iniciales.
3. **Pre-llenado con Custom Values:** inserta en el cuerpo `{{contact.first_name}}`, `{{contact.nombre_empresa}}`, `{{contact.licencia}}`, `{{contact.ciudad}}`, plan y precio. Los datos de GasManager (Parte A) van fijos en la plantilla.
4. **Workflow B – disparo automático:**
   - **Trigger:** `Order Form Submission` (o `Payment Received`).
   - **Action – Add Tag** `pago-ok`.
   - **Action – Send Document/Contract** → selecciona la plantilla → destinatario Parte B = contacto.
   - **Action – Add Tag** `contrato-enviado`.
   - (La Página 2 del funnel además redirige al enlace para firmar de inmediato.)
5. **Cierre del ciclo:**
   - **Trigger/Branch:** evento **Documento Firmado/Completado** → **Add Tag** `contrato-firmado`.
   - **Action:** provisiona la cuenta (Webhook a GasManager / notifica onboarding) → **Add Tag** `cliente-activo` → email de bienvenida con accesos.
   - Si NO firma en 48 h → recordatorio WhatsApp/Email; a las 96 h → aviso a ventas.

### Opción 2 — PandaDoc / DocuSign (si exiges Parte A 100% automática)

1. Workflow B → **Webhook** (Order/Payment) hacia PandaDoc/DocuSign API (o vía Make/Zapier).
2. La plantilla tiene **2 roles**: *Remitente (Parte A)* con **firma aplicada automáticamente** y *Firmante (Parte B)* = instalador.
3. Pre-llenas tokens con los datos del contacto (mismos Custom Values vía payload del webhook).
4. La plataforma envía el enlace de firma SOLO a Parte B; al completar, **webhook de retorno** a GHL → tag `contrato-firmado` → activación.

---

## Orden de implementación sugerido (1 tarde)

1. Stripe + Producto + Custom Fields + Tags (Módulo 1 y 2 base).
2. Funnel 2 páginas con One-Step Order Form (Módulo 2).
3. Plantillas Email/SMS/WhatsApp (Módulo 4) — **registra A2P/templates antes**.
4. Workflow A (nutrición) (Módulo 3).
5. Plantilla de contrato + Workflow B (Módulo 5).
6. Prueba E2E con un contacto de test (import → secuencia → checkout test → contrato → firma → activación).

---

### Fuentes (capacidades GHL verificadas)
- Documents & Contracts – guía: https://help.gohighlevel.com/support/solutions/articles/155000000594-how-to-use-documents-contracts-
- Múltiples destinatarios (incluir al sender como firmante): https://help.gohighlevel.com/support/solutions/articles/155000001300-multiple-recipient-support-on-documents-contracts
- Enviar contratos desde Workflows: https://help.gohighlevel.com/support/solutions/articles/155000001301-how-to-create-and-send-document-or-contract-templates-automatically-in-a-workflow
- Trigger Order Form Submission: https://help.gohighlevel.com/support/solutions/articles/155000003253-workflow-trigger-order-form-submission
- Order Submitted vs Order Form Submission: https://help.gohighlevel.com/support/solutions/articles/155000004303-workflow-trigger-order-submitted-vs-order-form-submission
- One-Step Order Form en Funnel: https://help.gohighlevel.com/support/solutions/articles/155000007238-how-to-add-a-one%E2%80%91step-order-form-to-a-funnel
- Trigger Payment Received: https://help.gohighlevel.com/support/solutions/articles/155000003534-workflow-trigger-payment-received
