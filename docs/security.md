# Modelo de seguridad y datos

## Esquema existente del proyecto Supabase

El esquema que proporcionó el negocio es la fuente de verdad; la migración de referencia de este repositorio no debe ejecutarse sobre ese proyecto. Los nombres reales difieren: `products.stock` (no `quantity_available`), `image_url` (no `photo_path`), `sales.sale_channel`/`total`, y los estados y métodos usan valores en español/mayúsculas. Los repositorios de la app deben usar esos nombres y valores.

### Observaciones antes de habilitar escrituras

- `inventory_movements` no contiene `business_id`, columna de autor ni relación con venta/pedido. El script de operaciones agrega `request_id`; el UUID de la usuaria queda en el texto del motivo como auditoría básica.
- `sales` no tiene columna de autor. El script de operaciones agrega clave idempotente por negocio para evitar descuentos duplicados por reintento.
- `sale_items` conserva `unit_price`, pero no conserva el nombre del producto al momento de la venta.
- `order_payments` deriva el negocio a través del pedido y no guarda quién recibió el pago. `custom_orders.deposit` y `order_payments` podrían discrepar si ambos representan el anticipo.
- Hay que verificar que cada FK valide que las filas relacionadas pertenecen al mismo negocio. Las FK actuales aseguran existencia, no coincidencia de `business_id`.
- Las políticas compartidas muestran una lectura pública para productos publicados y políticas de acceso por membresía en productos, pedidos y ventas. El propietario indicó que ya ejecutó los tres scripts iniciales con las políticas adicionales.

Estas limitaciones no impiden leer el catálogo o construir pantallas, pero sí requieren políticas y funciones PostgreSQL cuidadosas antes de permitir operaciones financieras/de inventario. No ejecutar la migración de este repositorio sobre el esquema existente.

El archivo `supabase/manual/20261027_complete_existing_rls.sql` es un complemento específico para las tablas existentes: agrega políticas de lectura de membresías, negocios, movimientos, líneas y pagos; cambia la política `ALL` conocida de ventas a solo lectura. El propietario indicó que ya lo ejecutó. No elimina ni reemplaza las políticas actuales de productos o pedidos. Según las expresiones entregadas, cualquier miembro del negocio puede operar productos y pedidos; las políticas no distinguen por `role`.

El archivo `supabase/manual/20261027_order_payments_rpc.sql` agrega `record_order_payment`, que verifica la membresía y bloquea el pedido durante la operación para que abonos concurrentes no excedan el saldo. El propietario indicó que ya lo ejecutó. La app usa `custom_orders.deposit` como saldo inicial ya recibido en los registros previos; los pagos nuevos se guardan en `order_payments` con su método. Para nuevos pedidos la app inicia `deposit` en cero y registra anticipos como pagos, preservando su método e historial. La función no convierte un abono en una venta.

El archivo `supabase/manual/20261027_sales_inventory_rpcs.sql` agrega claves de idempotencia y RPCs `confirm_sale`, `cancel_sale` y `adjust_inventory`. El propietario indicó que ya lo ejecutó. La confirmación obtiene precios desde la base, bloquea productos, valida stock, registra artículos y movimientos y descuenta existencias en la misma transacción. Cancelar repone stock una sola vez y marca la venta cancelada. La cantidad en `inventory_movements` se guarda como delta firmado (venta negativa, entrada positiva). Los ajustes incluyen UUID de la usuaria en el motivo porque el esquema no dispone de una columna de autor.

## Acceso

- Las tablas del esquema están bajo RLS. La pertenencia se resuelve mediante `business_members` y `auth.uid()`.
- Las políticas actuales admiten a cualquier persona con una fila en `business_members`; no diferencian por `role`. La inserción de membresías debe hacerse desde una herramienta administrativa confiable.
- No se crea una cuenta compartida. Cada persona debe tener su identidad de Supabase Auth y ser agregada como miembro autorizado del negocio.
- No desplegar una clave `service_role` en clientes. La clave pública anon no sustituye RLS.

## Catálogo público

El esquema actual no muestra una vista `published_catalog`. La política `Public products reading` permite leer filas donde `is_published = true`; el resto de tablas no debe tener acceso anónimo. Conviene verificar grants de columnas si se agregan datos internos a `products`.

## Integridad pendiente antes de producción

- Ejecutar `supabase/manual/20261028_product_images_storage.sql` para habilitar el bucket y las políticas nuevas de fotos. Los tres SQL anteriores ya fueron aplicados por el propietario.
- Agregar columna de autor real a ventas, movimientos y pagos si se requiere auditoría estructurada; `reason` solo ofrece una solución textual temporal.
- Las fotos del bucket `product-images` son públicas para servirlas en el catálogo; las cargas y borrados se limitan a integrantes autenticados dentro de la carpeta de su negocio.
- Añadir validaciones de negocio y pruebas SQL/RLS antes de cargar datos reales.

La migración inicial es un punto de partida de desarrollo, no certifica que el backend esté listo para producción. Revisar en una base Supabase desechable antes del despliegue.
