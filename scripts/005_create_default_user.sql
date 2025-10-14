-- Script para crear un usuario por defecto
-- IMPORTANTE: Este script debe ejecutarse desde el dashboard de Supabase
-- OPCION 1: Usar el dashboard de Supabase (Recomendado)
-- 1. Ve a Authentication > Users en tu dashboard de Supabase
-- 2. Haz clic en "Add user"
-- 3. Email: admin@empresa.com
-- 4. Password: admin123
-- 5. Confirmed: Sí
-- 6. User Metadata: {"full_name": "Administrador", "role": "Admin"}

-- OPCION 2: Usar la función de Supabase (Requiere permisos de service role)
-- Ejecutar desde el cliente de Supabase con service role key:

/*
const { createClient } = require('@supabase/supabase-js')

const supabase = createClient(
  'YOUR_SUPABASE_URL',
  'YOUR_SERVICE_ROLE_KEY' // No la anon key!
)

const { data, error } = await supabase.auth.admin.createUser({
  email: 'admin@empresa.com',
  password: 'admin123',
  email_confirm: true,
  user_metadata: {
    full_name: 'Administrador',
    role: 'Admin'
  }
})

if (error) {
  console.error('Error creating user:', error)
} else {
  console.log('User created:', data)
}
*/

-- OPCION 3: Script SQL directo (Solo si tienes permisos de superusuario)
-- Descomenta las siguientes líneas si tienes acceso directo a la base de datos:

/*
-- Crear usuario por defecto en auth.users
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'admin@empresa.com',
  crypt('admin123', gen_salt('bf')),
  NOW(),
  '{"provider": "email", "providers": ["email"]}',
  '{"full_name": "Administrador", "role": "Admin"}',
  NOW(),
  NOW()
);

-- El trigger automáticamente creará el perfil en public.profiles
*/

-- Verificar que el usuario existe (ejecutar después de crear el usuario)
SELECT 
  p.id,
  p.email,
  p.full_name,
  p.role,
  p.created_at
FROM public.profiles p
WHERE p.email = 'admin@empresa.com';
