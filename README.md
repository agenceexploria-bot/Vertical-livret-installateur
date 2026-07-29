# Vertical — Livret Installateur Digital

Application de suivi de chantiers pour les installations de monte-charges /
élévateurs de fret : livret installateur (mobile), back-office CA/Admin, et
API centralisant les données côté serveur.

- **Frontend** : Flutter (Web PWA + Android), une seule base de code pour
  l'app installateur mobile et le back-office CA/Admin sur Web.
- **Backend** : Node.js / Express / Prisma, déployé comme fonction serverless
  unique sur Vercel (`api/index.ts`).
- **Base de données** : PostgreSQL (Neon, serverless).
- **Stockage fichiers** : Vercel Blob.
- **Déploiement** : Vercel — build Flutter fait en CI (Vercel ne sait pas
  builder Flutter nativement), puis `vercel --prod`.

Production : https://vertical-livret-installateur.vercel.app/

## Structure du dépôt

```
lib/                    Application Flutter (Web + Mobile)
  core/                 Thème, widgets partagés, utilitaires
  data/                 Client API, repositories, modèles, cache offline (Drift)
  screens/              Écrans installateur (mobile) et back-office (CA/Admin)
  state/                State management (Provider)
backend/
  src/
    routes/             Routes Express (auth, chantiers, utilisateurs, ...)
    lib/                Stockage fichiers (Vercel Blob), email 2FA, etc.
    prisma.ts           Client Prisma
    server.ts           Entrée serveur (dev local)
    app.ts              App Express (réutilisée par api/index.ts en prod)
  prisma/
    schema.prisma        Schéma de données
    migrations/           Migrations SQL
api/
  index.ts               Point d'entrée serverless Vercel (wrappe backend/src/app.ts)
.github/workflows/
  deploy.yml              CI/CD : build Flutter + déploiement Vercel à chaque push sur main
```

## Rôles applicatifs

- **Installateur** : utilise l'app mobile pour compléter le livret d'un
  chantier (fiche chantier, dossier technique, auto-contrôle, REX, ...).
- **Chargé d'affaires (CA)** : back-office Web — gestion des chantiers, des
  installateurs, des documents, validation des inscriptions.
- **Admin** : mêmes droits que le CA, plus la gestion complète des comptes
  (modification/suppression de chantiers et de comptes utilisateurs).

## Développement local

### Frontend (Flutter)

```bash
flutter pub get
flutter run -d chrome        # Web
flutter run                  # Mobile (émulateur/appareil connecté)
```

### Backend

```bash
cd backend
npm install
npm run prisma:generate
npm run dev                  # tsx watch src/server.ts
```

Variables d'environnement nécessaires (`.env` dans `backend/`) : `DATABASE_URL`
(Neon, avec suffixe `-pooler`), `JWT_SECRET`, `JWT_REFRESH_SECRET`,
`BLOB_READ_WRITE_TOKEN` (Vercel Blob), identifiants SMTP pour l'envoi des
codes 2FA.

### Tests & vérifications

```bash
flutter analyze                        # Lint/analyse statique Flutter
cd backend && npx tsc --noEmit -p .    # Typecheck backend
cd backend && npm test                 # Tests backend (vitest)
```

## Déploiement

Chaque push sur `main` déclenche `.github/workflows/deploy.yml` : build
Flutter Web, puis déploiement sur Vercel (projet `vertical-livret-installateur`,
scope `explore-ia`) via `vercel --prod`. Le build backend (génération du
client Prisma) est fait par Vercel lui-même au moment du déploiement
(`vercel.json`).
