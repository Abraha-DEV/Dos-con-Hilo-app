# Contrato del catálogo público para la landing

La landing conserva su código y despliegue independiente. En el esquema compartido no aparece una vista `published_catalog`; antes de conectarla habrá que crear una vista limitada o definir una política RLS de lectura anónima que solo permita productos publicados. La app administrativa consulta `products` con sesión y filtrado por negocio.

## Campos

| Campo | Tipo | Uso |
| --- | --- | --- |
| `id` | UUID | Identificador estable del producto |
| `business_id` | UUID | Filtro al negocio de Dos con Hilo; no es un secreto |
| `name` | texto | Nombre público |
| `description` | texto | Descripción pública |
| `category` | texto | Categoría |
| `price` | decimal | Precio vigente |
| `stock` | entero | Disponibilidad actual |
| `image_url` | texto/null | URL de imagen |
| `updated_at` | timestamp | Sincronización/caché |

La consulta pública debe filtrar `business_id` al UUID configurado para Dos con Hilo y puede ordenar por nombre o fecha de actualización. Si se expone una vista, debe contener únicamente estos campos. No dar acceso público a `business_members`, ventas, clientes, pedidos ni movimientos.

Al publicar un cambio, la landing verá el precio, publicación y existencia vigentes en su siguiente lectura. Para disponibilidad, el diseño debe decidir cómo mostrar `0` (agotado) y refrescar o revalidar caché. Las fotos que sube la app se guardan en el bucket público `product-images` y `image_url` contiene la URL pública de Storage.

Nunca agregar `service_role`, tokens de administración, ventas, clientes, pedidos ni información de pago a la landing. La clave anon es pública y la seguridad depende de grants y RLS.
