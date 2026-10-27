# Dos con Hilo Admin

Aplicación administrativa multiplataforma para Dos con Hilo, construida con Flutter, Riverpod, `go_router`, Material 3 y Supabase.

## Estado

Incluye inicio de sesión por invitación, CRUD de productos, inventario, ventas con carrito, pedidos personalizados y pagos, dashboard e informe mensual con productos más vendidos. El CRUD y las operaciones reales dependen de RLS y funciones PostgreSQL; los scripts SQL están preparados en `supabase/manual/` y aún deben aplicarse al proyecto Supabase.

La carga de fotos a Storage, exportación de reportes y pruebas de integración/RLS siguen pendientes. Productos usan por ahora un campo URL para la fotografía.

## Requisitos y ejecución

- Flutter estable con Dart 3.8 o superior.
- Proyecto Supabase y la URL/clave pública publishable.

Las credenciales públicas proporcionadas se usan como configuración predeterminada. Para ejecutar en web:

```sh
flutter pub get
flutter run -d chrome
```

Para usar otro proyecto, pasa `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`. También se acepta `SUPABASE_ANON_KEY` por compatibilidad. La clave `service_role` nunca debe incluirse en Flutter, el repositorio o la landing.

## Supabase

Las tablas existentes son la fuente de verdad. **No ejecutes** `supabase/migrations/202610270001_initial_schema.sql` en ese proyecto. Revisa y aplica desde Supabase SQL Editor, en este orden:

1. `supabase/manual/20261027_complete_existing_rls.sql`
2. `supabase/manual/20261027_order_payments_rpc.sql`
3. `supabase/manual/20261027_sales_inventory_rpcs.sql`

Estos scripts agregan políticas de lectura y columnas de idempotencia, y crean RPCs para abonos, ventas, cancelaciones y ajustes de inventario. No se han ejecutado desde este repositorio.

Invita cada cuenta desde Supabase Auth y agrega su `user_id` a `business_members` con el UUID del negocio. La app no incluye una pantalla de invitaciones porque requeriría privilegios administrativos. La versión actual usa la primera membresía de cada usuaria y está pensada para un negocio por cuenta.

## Organización

- `lib/core`: configuración, tema, rutas y utilidades.
- `lib/features`: auth, dashboard, productos, inventario, ventas, pedidos y reportes.
- `supabase/manual`: cambios de seguridad y RPC para el esquema existente.
- `supabase/migrations`: esquema inicial de referencia, no destinado al proyecto ya creado.
- `docs`: modelo de seguridad y contrato para la landing independiente.
