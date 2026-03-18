# MoMo Plus — Mobile

Flutter app for MoMo Plus. One codebase, two experiences: **users** borrow emergency funds from nearby agents, **agents** manage requests and disbursements.

---

## Getting Started

```bash
# Copy and fill in environment variables
cp .env.example .env

# Install dependencies
flutter pub get

# Run
flutter run
```

---

## Architecture

Feature-first clean architecture. Shared code lives in `core/`, each role gets its own isolated feature tree under `features/`. Adding new screens for users or agents never touches the other side.

```
lib/
├── main.dart                         # Bootstrap: env + Supabase init + runApp
├── app.dart                          # MomoPlusApp: dependency wiring + MaterialApp.router
│
├── core/                             # Shared across all features
│   ├── config/
│   │   └── app_config.dart           # Environment variables (Supabase, backend URL)
│   ├── data/
│   │   ├── repositories/
│   │   │   └── auth_repository.dart  # Auth contract + Supabase implementation
│   │   └── services/
│   │       ├── backend_api_service.dart    # Django backend HTTP client
│   │       └── supabase_auth_service.dart  # Supabase auth wrapper
│   ├── domain/
│   │   └── models/
│   │       └── app_user.dart         # AppUser model with role + agent status
│   ├── routing/
│   │   └── router.dart               # GoRouter with role-aware redirects
│   └── ui/
│       ├── theme/
│       │   └── app_theme.dart        # Colors, typography, component themes
│       └── widgets/
│           ├── app_button.dart       # Primary / secondary / ghost button variants
│           ├── app_logo.dart         # Logo widget
│           └── app_text_field.dart   # Styled text input
│
└── features/
    ├── auth/
    │   └── presentation/
    │       ├── auth_view_model.dart  # Auth state, sign-in/up, role-aware profile fetch
    │       ├── sign_in_screen.dart
    │       └── sign_up_screen.dart
    │
    ├── splash/
    │   └── presentation/
    │       └── splash_screen.dart    # Animates then routes based on auth + role
    │
    ├── onboarding/
    │   └── presentation/
    │       ├── onboarding_view_model.dart
    │       └── onboarding_screen.dart
    │
    ├── user/                         # Everything for the user role
    │   └── presentation/
    │       └── home/
    │           ├── user_home_view_model.dart
    │           └── user_home_screen.dart
    │
    └── agent/                        # Everything for the agent role
        └── presentation/
            └── home/
                ├── agent_home_view_model.dart
                └── agent_home_screen.dart
```

---

## Key Design

**Role isolation via the router.** After login, `GoRouter` checks the user's role and routes to `/user/home` or `/agent/home`. Guards prevent cross-role navigation — an agent visiting a `/user/**` route is redirected to their own home, and vice versa.

**Feature-first, not layer-first.** Each feature (`auth`, `user`, `agent`, etc.) is a self-contained directory with its own presentation layer. New user screens go in `features/user/`, new agent screens go in `features/agent/` — nothing else needs to change.

**`core/` is the shared foundation.** Models, services, repositories, theme, and widgets used across features all live in `core/`. Features import from `core/`, never from each other (except `auth`, which is a shared concern).

**Thin `main.dart`.** Bootstrap is 12 lines: initialise bindings, load env, initialise Supabase, call `runApp`. All dependency wiring lives in `app.dart`.

**MVVM with Provider.** Each screen has its own `ViewModel` (`ChangeNotifier`). The global `AuthViewModel` is the single source of truth for auth state and the current user's role.

---

## Roles

| Role | Route prefix | Description |
|------|-------------|-------------|
| `user` | `/user/**` | Borrows funds, finds agents, repays loans |
| `agent` | `/agent/**` | Receives requests, disburses funds, manages repayments |

A user can apply to become an agent from their home screen. Applications are reviewed by staff via the admin web panel. Once approved, the user's role is updated and they are routed to the agent experience on next login.
