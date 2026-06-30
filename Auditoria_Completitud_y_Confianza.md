# GasManager — Auditoría de Completitud + Confianza y Seguridad

> Objetivo: corroborar que todo esté **en regla** y listar **lo que falta para 100%**.
> Aplica (adaptado) el marco de *Sistema de Confianza de Plataforma*. Nota honesta:
> GasManager **no es un marketplace** con compra-venta entre extraños; es **SaaS B2B de
> dos lados** (tú → instaladores; instaladores → sus clientes). Por eso reseñas/disputas
> entre pares no aplican; sí aplican verificación, protección de datos, fraude de cobro y
> abuso del agente.

---

## PARTE A — Estado actual (lo que YA está en regla)

| Pieza | Estado | Verificación |
|---|---|---|
| App A (gas) — shell, branding, logo, azul eléctrico | ✅ | build verde |
| App A — Auth (login, middleware, logout, rutas protegidas) | ✅ | build verde |
| App A — Instalaciones (lista, filtros, detalle, alta, edición) | ✅ | build verde |
| App A — Mapa (Leaflet por estado), Certificaciones, Agenda, Equipo | ✅ | build verde |
| App A — Plan (uso vs. tope, planes, CTA checkout) + gate de tope | ✅ | build verde |
| App A — Webhook de cobro (`/api/webhooks/billing`) | ⚠️ stub | compila; falta firma + tabla |
| Motor (Replai/whatsapp-saas) — superadmin + YCloud + agentes | ✅ código | build verde; 6 archivos clobbered reparados |
| Lista de captación (2.183 instaladores → CSV GHL) | ✅ | depurada |
| Playbook GoHighLevel | ✅ | entregado |

---

## PARTE B — Confianza y Seguridad (marco aplicado a GasManager)

### B1. Prevención (verificación que SÍ importa, sin burocracia)
- **Instalador verificado SEC:** validar **RUT + licencia/clase** contra el registro
  SEC antes de marcar la cuenta como "Verificada". Es tu insignia de confianza natural
  (el cliente del instalador confía porque está autorizado). Señal de alto valor.
- **Completitud de perfil de organización:** nombre, RUT, comuna, clase — desbloquea
  el agente y el envío a clientes.
- **Verificación de pago** antes de activar plan pagado (lo hace Stripe/GHL).
- **Límite de cuenta nueva:** el gate de tope del plan básico ya cumple esto.

### B2. Detección (fraude/abuso relevante a tu modelo)
| Señal | Acción |
|---|---|
| Múltiples organizaciones con mismo RUT/IP | Revisión manual |
| Pico de mensajes del agente (spam a clientes) | Throttle + alerta |
| Contracargos del instalador (3+/90 días) | Revisión de cuenta + pausa de plan |
| Agente intentando enviar a listas no consentidas | Bloqueo (cumplimiento WhatsApp) |

### B3. Resolución (disputas que SÍ existen aquí)
- **Cobro (tú ↔ instalador):** flujo de reembolso/cancelación claro, ventana de apelación.
  Evidencia: estado de suscripción, uso real, fechas.
- **Instalador ↔ su cliente:** **fuera del alcance de la plataforma** — GasManager es la
  herramienta, no árbitro entre el instalador y su cliente final. Dejarlo explícito en TyC.

### B4. Protección de datos (lo más crítico "en regla") — Chile
- Manejas **PII de instaladores y de sus clientes** (nombre, RUT, tel, email, dirección).
- **Ley 19.628 / Ley 21.719 (2026):** base legal para tratar datos, finalidad declarada,
  derecho de acceso/rectificación/eliminación, y **opt-out** en toda comunicación.
- **Outreach en frío (los 2.183):** registrar A2P/plantillas, consentimiento y opt-out
  (ya está en el playbook). No es opcional.
- **Credenciales de terceros:** confirmado — **no** se piden cuentas de e-declarador;
  importación self-service.

### B5. Insignias / señales de confianza (adaptadas)
- ✅ **Instalador Verificado SEC** · 🛡️ **Certificaciones al día** (badge si 0 vencidas)
  · ⏱️ **Responde rápido** (si usa el agente) · 📅 **Establecido** (antigüedad).

---

## PARTE C — Lo que FALTA para 100% (con la skill que lo cubre)

### Técnico / producto
1. **Deploy del motor** en Supabase "Replai" (19 migraciones) + Vercel + env + super admin + cron. *(bloqueado en tus keys / 1 comando de terminal)*
2. **Tabla `suscripciones`** en "Gerente de Gas" + cablear el webhook real (firma Stripe/GHL, mapeo precio→plan). → habilita cobro real.
3. **Verificar RLS/login real** con tu anon key (datos bajo sesión).
4. **Importador e-declarador self-service** (parser de export/PDF del instalador).
5. **Puente App A ↔ Motor** (mapeo organización↔workspace + webhook de alta de agente).
6. **Verificación SEC automatizada** (RUT/licencia) para la insignia "Verificado".

### Plataforma (skills nuevas)
7. **Centro de ayuda** para instaladores → *skill `centro-ayuda-plataforma`* (autoservicio, tutoriales, escalamiento).
8. **Documentación de API** del webhook/puente → *skill `documentacion-api`*.
9. **Alianzas** (certificadores, gremios, ferreterías) → *skill `asociacion-plataforma`* (más adelante).

### Legal / contenido
10. **Términos de Servicio + Política de Privacidad** (Ley 21.719), aviso de opt-out, DPA si aplica. *(requiere abogado; yo dejo el borrador estructurado)*

---

## PARTE D — Checklist "en regla"

```
CONFIANZA & SEGURIDAD
- [ ] Verificación SEC (RUT/licencia) antes de insignia Verificado
- [ ] Gate de tope de plan activo (✅ hecho en código)
- [ ] Detección de spam del agente (throttle) — pendiente
- [ ] Flujo de reembolso/cancelación + apelación documentado
- [ ] Monitoreo de contracargos

DATOS / CUMPLIMIENTO
- [ ] Base legal + finalidad declarada (Ley 21.719)
- [ ] Opt-out en todo SMS/WhatsApp/email (✅ en playbook)
- [ ] A2P 10DLC / plantillas WhatsApp aprobadas
- [ ] Sin credenciales de terceros (✅ confirmado)
- [ ] TyC + Política de Privacidad publicadas

PRODUCTO
- [ ] Motor desplegado (Supabase Replai + Vercel)
- [ ] Tabla suscripciones + webhook firmado → cobro real
- [ ] RLS verificado con login real
- [ ] Importador e-declarador
- [ ] Puente App A ↔ Motor
```

---

### Próximas skills a aplicar (en orden sugerido)
1. `documentacion-api` — documentar webhook de cobro + puente (contrato técnico claro).
2. `centro-ayuda-plataforma` — soporte autoservicio para instaladores.
3. `asociacion-plataforma` — alianzas para crecer (más adelante).
