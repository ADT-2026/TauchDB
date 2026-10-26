# Supabase local usage

For the first run, follow [Initial setup](Initial_Setup.md).

Run these commands from `db/` (the directory containing `package.json`), with Node.js 20+ and Docker Desktop running:

```sh
cd db
npm install
```

## Supabase CLI

| Command | Description |
| --- | --- |
| `npx supabase init` | Create `supabase/config.toml` for a new project. Already initialized in this repo; skip this step. |
| `npx supabase start` | Start the local Supabase services in Docker. The first run downloads the images. |
| `npx supabase status` | Show local service URLs, database connection details, and API keys. |
| `npx supabase status -o env` | Print connection details and keys in env format for copying into app configuration. |
| `npx supabase stop` | Stop the local services while preserving local database data. |

Supabase settings and ports live in `supabase/config.toml`. With the current configuration, Studio is at <http://127.0.0.1:54323> and the API is at <http://127.0.0.1:54321>.

## Environment configuration

Set these values in `db/.env` for the default local database:

```dotenv
DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
DIRECT_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
```

Use the database URL printed by `npx supabase status` if your local connection details differ. Both variables use the same direct connection locally. `DATABASE_URL` is for application connections; `DIRECT_URL` is for Prisma CLI schema operations. Keep `.env` out of version control (already ignored in `db/.gitignore`).

## Prisma schema changes

Start Supabase and configure the environment before running these commands from `db/`:

| Command | Description |
| --- | --- |
| `npx prisma db push` | Sync `prisma/schema.prisma` directly to the database for local prototyping. Does not create or apply migration files. |
| `npx prisma migrate deploy` | Apply pending migration files from `prisma/migrations/`, including `0_init` on a fresh database. |
| `npx prisma migrate dev --name describe_change` | Create and apply a migration after editing the Prisma schema during development. |

Choose schema push for prototyping or migrations for tracked changes. Applying `0_init` after `db push` created the same tables can fail because those tables already exist.

References: [Supabase CLI setup](https://supabase.com/docs/guides/local-development/cli/getting-started), [Prisma db push](https://www.prisma.io/docs/cli/v7/db/push), [Prisma migrate deploy](https://www.prisma.io/docs/cli/v7/migrate/deploy).
