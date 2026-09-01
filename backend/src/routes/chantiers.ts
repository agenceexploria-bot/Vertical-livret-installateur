import { Router, Response, NextFunction } from 'express';
import { Chantier } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../prisma';
import { serializeChantier } from '../serializers';
import { requireAuth, requireRole, AuthedRequest } from '../middleware/auth';
import { saveBuffer, deleteBlobFile, isOwnBlobUrl } from '../lib/imageStorage';
import { fetchBlobFile, fusionnerSignatureDansPdf } from '../lib/pvMerge';
import { genererPdfPvFormulaire, PvFormReponses } from '../lib/pvFormPdf';
import { PV_SECTION_1, PV_SECTION_2, PV_SECTION_3, PvChecklistItemDef } from '../lib/pvFormulaireDefinition';
import { isPointComplete } from '../lib/pointControleStatus';
import { transcribeAudio } from '../lib/transcription';
import { triggerChantierChanged, triggerChantierDeleted, triggerNotificationCreated } from '../lib/pusher';

export const chantiersRouter = Router();

const CHANTIER_INCLUDE = {
  pointsControle: { orderBy: { ordre: 'asc' as const } },
  installateurs: { include: { user: true } },
  documentsTerrain: { include: { auteur: true } },
  documentsChantier: { orderBy: { createdAt: 'asc' as const } },
  coordinateurTravaux: true,
  rex: { orderBy: { soumisAt: 'desc' as const } },
};

interface ChantierScopedRequest extends AuthedRequest {
  chantier?: Chantier;
}

/// Un installateur ne peut agir que sur un chantier auquel il est rattaché
/// (table ChantierInstallateur) — sans ce garde, n'importe quel installateur
/// authentifié pouvait modifier les points, signer le PV ou déposer un
/// document sur n'importe quel chantier en connaissant sa seule référence.
/// Les rôles internes (CT, Qualité, Direction, Admin) ne sont pas concernés
/// par la notion de rattachement.
async function requireRattachement(req: ChantierScopedRequest, res: Response, next: NextFunction) {
  const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
  if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

  if (req.auth!.role === 'installateur') {
    const rattache = await prisma.chantierInstallateur.findUnique({
      where: { chantierId_userId: { chantierId: chantier.id, userId: req.auth!.userId } },
    });
    if (!rattache) return res.status(403).json({ error: 'Vous n\'êtes pas rattaché à ce chantier' });
  }

  req.chantier = chantier;
  next();
}

chantiersRouter.get('/', requireAuth, async (req: AuthedRequest, res) => {
  const { userId, role } = req.auth!;

  const chantiers = await prisma.chantier.findMany({
    where: role === 'installateur' ? { installateurs: { some: { userId } } } : undefined,
    include: CHANTIER_INCLUDE,
    orderBy: { dateDebut: 'asc' },
  });
  res.json({ chantiers: chantiers.map(serializeChantier) });
});

const createSchema = z.object({
  reference: z.string().min(1),
  client: z.string().min(1),
  adresse: z.string().min(1),
  ville: z.string().min(1),
  dateDebut: z.string(),
  dateFin: z.string(),
  contactNom: z.string().min(1),
  contactTel: z.string().min(1),
  contactEmail: z.string().email().optional(),
  horaires: z.string().min(1),
  consignes: z.array(z.string()).default([]),
  typeMonteCharge: z.string().min(1),
  capacite: z.string().min(1),
  niveaux: z.number().int().positive(),
  referenceAffaire: z.string().min(1),
  coordinateurTravauxId: z.string().optional(),
});

chantiersRouter.post('/', requireAuth, requireRole('coordinateurTravaux', 'direction', 'admin'), async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const d = parsed.data;

  const existing = await prisma.chantier.findUnique({ where: { reference: d.reference } });
  if (existing) return res.status(409).json({ error: 'Cette référence existe déjà' });

  // Rattachement direct à un CT — réservé à l'Admin côté formulaire (voir
  // BoNewChantierScreen), mais vérifié ici indépendamment de qui appelle la
  // route : la valeur fournie doit correspondre à un compte CT existant.
  if (d.coordinateurTravauxId) {
    const ct = await prisma.user.findUnique({ where: { id: d.coordinateurTravauxId } });
    if (!ct || ct.role !== 'coordinateurTravaux') {
      return res.status(400).json({ error: 'CT sélectionné invalide' });
    }
  }

  // Listes de réception/contrôle éditables par l'Admin (voir
  // routes/checklistTemplates.ts) — appliquées telles quelles à ce nouveau
  // chantier ; les modifier ensuite n'affecte jamais les chantiers déjà créés.
  const templates = await prisma.checklistTemplateItem.findMany({ orderBy: { ordre: 'asc' } });

  const chantier = await prisma.chantier.create({
    data: {
      reference: d.reference,
      client: d.client,
      adresse: d.adresse,
      ville: d.ville,
      dateDebut: new Date(d.dateDebut),
      dateFin: new Date(d.dateFin),
      contactNom: d.contactNom,
      contactTel: d.contactTel,
      contactEmail: d.contactEmail,
      horaires: d.horaires,
      consignes: JSON.stringify(d.consignes),
      typeMonteCharge: d.typeMonteCharge,
      capacite: d.capacite,
      niveaux: d.niveaux,
      referenceAffaire: d.referenceAffaire,
      coordinateurTravauxId: d.coordinateurTravauxId,
      pointsControle: {
        create: templates.map(({ type, categorie, libelle, critique, ordre }) => ({ type, categorie, libelle, critique, ordre })),
      },
    },
    include: CHANTIER_INCLUDE,
  });

  await triggerChantierChanged(chantier.reference);
  res.status(201).json({ chantier: serializeChantier(chantier) });
});

chantiersRouter.get('/:reference', requireAuth, requireRattachement, async (req: ChantierScopedRequest, res) => {
  const chantier = await prisma.chantier.findUnique({
    where: { reference: req.params.reference },
    include: CHANTIER_INCLUDE,
  });
  if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });
  res.json({ chantier: serializeChantier(chantier) });
});

chantiersRouter.post('/:reference/rattacher', requireAuth, requireRole('coordinateurTravaux', 'direction', 'admin'), async (req, res) => {
  const { userId } = req.body ?? {};
  if (!userId) return res.status(400).json({ error: 'userId requis' });

  const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
  if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

  await prisma.chantierInstallateur.upsert({
    where: { chantierId_userId: { chantierId: chantier.id, userId } },
    create: { chantierId: chantier.id, userId },
    update: {},
  });

  const updated = await prisma.chantier.findUnique({ where: { id: chantier.id }, include: CHANTIER_INCLUDE });
  await triggerChantierChanged(updated!.reference);
  res.json({ chantier: serializeChantier(updated!) });
});

// Détache un installateur d'un chantier (retire le rattachement) — CT/Direction/Admin.
chantiersRouter.delete(
  '/:reference/rattacher/:userId',
  requireAuth,
  requireRole('coordinateurTravaux', 'direction', 'admin'),
  async (req, res) => {
    const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
    if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

    await prisma.chantierInstallateur.deleteMany({
      where: { chantierId: chantier.id, userId: req.params.userId },
    });

    const updated = await prisma.chantier.findUnique({ where: { id: chantier.id }, include: CHANTIER_INCLUDE });
    await triggerChantierChanged(updated!.reference);
    res.json({ chantier: serializeChantier(updated!) });
  },
);

const updateChantierSchema = z.object({
  client: z.string().min(1).optional(),
  adresse: z.string().min(1).optional(),
  ville: z.string().min(1).optional(),
  dateDebut: z.string().optional(),
  dateFin: z.string().optional(),
  contactNom: z.string().min(1).optional(),
  contactTel: z.string().min(1).optional(),
  contactEmail: z.string().email().optional(),
  horaires: z.string().min(1).optional(),
  consignes: z.array(z.string()).optional(),
  typeMonteCharge: z.string().min(1).optional(),
  capacite: z.string().min(1).optional(),
  niveaux: z.number().int().positive().optional(),
  referenceAffaire: z.string().min(1).optional(),
});

// Modification des informations d'un chantier — CT/Direction/Admin. La
// suppression, elle, reste réservée à l'Admin (capacité destructive
// supplémentaire, voir la route DELETE ci-dessous).
chantiersRouter.patch('/:reference', requireAuth, requireRole('coordinateurTravaux', 'direction', 'admin'), async (req, res) => {
  const parsed = updateChantierSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const d = parsed.data;

  const existing = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
  if (!existing) return res.status(404).json({ error: 'Chantier introuvable' });

  const chantier = await prisma.chantier.update({
    where: { reference: req.params.reference },
    data: {
      client: d.client,
      adresse: d.adresse,
      ville: d.ville,
      dateDebut: d.dateDebut ? new Date(d.dateDebut) : undefined,
      dateFin: d.dateFin ? new Date(d.dateFin) : undefined,
      contactNom: d.contactNom,
      contactTel: d.contactTel,
      contactEmail: d.contactEmail,
      horaires: d.horaires,
      consignes: d.consignes ? JSON.stringify(d.consignes) : undefined,
      typeMonteCharge: d.typeMonteCharge,
      capacite: d.capacite,
      niveaux: d.niveaux,
      referenceAffaire: d.referenceAffaire,
    },
    include: CHANTIER_INCLUDE,
  });
  await triggerChantierChanged(chantier.reference);
  res.json({ chantier: serializeChantier(chantier) });
});

// Suppression d'un chantier — réservé à l'Admin. Les points de contrôle,
// rattachements, documents terrain et documents chantier sont supprimés en
// cascade (voir onDelete: Cascade sur ces relations dans schema.prisma), mais
// la cascade ne nettoie que les lignes en base : les fichiers correspondants
// sur Vercel Blob sont supprimés explicitement ci-dessous avant la suppression,
// sans quoi ils resteraient stockés (et facturés) indéfiniment.
chantiersRouter.delete('/:reference', requireAuth, requireRole('admin'), async (req, res) => {
  const existing = await prisma.chantier.findUnique({
    where: { reference: req.params.reference },
    include: { pointsControle: true, documentsTerrain: true, documentsChantier: true, rex: true },
  });
  if (!existing) return res.status(404).json({ error: 'Chantier introuvable' });

  const filePaths = [
    ...existing.rex.map((r) => r.audioPath),
    existing.pvSignatureImagePath,
    ...existing.pointsControle.map((p) => p.photoPath),
    ...existing.documentsTerrain.map((d) => d.filePath),
    ...existing.documentsChantier.map((d) => d.filePath),
  ].filter((p): p is string => !!p);
  await Promise.all(filePaths.map((p) => deleteBlobFile(p)));

  await prisma.chantier.delete({ where: { reference: req.params.reference } });
  await triggerChantierDeleted(req.params.reference);
  res.status(204).send();
});

// Vérification de la veille (EX-22) : l'installateur ouvre son livret.
chantiersRouter.post('/:reference/livret-ouvert', requireAuth, requireRattachement, async (req: ChantierScopedRequest, res) => {
  const chantier = req.chantier!;

  const opened = new Set(JSON.parse(chantier.livretsOuvertsJson) as string[]);
  opened.add(req.auth!.userId);
  await prisma.chantier.update({
    where: { id: chantier.id },
    data: { livretsOuvertsJson: JSON.stringify([...opened]) },
  });
  await triggerChantierChanged(chantier.reference);
  res.status(204).send();
});

const pointUpdateSchema = z.object({
  status: z.enum(['vide', 'conforme', 'nonConforme']).optional(),
  photoPath: z.string().nullable().optional(),
  photoUrl: z.string().optional(),
  clientValidatedAt: z.string().optional(),
});

chantiersRouter.patch('/:reference/points/:pointId', requireAuth, requireRattachement, async (req: ChantierScopedRequest, res) => {
  const parsed = pointUpdateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const point = await prisma.pointControle.findUnique({ where: { id: req.params.pointId } });
  // Le point doit appartenir au chantier indiqué dans l'URL — sans ce
  // contrôle, un installateur rattaché au chantier A pourrait modifier un
  // point du chantier B en devinant/réutilisant son id.
  if (!point || point.chantierId !== req.chantier!.id) {
    return res.status(404).json({ error: 'Point de contrôle introuvable' });
  }

  if (parsed.data.photoUrl && !isOwnBlobUrl(parsed.data.photoUrl)) {
    return res.status(400).json({ error: 'URL de fichier invalide' });
  }

  const photoPath = parsed.data.photoUrl
    ? parsed.data.photoUrl
    : parsed.data.photoPath === undefined
      ? undefined
      : parsed.data.photoPath;

  // Horodatage et attribution nominative de chaque validation/signalement,
  // liées au compte connecté (jamais au nom fourni par le client) — pris à
  // l'heure de l'action terrain (clientValidatedAt) plutôt qu'à l'heure de
  // synchronisation, qui peut survenir bien plus tard si l'installateur était hors-ligne.
  // Un retour à `vide` (annulation de validation) efface l'attribution — sans
  // ça la mention "Validé par ..." resterait affichée sur un point redevenu à faire.
  let validePar: string | null | undefined;
  let valideAt: Date | null | undefined;
  if (parsed.data.status === 'vide') {
    validePar = null;
    valideAt = null;
  } else if (parsed.data.status !== undefined) {
    const auteur = await prisma.user.findUnique({ where: { id: req.auth!.userId } });
    validePar = auteur ? `${auteur.prenom} ${auteur.nom}` : undefined;
    valideAt = parsed.data.clientValidatedAt ? new Date(parsed.data.clientValidatedAt) : new Date();
  }

  const updated = await prisma.pointControle.update({
    where: { id: point.id },
    data: {
      status: parsed.data.status ?? undefined,
      photoPath,
      validePar,
      valideAt,
    },
  });

  // Prévention : le back-office (CT/Admin) doit être alerté dès que
  // l'auto-contrôle d'un chantier atteint 80%, pour pouvoir intervenir avant
  // la fin du chantier plutôt que de découvrir les anomalies au moment du PV.
  // Une seule notification par chantier (pas de spam à chaque point coché
  // au-delà du seuil). Toute cette vérification est secondaire à la mise à
  // jour du point elle-même : un échec ici (ex. chantier supprimé entre-temps
  // par un autre utilisateur, contrainte de clé étrangère) ne doit jamais
  // faire échouer la réponse au point qui vient d'être validé.
  if (point.type === 'autoControle') {
    try {
      const autoControlePoints = await prisma.pointControle.findMany({
        where: { chantierId: req.chantier!.id, type: 'autoControle' },
      });
      const progression = autoControlePoints.length === 0
        ? 0
        : autoControlePoints.filter(isPointComplete).length / autoControlePoints.length;

      if (progression >= 0.8) {
        const existingNotif = await prisma.notification.findFirst({
          where: { chantierId: req.chantier!.id, type: 'autoControle80' },
        });
        if (!existingNotif) {
          const notification = await prisma.notification.create({
            data: {
              chantierId: req.chantier!.id,
              type: 'autoControle80',
              message: `Auto-contrôle à ${Math.round(progression * 100)}% pour ${req.chantier!.reference} — à vérifier avant réception.`,
            },
          });
          await triggerNotificationCreated({
            id: notification.id,
            type: notification.type,
            message: notification.message,
            lue: notification.lue,
            createdAt: notification.createdAt,
            chantierReference: req.chantier!.reference,
          });
        }
      }
    } catch (err) {
      console.error('Échec de la vérification de notification à 80%', err);
    }
  }

  try {
    await triggerChantierChanged(req.chantier!.reference);
  } catch (err) {
    console.error('Échec de la diffusion temps réel', err);
  }
  res.json({ point: updated });
});

// Un REX peut être une note vocale seule (audio sans texte) ou un texte
// saisi directement — l'un des deux suffit, mais au moins un est obligatoire.
const rexSchema = z
  .object({
    transcription: z.string().min(1).optional(),
    audioUrl: z.string().optional(),
  })
  .refine((d) => d.transcription || d.audioUrl, { message: 'Une transcription ou une note vocale est requise' });

// Plusieurs REX possibles par chantier : chaque soumission crée une nouvelle
// entrée (table Rex) au lieu de bloquer tant que le CT/Admin n'a pas supprimé
// la précédente — un installateur peut ainsi compléter son retour s'il a
// oublié quelque chose. La note vocale est déposée directement par l'app sur
// Vercel Blob (voir routes/uploads.ts, kind "rexAudio").
chantiersRouter.post('/:reference/rex', requireAuth, requireRattachement, async (req: ChantierScopedRequest, res) => {
  const parsed = rexSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  if (parsed.data.audioUrl && !isOwnBlobUrl(parsed.data.audioUrl)) {
    return res.status(400).json({ error: 'URL de fichier invalide' });
  }

  // Le REX est créé tout de suite, avant la transcription automatique — si
  // cette dernière traîne au point de dépasser le temps d'exécution alloué à
  // la fonction serverless (Whisper peut être lent), le REX (texte et/ou
  // audio) est déjà enregistré plutôt que perdu avec toute la requête.
  const rex = await prisma.rex.create({
    data: {
      chantierId: req.chantier!.id,
      transcription: parsed.data.transcription,
      audioPath: parsed.data.audioUrl,
    },
  });
  console.log(`POST /rex: REX ${rex.id} créé pour ${req.params.reference} — audioUrl=${parsed.data.audioUrl ?? 'aucun'} transcriptionClient=${parsed.data.transcription ? 'oui' : 'non'}`);

  // Si l'installateur n'a pas dicté (ou corrigé) de texte côté app —
  // reconnaissance vocale en direct indisponible ou silencieuse —, on tente
  // une transcription automatique côté serveur sur l'audio déjà déposé, et on
  // met à jour l'entrée déjà créée. Ne bloque jamais la création du REX (voir
  // transcribeAudio) : un échec ou un dépassement de délai laisse
  // simplement le REX sans transcription, comme avant l'ajout de Whisper.
  if (!parsed.data.transcription && parsed.data.audioUrl) {
    const transcription = await transcribeAudio(parsed.data.audioUrl);
    if (transcription) {
      await prisma.rex.update({ where: { id: rex.id }, data: { transcription } });
      console.log(`POST /rex: REX ${rex.id} mis à jour avec la transcription Whisper`);
    } else {
      console.log(`POST /rex: REX ${rex.id} reste sans transcription (voir logs transcribeAudio ci-dessus)`);
    }
  }

  const chantier = await prisma.chantier.findUnique({
    where: { reference: req.params.reference },
    include: CHANTIER_INCLUDE,
  });
  await triggerChantierChanged(chantier!.reference);
  res.json({ chantier: serializeChantier(chantier!) });
});

// Supprime une entrée REX précise — réservé au CT/Admin. Suppression
// immédiate et définitive, y compris de la note vocale sur Vercel Blob si
// elle existe. Les autres entrées REX du chantier ne sont pas affectées.
chantiersRouter.delete('/:reference/rex/:rexId', requireAuth, requireRole('coordinateurTravaux', 'admin'), async (req, res) => {
  const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
  if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

  const rex = await prisma.rex.findUnique({ where: { id: req.params.rexId } });
  if (!rex || rex.chantierId !== chantier.id) return res.status(404).json({ error: 'REX introuvable' });

  if (rex.audioPath) await deleteBlobFile(rex.audioPath);
  await prisma.rex.delete({ where: { id: rex.id } });

  const updated = await prisma.chantier.findUnique({ where: { id: chantier.id }, include: CHANTIER_INCLUDE });
  await triggerChantierChanged(updated!.reference);
  res.json({ chantier: serializeChantier(updated!) });
});

const pvDocumentSchema = z.object({ fileUrl: z.string().min(1, 'Un fichier PDF est requis') });

// Dépôt (ou remplacement) du gabarit PV par le back-office — ne valide RIEN :
// le PV reste "en attente de signature" tant que l'installateur n'a pas fait
// signer le client (voir POST .../pv/signature ci-dessous). Remplacer le
// gabarit invalide une signature déjà apposée sur l'ancienne version. Le
// fichier est déposé directement par le back-office sur Vercel Blob (voir
// routes/uploads.ts, kind "pvDocument", qui restreint déjà le type au PDF).
chantiersRouter.post(
  '/:reference/pv/document',
  requireAuth,
  requireRole('coordinateurTravaux', 'direction', 'admin'),
  async (req, res) => {
    const parsed = pvDocumentSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    if (!isOwnBlobUrl(parsed.data.fileUrl)) return res.status(400).json({ error: 'URL de fichier invalide' });

    const existing = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
    if (!existing) return res.status(404).json({ error: 'Chantier introuvable' });

    if (existing.pvPdfPath) await deleteBlobFile(existing.pvPdfPath);
    if (existing.pvSignatureImagePath) await deleteBlobFile(existing.pvSignatureImagePath);
    const pvPdfPath = parsed.data.fileUrl;

    const chantier = await prisma.chantier.update({
      where: { reference: req.params.reference },
      data: {
        pvPdfPath,
        // Un chantier qui revient sur l'ancien flux (dépôt de gabarit) ne
        // doit pas garder les réponses d'un formulaire interactif abandonné
        // — même remise à zéro que DELETE .../pv, qui distingue les deux
        // flux exactement sur ce champ (voir schema.prisma).
        pvReponses: null,
        pvSigne: false,
        pvSigneur: null,
        pvFonctionSignataire: null,
        pvSigneAt: null,
        pvSignatureImagePath: null,
      },
      include: CHANTIER_INCLUDE,
    });
    await triggerChantierChanged(chantier.reference);
    res.json({ chantier: serializeChantier(chantier) });
  },
);

const pvSignatureSchema = z.object({
  nomSignataire: z.string().min(1),
  fonctionSignataire: z.string().min(1),
  signatureImage: z.string().min(1, 'L\'image de la signature est requise'),
  // Emplacement du tracé sur le PDF gabarit, calculé par l'app à partir de
  // la position réelle du dessin sur le document affiché (le client signe
  // directement sur sa case, il n'y a plus de coordonnées fixes) — voir
  // SignaturePlacement dans pvMerge.ts.
  pageNumber: z.number().int().min(1),
  x: z.number(),
  y: z.number(),
  width: z.number().positive(),
  height: z.number().positive(),
});

function isPngDataUrl(dataUrl: string): boolean {
  return dataUrl.startsWith('data:image/png;base64,');
}

// Signature du PV par le client, soumise par l'installateur — SEULE façon de
// faire passer pvSigne à true. L'app envoie l'image PNG du tracé de
// signature et son emplacement sur le document (pas un PDF déjà fusionné) :
// c'est le backend qui la superpose sur le PDF gabarit original via pdf-lib
// (voir pvMerge.ts), en préservant intégralement son texte et ses vecteurs —
// le gabarit n'est jamais rasterisé.
//
// Un PV déjà signé ne peut plus être re-signé : c'est un verrou volontaire
// (voir lib/screens/client/signature_screen.dart côté app), la seule façon
// de recommencer est que le CT/Admin supprime le PV (DELETE .../pv
// ci-dessous, qui repasse pvSigne à false).
chantiersRouter.post(
  '/:reference/pv/signature',
  requireAuth,
  requireRole('installateur'),
  requireRattachement,
  async (req, res) => {
    const parsed = pvSignatureSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    if (!isPngDataUrl(parsed.data.signatureImage)) {
      return res.status(400).json({ error: 'La signature doit être une image PNG' });
    }

    const existing = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
    if (!existing) return res.status(404).json({ error: 'Chantier introuvable' });
    if (!existing.pvPdfPath) {
      return res.status(400).json({ error: 'Aucun PV à signer pour ce chantier — en attente du back-office' });
    }
    if (existing.pvSigne) {
      return res.status(400).json({ error: 'Ce PV est déjà signé — seul le CT/Admin peut le réinitialiser en le supprimant' });
    }

    let pdfSigneBytes: Buffer;
    try {
      const gabaritBytes = await fetchBlobFile(existing.pvPdfPath);
      const signatureBytes = Buffer.from(parsed.data.signatureImage.split(',')[1] ?? '', 'base64');
      pdfSigneBytes = await fusionnerSignatureDansPdf(gabaritBytes, signatureBytes, {
        pageNumber: parsed.data.pageNumber,
        x: parsed.data.x,
        y: parsed.data.y,
        width: parsed.data.width,
        height: parsed.data.height,
      });
    } catch (err) {
      console.error('Fusion de la signature sur le PV échouée:', err);
      return res.status(502).json({ error: 'Impossible de fusionner la signature sur le PV, réessayez.' });
    }

    if (existing.pvSignatureImagePath) await deleteBlobFile(existing.pvSignatureImagePath);
    const pvSignatureImagePath = await saveBuffer(pdfSigneBytes, `pv-signe-${existing.id}`, 'application/pdf');

    const chantier = await prisma.chantier.update({
      where: { reference: req.params.reference },
      data: {
        pvSigne: true,
        pvSigneur: parsed.data.nomSignataire,
        pvFonctionSignataire: parsed.data.fonctionSignataire,
        pvSigneAt: new Date(),
        pvSignatureImagePath,
      },
      include: CHANTIER_INCLUDE,
    });
    await triggerChantierChanged(chantier.reference);
    res.json({ chantier: serializeChantier(chantier) });
  },
);

// reponse n'est PAS nullable ici : au moment de la validation finale du PV
// (contrairement à une simple sauvegarde de brouillon, qui n'existe pas dans
// ce flux — voir POST .../pv/reponses), chaque question de la checklist doit
// avoir été tranchée. Un point non applicable au chantier se répond "Non"
// avec observation, comme sur le PV papier — voir aussi le garde-fou de
// couverture ci-dessous, qui vérifie que chaque id du gabarit officiel a bien
// une réponse (et pas seulement que celles présentes sont non nulles).
const pvChecklistReponseSchema = z.object({
  id: z.string().min(1),
  reponse: z.enum(['oui', 'non']),
  observation: z.string().optional().nullable(),
});

function checklistCouvreTousLesItems(reponses: { id: string }[], defs: PvChecklistItemDef[]): boolean {
  const ids = new Set(reponses.map((r) => r.id));
  return defs.every((d) => ids.has(d.id));
}

const pvReponsesSchema = z
  .object({
    identite: z.object({
      maitreOeuvre: z.string().optional().nullable(),
      operation: z.string().optional().nullable(),
      lot: z.string().optional().nullable(),
    }),
    receptionInstallation: z.array(pvChecklistReponseSchema),
    documentsRemis: z.array(pvChecklistReponseSchema),
    servicesSupplementaires: z.array(pvChecklistReponseSchema),
    natureDePose: z.array(z.string()),
    quantite: z.string().optional().nullable(),
    reserves: z.string().optional().nullable(),
    remarques: z.string().optional().nullable(),
    temoignageClient: z.string().optional().nullable(),
  })
  .refine((d) => checklistCouvreTousLesItems(d.receptionInstallation, PV_SECTION_1), {
    message: 'Toutes les questions de la section "réception de l\'installation" doivent être renseignées',
    path: ['receptionInstallation'],
  })
  .refine((d) => checklistCouvreTousLesItems(d.documentsRemis, PV_SECTION_2), {
    message: 'Toutes les questions de la section "documents remis" doivent être renseignées',
    path: ['documentsRemis'],
  })
  .refine((d) => checklistCouvreTousLesItems(d.servicesSupplementaires, PV_SECTION_3), {
    message: 'Toutes les questions de la section "services supplémentaires" doivent être renseignées',
    path: ['servicesSupplementaires'],
  }) satisfies z.ZodType<PvFormReponses>;

const pvFormulaireSchema = z.object({
  reponses: pvReponsesSchema,
  dateReception: z.string().min(1),
  nomSignataire: z.string().min(1),
  fonctionSignataire: z.string().min(1),
  signatureImage: z.string().min(1, "L'image de la signature est requise"),
});

// Nouveau flux (formulaire PV interactif, voir pvFormPdf.ts) : contrairement
// à .../pv/signature (qui superpose la signature sur un gabarit PDF déjà
// déposé), ici il n'y a pas de gabarit — le backend génère le PDF final de
// toutes pièces à partir des réponses du formulaire + la signature. Réservé
// aux chantiers qui n'utilisent PAS l'ancien flux (pvPdfPath == null) ; même
// verrou qu'ailleurs, un PV déjà signé ne se re-signe pas.
chantiersRouter.post(
  '/:reference/pv/reponses',
  requireAuth,
  requireRole('installateur'),
  requireRattachement,
  async (req, res) => {
    const parsed = pvFormulaireSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    if (!isPngDataUrl(parsed.data.signatureImage)) {
      return res.status(400).json({ error: 'La signature doit être une image PNG' });
    }
    const dateReception = new Date(parsed.data.dateReception);
    if (Number.isNaN(dateReception.getTime())) {
      return res.status(400).json({ error: 'Date de réception invalide' });
    }

    const existing = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
    if (!existing) return res.status(404).json({ error: 'Chantier introuvable' });
    if (existing.pvPdfPath) {
      return res.status(400).json({ error: 'Ce chantier utilise le dépôt de gabarit PDF — voir la signature classique du PV' });
    }
    if (existing.pvSigne) {
      return res.status(400).json({ error: 'Ce PV est déjà signé — seul le CT/Admin peut le réinitialiser en le supprimant' });
    }

    let pdfBytes: Buffer;
    try {
      const signatureBytes = Buffer.from(parsed.data.signatureImage.split(',')[1] ?? '', 'base64');
      pdfBytes = await genererPdfPvFormulaire({
        chantier: {
          reference: existing.reference,
          client: existing.client,
          adresse: existing.adresse,
          referenceAffaire: existing.referenceAffaire,
          contactNom: existing.contactNom,
        },
        reponses: parsed.data.reponses,
        dateReception,
        nomSignataire: parsed.data.nomSignataire,
        fonctionSignataire: parsed.data.fonctionSignataire,
        signaturePngBytes: signatureBytes,
      });
    } catch (err) {
      console.error('Génération du PDF du PV interactif échouée:', err);
      return res.status(502).json({ error: 'Impossible de générer le PDF du PV, réessayez.' });
    }

    if (existing.pvSignatureImagePath) await deleteBlobFile(existing.pvSignatureImagePath);
    const pvSignatureImagePath = await saveBuffer(pdfBytes, `pv-signe-${existing.id}`, 'application/pdf');

    const chantier = await prisma.chantier.update({
      where: { reference: req.params.reference },
      data: {
        pvReponses: JSON.stringify(parsed.data.reponses),
        pvSigne: true,
        pvSigneur: parsed.data.nomSignataire,
        pvFonctionSignataire: parsed.data.fonctionSignataire,
        pvSigneAt: new Date(),
        pvSignatureImagePath,
      },
      include: CHANTIER_INCLUDE,
    });
    await triggerChantierChanged(chantier.reference);
    res.json({ chantier: serializeChantier(chantier) });
  },
);

// Supprime définitivement le PV d'un chantier (gabarit ET signature
// éventuelle, quel que soit le flux utilisé) — réservé au CT/Admin, comme
// pour le REX. Contrairement à un remplacement du gabarit (POST
// .../pv/document, qui invalide juste la signature), la suppression efface
// tout, y compris les fichiers sur Vercel Blob.
chantiersRouter.delete('/:reference/pv', requireAuth, requireRole('coordinateurTravaux', 'admin'), async (req, res) => {
  const existing = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
  if (!existing) return res.status(404).json({ error: 'Chantier introuvable' });
  if (!existing.pvPdfPath && !existing.pvSigne) {
    return res.status(404).json({ error: 'Aucun PV à supprimer pour ce chantier' });
  }

  if (existing.pvPdfPath) await deleteBlobFile(existing.pvPdfPath);
  if (existing.pvSignatureImagePath) await deleteBlobFile(existing.pvSignatureImagePath);

  const chantier = await prisma.chantier.update({
    where: { reference: req.params.reference },
    data: {
      pvPdfPath: null,
      pvReponses: null,
      pvSigne: false,
      pvSigneur: null,
      pvFonctionSignataire: null,
      pvSigneAt: null,
      pvSignatureImagePath: null,
    },
    include: CHANTIER_INCLUDE,
  });
  await triggerChantierChanged(chantier.reference);
  res.json({ chantier: serializeChantier(chantier) });
});

const documentCategories = ['bonLivraison', 'documentClient', 'habilitation', 'constat', 'autre'] as const;
const documentSchema = z.object({
  titre: z.string().min(1),
  categorie: z.enum(documentCategories),
  fileUrl: z.string().min(1, 'Un fichier (photo, vidéo ou PDF) est requis'),
});

// Le fichier (photo, vidéo ou PDF) est déposé directement par l'app sur
// Vercel Blob (voir routes/uploads.ts, kind "documentTerrain").
chantiersRouter.post('/:reference/documents', requireAuth, requireRattachement, async (req: ChantierScopedRequest, res) => {
  const parsed = documentSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  if (!isOwnBlobUrl(parsed.data.fileUrl)) {
    return res.status(400).json({ error: 'URL de fichier invalide' });
  }

  const chantier = req.chantier!;
  const filePath = parsed.data.fileUrl;

  const doc = await prisma.documentTerrain.create({
    data: {
      chantierId: chantier.id,
      titre: parsed.data.titre,
      categorie: parsed.data.categorie,
      filePath,
      auteurId: req.auth!.userId,
    },
    include: { auteur: true },
  });
  await triggerChantierChanged(chantier.reference);
  res.status(201).json({ document: doc });
});

// Suppression d'un document terrain (Module 8) — réservée à son auteur
// (l'installateur qui l'a déposé) ou à un CT/Admin, jamais à un autre
// installateur même rattaché au même chantier. Suppression immédiate et
// définitive, y compris le fichier stocké sur Vercel Blob.
chantiersRouter.delete('/:reference/documents/:docId', requireAuth, requireRattachement, async (req: ChantierScopedRequest, res) => {
  const doc = await prisma.documentTerrain.findUnique({ where: { id: req.params.docId } });
  if (!doc || doc.chantierId !== req.chantier!.id) {
    return res.status(404).json({ error: 'Document introuvable' });
  }

  const estAuteur = doc.auteurId === req.auth!.userId;
  const estCtOuAdmin = req.auth!.role === 'coordinateurTravaux' || req.auth!.role === 'admin';
  if (!estAuteur && !estCtOuAdmin) {
    return res.status(403).json({ error: 'Seul l\'auteur du document ou un CT/Admin peut le supprimer' });
  }

  if (doc.filePath) await deleteBlobFile(doc.filePath);
  await prisma.documentTerrain.delete({ where: { id: doc.id } });

  const chantier = await prisma.chantier.findUnique({ where: { id: req.chantier!.id }, include: CHANTIER_INCLUDE });
  await triggerChantierChanged(chantier!.reference);
  res.json({ chantier: serializeChantier(chantier!) });
});

const documentChantierSchema = z.object({
  type: z.enum(['ficheChantier', 'securite', 'technique']),
  // Optionnel : nommer le document lors de l'import ralentissait l'ajout de
  // plusieurs fichiers sans réel bénéfice — à défaut, le nom du fichier
  // d'origine (nomFichierOriginal) fait l'affaire.
  nom: z.string().min(1).optional(),
  nomFichierOriginal: z.string().min(1).optional(),
  fileUrl: z.string().min(1, 'Un fichier (photo, vidéo ou PDF) est requis'),
});

// Documents de référence (PPSPS, plans, notices...) déposés par le CT depuis
// le back-office — consultés en lecture seule par l'installateur sur mobile
// (Modules 1-3), via le même mécanisme de cache hors-ligne que le reste du
// chantier. Le fichier est déposé directement par le back-office sur Vercel
// Blob (voir routes/uploads.ts, kind "documentChantier").
chantiersRouter.post(
  '/:reference/documents-chantier',
  requireAuth,
  requireRole('coordinateurTravaux', 'direction', 'admin'),
  async (req, res) => {
    const parsed = documentChantierSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    if (!isOwnBlobUrl(parsed.data.fileUrl)) {
      return res.status(400).json({ error: 'URL de fichier invalide' });
    }

    const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
    if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

    await prisma.documentChantier.create({
      data: {
        chantierId: chantier.id,
        type: parsed.data.type,
        nom: parsed.data.nom || parsed.data.nomFichierOriginal || 'Document',
        nomFichierOriginal: parsed.data.nomFichierOriginal,
        filePath: parsed.data.fileUrl,
      },
    });

    const updated = await prisma.chantier.findUnique({ where: { id: chantier.id }, include: CHANTIER_INCLUDE });
    await triggerChantierChanged(updated!.reference);
    res.status(201).json({ chantier: serializeChantier(updated!) });
  },
);

// Supprime un document chantier — en base ET sur Vercel Blob (sans ça, le
// fichier reste stocké et facturé indéfiniment sans qu'aucune UI n'y renvoie).
chantiersRouter.delete(
  '/:reference/documents-chantier/:docId',
  requireAuth,
  requireRole('coordinateurTravaux', 'direction', 'admin'),
  async (req, res) => {
    const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
    if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

    const doc = await prisma.documentChantier.findUnique({ where: { id: req.params.docId } });
    if (!doc || doc.chantierId !== chantier.id) return res.status(404).json({ error: 'Document introuvable' });

    await deleteBlobFile(doc.filePath);
    await prisma.documentChantier.delete({ where: { id: doc.id } });

    const updated = await prisma.chantier.findUnique({ where: { id: chantier.id }, include: CHANTIER_INCLUDE });
    await triggerChantierChanged(updated!.reference);
    res.json({ chantier: serializeChantier(updated!) });
  },
);

const replaceDocumentChantierSchema = z.object({
  fileUrl: z.string().min(1, 'Un fichier (photo, vidéo ou PDF) est requis'),
  nomFichierOriginal: z.string().min(1).optional(),
});

// Remplace le fichier d'un document chantier existant (même titre/catégorie,
// nouveau contenu) — l'ancien fichier est supprimé de Vercel Blob pour ne pas
// laisser de version périmée stockée en double.
chantiersRouter.put(
  '/:reference/documents-chantier/:docId',
  requireAuth,
  requireRole('coordinateurTravaux', 'direction', 'admin'),
  async (req, res) => {
    const parsed = replaceDocumentChantierSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    if (!isOwnBlobUrl(parsed.data.fileUrl)) {
      return res.status(400).json({ error: 'URL de fichier invalide' });
    }

    const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
    if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

    const doc = await prisma.documentChantier.findUnique({ where: { id: req.params.docId } });
    if (!doc || doc.chantierId !== chantier.id) return res.status(404).json({ error: 'Document introuvable' });

    const newFilePath = parsed.data.fileUrl;
    await deleteBlobFile(doc.filePath);

    await prisma.documentChantier.update({
      where: { id: doc.id },
      data: { filePath: newFilePath, nomFichierOriginal: parsed.data.nomFichierOriginal ?? doc.nomFichierOriginal },
    });

    const updated = await prisma.chantier.findUnique({ where: { id: chantier.id }, include: CHANTIER_INCLUDE });
    await triggerChantierChanged(updated!.reference);
    res.json({ chantier: serializeChantier(updated!) });
  },
);
