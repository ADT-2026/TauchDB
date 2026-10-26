# Initial local setup

1. Install Node.js 20+ and start Docker Desktop.

2. From the repository root, install dependencies:

   ```sh
   cd db
   npm install
   ```

3. Start Supabase (`supabase init` is already done in this repo):

   ```sh
   npx supabase start
   npx supabase status
   ```

4. Create or update `db/.env` using the local database URL from the status output. Defaults:

   ```dotenv
   DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
   DIRECT_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
   ```

5. From `db/`, apply the existing migrations to the fresh database:

   ```sh
   npx prisma migrate deploy
   ```

6. Open Supabase Studio at <http://127.0.0.1:54323> to view the tables.
