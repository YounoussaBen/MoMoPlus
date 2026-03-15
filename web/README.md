# MoMoPlus Admin

Internal admin dashboard for MoMoPlus, built with Next.js 16 and set up for day-one development.

## Stack

- Next.js 16 App Router
- React 19 with strict TypeScript
- Tailwind CSS v4
- ESLint 9 with `next/core-web-vitals`
- Prettier with Tailwind class sorting
- Husky + lint-staged pre-commit checks
- Typed route support enabled in `next.config.ts`

## Getting Started

```bash
pnpm install
pnpm dev
```

Open `http://localhost:3000`.

## Scripts

```bash
pnpm dev           # Start the app in development with Turbopack
pnpm build         # Create a production build
pnpm start         # Run the production server
pnpm lint          # Run ESLint with zero warnings allowed
pnpm lint:fix      # Auto-fix lint issues
pnpm typecheck     # Generate Next.js route types and run TypeScript checks
pnpm format        # Format the project with Prettier
pnpm format:check  # Verify formatting
pnpm check         # Run formatting, linting, and type checks
```

## Git Hooks

Running `pnpm install` configures Husky for this nested `web/` app.

- `pre-commit` runs web `lint-staged`, web type checks, and backend `pre-commit` hooks when backend files are staged.
- `pre-push` runs the web production build.
