# TauchDB Schema 2

Lokales Supabase und prisma setup. 

## Installation
- npm install
- npx supabase init
- npx supabase start
- npx prisma init

## Anwenden der Migrationen

npx prisma migrate dev wendet die bestehenden migrationen init (aus schema.prisma generiert) und constraints_and_triggers (enthält sql constraints die nicht mit der orm Sprache von Prisma dargestellt werden können) an.

Danach kann mit npx prisma studio mit der datenbank interagiert werden
