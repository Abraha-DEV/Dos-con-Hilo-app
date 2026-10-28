-- Storage para fotos de productos. Ejecutar una vez en Supabase SQL Editor.
-- Las imágenes son públicas para que la app y el catálogo puedan mostrarlas.
-- Solo integrantes autenticados del negocio pueden subir o borrar en su carpeta.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'Business members upload product images'
  ) then
    create policy "Business members upload product images"
    on storage.objects for insert to authenticated
    with check (
      bucket_id = 'product-images'
      and exists (
        select 1 from public.business_members m
        where m.business_id::text = (storage.foldername(name))[1]
          and m.user_id = (select auth.uid())
      )
    );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'Business members delete product images'
  ) then
    create policy "Business members delete product images"
    on storage.objects for delete to authenticated
    using (
      bucket_id = 'product-images'
      and exists (
        select 1 from public.business_members m
        where m.business_id::text = (storage.foldername(name))[1]
          and m.user_id = (select auth.uid())
      )
    );
  end if;
end
$$;
