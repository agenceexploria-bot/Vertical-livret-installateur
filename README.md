# MB02 — Livret Installateur Digital (Vertical Monte-Charges / Actiwork)

Application de suivi de chantiers pour les installations de monte-charges et
élévateurs de fret, composée de deux interfaces partageant la même base de
code Flutter et la même API :

- **Livret installateur** : une **PWA mobile-first** (installable sur
  smartphone sans passer par un store — voir section 6) permettant à
  l'installateur de compléter en autonomie le livret de chaque chantier
  (fiche chantier, dossier technique, auto-contrôle, retour d'expérience,
  signature du PV...), y compris **hors connexion** grâce à un cache local
  (Drift) synchronisé automatiquement au retour du réseau.
- **Back-office Web** : destiné aux Chargés d'Affaires (CA), à la Qualité et
  à l'Admin, pour la création et le suivi des chantiers, la gestion des
  comptes installateurs, le dépôt de documents de référence et la
  consultation des livrets/PV signés.

Production : https://vertical-livret-installateur.vercel.app/

## 1. Sommaire

1. [Stack technique](#2-stack-technique)
2. [Prérequis](#3-prérequis)
3. [Installation & configuration locale](#4-installation--configuration-locale)
4. [Déploiement (production)](#5-déploiement-production)
5. [Guide d'installation mobile (PWA)](#6-guide-dinstallation-mobile-pwa)
6. [Rôles et permissions](#7-rôles-et-permissions)
7. [Structure du dépôt](#structure-du-dépôt)

## 2. Stack technique

| Domaine | Technologie |
|---|---|
| Frontend | **Flutter** (Web PWA + Android/iOS), une seule base de code pour l'app installateur et le back-office |
| Cache local / mode hors-ligne | **Drift** (SQLite embarqué) + moteur de synchronisation maison (`lib/data/sync/sync_engine.dart`) |
| Backend | **Node.js** / **Express** / **TypeScript**, déployé comme fonction serverless unique sur Vercel (`api/index.ts`) |
| ORM / Base de données | **Prisma** ORM + **PostgreSQL** (hébergé sur **Neon**, serverless) |
| Stockage fichiers | **Vercel Blob** (photos, PDF, notes vocales, signatures) |
| Authentification | JWT (access + refresh token), 2FA par email à l'inscription (SMTP) |
| Déploiement | **Vercel** (hébergement) + **GitHub Actions** (CI/CD, build Flutter) |
| Tests | Vitest (backend), `flutter analyze` (frontend) |

## 3. Prérequis

À installer avant de commencer :

- **Flutter SDK** — version utilisée en CI/production : `3.44.7` (canal
  stable). Vérifiez avec `flutter --version` ; installez via
  https://docs.flutter.dev/get-started/install.
- **Node.js** 20 ou supérieur, avec **npm**.
- **Git**.
- Un accès à une base **PostgreSQL** (Neon recommandé : https://neon.tech,
  plan gratuit suffisant pour le développement).
- Pour les uploads de fichiers en local : un **Vercel Blob Store** (créé
  depuis un projet Vercel, voir section 4).
- Pour le 2FA par email : des identifiants **SMTP** valides (Gmail + mot de
  passe d'application fonctionne bien, voir `backend/.env.example`).

_Optionnel_ : le CLI Vercel (`npm i -g vercel`) si vous devez inspecter ou
déclencher manuellement des déploiements.

## 4. Installation & configuration locale

### 4.1. Cloner le dépôt

```bash
git clone https://github.com/agenceexploria-bot/Vertical-livret-installateur.git
cd Vertical-livret-installateur
```

### 4.2. Frontend (Flutter)

```bash
flutter pub get
```

### 4.3. Backend (Node/Express/Prisma)

```bash
cd backend
npm install
cp .env.example .env
```

Renseignez ensuite `backend/.env` (voir `backend/.env.example` pour le détail
de chaque variable et où l'obtenir) :

| Variable | Rôle |
|---|---|
| `DATABASE_URL` | Connexion Postgres (Neon) utilisée par l'app |
| `TEST_DATABASE_URL` | Base **distincte** utilisée uniquement par `npm test` (reset à chaque run — ne jamais pointer vers `DATABASE_URL`) |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | Secrets de signature des jetons d'authentification |
| `BLOB_READ_WRITE_TOKEN` | Token Vercel Blob (Storage > Create Database > Blob dans un projet Vercel) |
| `PORT` | Port du serveur local (défaut `3000`) |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` / `SMTP_FROM` | Envoi réel du code à 6 chiffres (2FA inscription) — **obligatoires**, le serveur refuse de démarrer si l'une manque |
| `OPENAI_API_KEY` | Transcription automatique (Whisper) des notes vocales REX — **optionnelle** : sans elle, la note vocale est envoyée normalement mais reste sans transcription automatique |

Puis initialisez la base de données :

```bash
npx prisma migrate dev     # applique les migrations existantes (prisma/migrations)
npm run prisma:generate    # régénère le client Prisma
npm run prisma:seed        # (optionnel) charge les comptes et chantiers de démo — voir section 7
```

**Créer un compte Admin** : il n'existe aucune route API pour ça (`POST
/auth/signup` crée toujours un installateur, `POST /auth/signup-interne`
n'accepte que `coordinateurTravaux` — les rôles à privilèges ne sont
volontairement pas self-service). Le seed ci-dessus en crée déjà un
(`admin@actiwork.fr` / `demodemo`) ; pour un compte Admin isolé sans
lancer tout le seed, utilisez `backend/prisma/createAdmin.ts` (upsert sur
l'email, n'écrase jamais un compte existant — email/mot de passe passés en
variables d'environnement, jamais codés en dur) :

```bash
cd backend
ADMIN_EMAIL="admin@vertical.fr" ADMIN_PASSWORD="change-me" npx tsx prisma/createAdmin.ts
```

### 4.4. Démarrer les serveurs

```bash
# Backend (depuis backend/)
npm run dev                 # tsx watch src/server.ts — http://localhost:3000

# Frontend (depuis la racine, dans un autre terminal)
flutter run -d chrome       # Web (back-office ou installateur, selon l'URL)
flutter run                 # Mobile — émulateur ou appareil connecté
```

> **Test sur téléphone physique** : un mobile ne peut pas résoudre
> `localhost` vers le backend qui tourne sur votre PC. Mettez à jour
> `_devMachineLanIp` dans `lib/data/api_client.dart` avec l'adresse IP locale
> de votre machine (Windows : `ipconfig`, carte Wi-Fi, ligne "Adresse IPv4"),
> téléphone et PC sur le même réseau Wi-Fi.

### 4.5. Tests & vérifications

```bash
flutter analyze                        # Lint/analyse statique Flutter
cd backend && npx tsc --noEmit -p .    # Typecheck backend
cd backend && npm test                 # Tests backend (Vitest)
```

## 5. Déploiement (production)

Le déploiement est **entièrement automatisé** via GitHub Actions — il n'y a
normalement rien à faire manuellement après un `git push` sur `main`.

1. `.github/workflows/deploy.yml` se déclenche à chaque push sur `main` :
   installe Flutter (`3.44.7`), exécute `flutter build web --release`,
   injecte le SHA du commit dans le service worker PWA (invalide le cache
   des visiteurs précédents), puis déploie avec `npx vercel --prod`
   (nécessite le secret de dépôt GitHub `VERCEL_TOKEN`).
2. Côté Vercel, `vercel.json` définit `outputDirectory: "build/web"` (le
   build Flutter déjà fait par l'Action) et un `buildCommand` qui exécute
   `cd backend && npm install && npx prisma generate && npx prisma migrate
   deploy` (génération du client Prisma pour la fonction serverless
   `api/index.ts`, puis application des migrations en attente sur la base de
   production).
3. `vercel.json` déclare `"git": { "deploymentEnabled": false }` :
   l'intégration Git native de Vercel (qui clonerait le dépôt et échouerait
   systématiquement, faute d'étape de build Flutter côté Vercel) est
   désactivée — **seule** l'Action GitHub ci-dessus déclenche un
   déploiement.

**Point d'attention** : `npx prisma migrate deploy` n'applique que les
migrations déjà présentes dans `prisma/migrations/` — pensez à générer et
committer la migration (`npx prisma migrate dev` en local) **avant** de
pousser un changement de `prisma/schema.prisma` sur `main`, sinon le schéma
de prod ne bougera pas.

Vérifier l'état d'un déploiement :

```bash
npx vercel ls                          # liste des déploiements récents
npx vercel inspect <url> --logs        # logs de build d'un déploiement précis
```

## 6. Guide d'installation mobile (PWA)

L'application installateur s'installe directement depuis le navigateur,
**sans passer par le Play Store ni l'App Store**.

### Android (Google Chrome)

1. Ouvrez https://vertical-livret-installateur.vercel.app/ dans Chrome.
2. Appuyez sur le menu ⋮ (trois points, en haut à droite).
3. Sélectionnez **« Installer l'application »** (ou **« Ajouter à l'écran
   d'accueil »** selon la version de Chrome).
4. Confirmez — une icône « Vertical » apparaît sur l'écran d'accueil, l'app
   s'ouvre ensuite en plein écran comme une app native.

### iPhone / iPad (Safari — obligatoirement Safari, pas Chrome)

1. Ouvrez https://vertical-livret-installateur.vercel.app/ dans **Safari**.
2. Appuyez sur l'icône **Partager** (carré avec une flèche vers le haut, en
   bas de l'écran).
3. Faites défiler et sélectionnez **« Sur l'écran d'accueil »**.
4. Confirmez le nom puis appuyez sur **« Ajouter »**.

Une fois installée, l'app fonctionne hors-ligne (les données déjà
synchronisées restent accessibles) et se met à jour automatiquement au
prochain lancement avec réseau.


## 7. Rôles et permissions

| | Installateur | CA (+ Qualité) | Admin |
|---|---|---|---|
| **Interface** | Mobile (PWA) | Web + Mobile (consultation/upload) | Web uniquement |
| Consulter ses chantiers rattachés | ✅ | — | — |
| Créer / modifier un chantier | ❌ | ✅ | ✅ |
| **Supprimer** un chantier | ❌ | ❌ | ✅ (uniquement) |
| Compléter le livret (fiche, auto-contrôle, REX, PV) | ✅ (chantiers rattachés uniquement) | Consultation | Consultation |
| Supprimer un REX (déblocage pour re-soumission) | ❌ | ✅ | ✅ |
| Déposer des documents terrain (bons, constats...) | ✅ | Consultation/téléchargement | Consultation/téléchargement |
| Déposer des documents de référence chantier (Modules 1-3) | Consultation | ✅ (Web + Mobile) | ✅ |
| Valider / suspendre un compte installateur | ❌ | ✅ | ✅ |
| Gérer les comptes internes (CA/Qualité/Admin) | ❌ | ❌ | ✅ |
| **Supprimer** un compte utilisateur | ❌ | ❌ | ✅ (uniquement) |

Le rôle `direction` existe également dans le modèle de données avec des
permissions équivalentes au CA ; il n'est pas alimenté par le script de seed.
Toutes les suppressions (chantiers, comptes, REX) sont **définitives et
immédiates**, y compris sur les fichiers associés stockés sur Vercel Blob.

## Structure du dépôt

```
lib/                      Application Flutter (Web + Mobile)
  core/                   Thème, widgets partagés, utilitaires
  data/                   Client API, repositories, modèles, cache offline (Drift)
  screens/                Écrans installateur (mobile) et back-office (CA/Admin)
  state/                  State management (Provider)
backend/
  src/
    routes/               Routes Express (auth, chantiers, comptes, admin, notifications, pusherAuth)
    lib/                  Stockage fichiers (Vercel Blob), email 2FA, SMS
    prisma.ts             Client Prisma
    server.ts             Entrée serveur (dev local)
    app.ts                App Express (réutilisée par api/index.ts en prod)
  prisma/
    schema.prisma         Schéma de données
    migrations/           Migrations SQL
    seed.ts                Comptes et chantiers de démonstration
    createAdmin.ts        Crée (upsert) un compte Admin isolé — voir section 4
  .env.example            Modèle de configuration locale
api/
  index.ts                Point d'entrée serverless Vercel (wrappe backend/src/app.ts)
.github/workflows/
  deploy.yml              CI/CD : build Flutter + déploiement Vercel à chaque push sur main
vercel.json               Configuration de build/déploiement Vercel
```
