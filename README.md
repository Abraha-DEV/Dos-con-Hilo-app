# Dos con Hilo Admin

Aplicación administrativa multiplataforma para Dos con Hilo, construida con Flutter, Riverpod, `go_router`, Material 3 y Supabase.

## Estado

Incluye inicio de sesión por invitación, CRUD de productos, inventario, ventas con carrito, pedidos personalizados y pagos, dashboard e informe mensual con productos más vendidos. El CRUD y las operaciones reales dependen de RLS y funciones PostgreSQL. Los tres scripts previos ya fueron aplicados al proyecto; el nuevo script de imágenes se debe ejecutar para habilitar la carga de fotos.

Las fotos de productos se eligen desde galería o cámara y se guardan en Supabase Storage. La exportación de reportes y las pruebas de integración/RLS siguen pendientes.

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

Las tablas existentes son la fuente de verdad. **No ejecutes** `supabase/migrations/202610270001_initial_schema.sql` en ese proyecto. Ya aplicaste los tres primeros scripts. Para activar la nueva carga de imágenes, ejecuta solo este archivo desde Supabase SQL Editor:

`supabase/manual/20261028_product_images_storage.sql`

Ese script prepara el bucket público `product-images` y restringe las cargas y borrados a integrantes autenticados dentro de la carpeta de su negocio. Los scripts se ejecutan manualmente desde Supabase SQL Editor, no desde este repositorio.

Invita cada cuenta desde Supabase Auth y agrega su `user_id` a `business_members` con el UUID del negocio. La app no incluye una pantalla de invitaciones porque requeriría privilegios administrativos. La versión actual usa la primera membresía de cada usuaria y está pensada para un negocio por cuenta.

## Organización

- `lib/core`: configuración, tema, rutas y utilidades.
- `lib/features`: auth, dashboard, productos, inventario, ventas, pedidos y reportes.
- `supabase/manual`: cambios de seguridad y RPC para el esquema existente.
- `supabase/migrations`: esquema inicial de referencia, no destinado al proyecto ya creado.
- `docs`: modelo de seguridad y contrato para la landing independiente.
- `assets/img`: coloca aquí el logo oficial para integrarlo y ajustar el tema a sus colores.
