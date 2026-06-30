# GasManager — Centro de Ayuda (estructura + artículos base)

> Adaptado: GasManager no tiene compradores/vendedores; la audiencia es el
> **Instalador** (usuario de la app) y, aparte, **tú** (operador del Cockpit).
> Meta: que cada duda se resuelva en menos de 2 minutos sin abrir un ticket.

---

## Arquitectura de información

```
Inicio del Centro de Ayuda
├── Para Instaladores
│   ├── Primeros pasos (crear cuenta, conectar, primer proyecto)
│   ├── Instalaciones (alta, edición, estados de certificación)
│   ├── Certificaciones y vencimientos
│   ├── Migrar mis proyectos desde e-declarador
│   ├── Mapa y Agenda
│   ├── Equipo y accesos
│   ├── Planes, cobro y "comprar más proyectos"
│   └── Agente de WhatsApp (plan Agente)
├── Confianza y Seguridad
│   ├── Cómo protegemos tus datos
│   ├── Verificación de instalador (SEC)
│   └── Reportar un problema
└── Contáctanos
    ├── Enviar una solicitud
    └── WhatsApp / correo de soporte
```

---

## Top 10 (P1 — escribir primero)

1. ¿Cómo creo mi primera instalación?
2. ¿Qué significan los estados Vigente / Por vencer / Vencida?
3. ¿Cómo migro mis proyectos desde e-declarador?
4. ¿Cómo veo qué certificaciones están por vencer?
5. ¿Cómo cambio de plan o compro más proyectos?
6. Llegué al tope de proyectos, ¿qué hago?
7. ¿Qué es el agente de WhatsApp y cómo lo activo?
8. ¿Cómo agrego a alguien de mi equipo?
9. No veo mis datos después de iniciar sesión (¿por qué?).
10. ¿Cómo protegen mis datos y los de mis clientes?

---

## Artículos base (formato pregunta → respuesta)

### ¿Cómo creo mi primera instalación?
**Aplicable a:** Instaladores

Desde **Instalaciones**, pulsa **Nueva instalación**, completa los datos y guarda.

1. En el menú lateral, entra a **Instalaciones**.
2. Arriba a la derecha, pulsa **Nueva instalación**.
3. Completa cliente, dirección, comuna, tipo de gas y estado.
4. Pulsa **Crear instalación**. Aparecerá en tu lista.

**Problemas comunes**
- *No me deja crear:* puede que llegaste al tope de tu plan → ver "Comprar más proyectos".

Relacionado: [Estados de certificación] · [Comprar más proyectos]

---

### ¿Cómo migro mis proyectos desde e-declarador?
**Aplicable a:** Instaladores

Exportas tus declaraciones **tú mismo** desde e-declarador y las subes a GasManager;
nosotros las importamos. **Nunca te pedimos tu contraseña de e-declarador.**

1. Entra a e-declarador (SEC) con tu usuario.
2. Descarga/exporta tus declaraciones (o guarda los comprobantes TC6 en PDF).
3. En GasManager, ve a **Instalaciones → Importar** y sube los archivos.
4. Revisa la previsualización y confirma. Tus proyectos quedan cargados.

> Por seguridad y por ley, GasManager no inicia sesión en e-declarador por ti.

Relacionado: [Cómo protegemos tus datos]

---

### Llegué al tope de proyectos, ¿qué hago?
**Aplicable a:** Instaladores (plan Básico)

El plan Básico incluye un número limitado de proyectos. Para seguir, **mejora tu plan**
o **compra más proyectos** desde **Plan y ajustes**.

1. Ve a **Plan y ajustes**.
2. Pulsa **Comprar más proyectos** o elige **Pro/Agente** (proyectos ilimitados).
3. Completa el pago; tu tope se actualiza automáticamente al confirmarse.

Relacionado: [Cambiar de plan] · [Agente de WhatsApp]

---

### No veo mis datos después de iniciar sesión
**Aplicable a:** Instaladores · *Solución de problemas*

Casi siempre es por permisos (RLS): tu cuenta debe estar asociada a tu organización.

- **Causa:** tu correo no está habilitado en la organización.
- **Solución:** pide al administrador que te agregue en **Equipo**, o contacta soporte.

Relacionado: [Equipo y accesos]

---

## Ruta de escalación

```
Duda → Buscar en el centro de ayuda
     → Sin respuesta → sugerir artículos relacionados
     → Sigue sin respuesta → Formulario de contacto (con categoría)
     → Ticket creado → autorespuesta con tiempo estimado
     → Soporte humano responde (meta: < 24 h hábiles)
```

---

## Métricas a seguir
- Tasa de contacto (visitantes que abren ticket — más bajo, mejor).
- Búsquedas sin resultado (top keywords) → nuevos artículos.
- "¿Te sirvió?" sí/no por artículo.
- Desviación de tickets tras publicar.

## Lista de verificación
```
- [ ] Sección dedicada para Instaladores (audiencia principal)
- [ ] Top 10 con artículo propio
- [ ] Títulos en forma de pregunta
- [ ] Respuesta en las primeras 2 frases
- [ ] Capturas (o marcadores [CAPTURA: ...])
- [ ] Ruta de contacto visible
- [ ] "¿Te sirvió?" en cada artículo
- [ ] Enlace al centro de ayuda desde toda la app
```
