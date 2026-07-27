import { Router, Response, NextFunction } from 'express';
import { Chantier } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../prisma';
import { serializeChantier } from '../serializers';
import { requireAuth, requireRole, AuthedRequest } from '../middleware/auth';
import { saveBase64File } from '../lib/imageStorage';
import { RECEPTION_POINTS, AUTO_CONTROLE_POINTS } from '../lib/checklistDefaults';

export const chantiersRouter = Router();

const CHANTIER_INCLUDE = {
  pointsControle: { orderBy: { ordre: 'asc' as const } },
  installateurs: { include: { user: true } },
  documentsTerrain: { include: { auteur: true } },
  documentsChantier: { orderBy: { createdAt: 'asc' as const } },
};

interface ChantierScopedRequest extends AuthedRequest {
  chantier?: Chantier;
}

/// Un installateur ne peut agir que sur un chantier auquel il est rattaché
/// (table ChantierInstallateur) — sans ce garde, n'importe quel installateur
/// authentifié pouvait modifier les points, signer le PV ou déposer un
/// document sur n'importe quel chantier en connaissant sa seule référence.
/// Les rôles internes (CA, Qualité, Direction, Admin) ne sont pas concernés
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
  horaires: z.string().min(1),
  consignes: z.array(z.string()).default([]),
  typeMonteCharge: z.string().min(1),
  capacite: z.string().min(1),
  niveaux: z.number().int().positive(),
  referenceAffaire: z.string().min(1),
});

chantiersRouter.post('/', requireAuth, requireRole('chargeAffaires', 'direction', 'admin'), async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const d = parsed.data;

  const existing = await prisma.chantier.findUnique({ where: { reference: d.reference } });
  if (existing) return res.status(409).json({ error: 'Cette référence existe déjà' });

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
      horaires: d.horaires,
      consignes: JSON.stringify(d.consignes),
      typeMonteCharge: d.typeMonteCharge,
      capacite: d.capacite,
      niveaux: d.niveaux,
      referenceAffaire: d.referenceAffaire,
      pointsControle: {
        create: [...RECEPTION_POINTS, ...AUTO_CONTROLE_POINTS],
      },
    },
    include: CHANTIER_INCLUDE,
  });

  res.status(201).json({ chantier: serializeChantier(chantier) });
});

chantiersRouter.get('/:reference', requireAuth, async (req, res) => {
  const chantier = await prisma.chantier.findUnique({
    where: { reference: req.params.reference },
    include: CHANTIER_INCLUDE,
  });
  if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });
  res.json({ chantier: serializeChantier(chantier) });
});

chantiersRouter.post('/:reference/rattacher', requireAuth, requireRole('chargeAffaires', 'direction', 'admin'), async (req, res) => {
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
  res.json({ chantier: serializeChantier(updated!) });
});

// Détache un installateur d'un chantier (retire le rattachement) — CA/Direction/Admin.
chantiersRouter.delete(
  '/:reference/rattacher/:userId',
  requireAuth,
  requireRole('chargeAffaires', 'direction', 'admin'),
  async (req, res) => {
    const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
    if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

    await prisma.chantierInstallateur.deleteMany({
      where: { chantierId: chantier.id, userId: req.params.userId },
    });

    const updated = await prisma.chantier.findUnique({ where: { id: chantier.id }, include: CHANTIER_INCLUDE });
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
  horaires: z.string().min(1).optional(),
  consignes: z.array(z.string()).optional(),
  typeMonteCharge: z.string().min(1).optional(),
  capacite: z.string().min(1).optional(),
  niveaux: z.number().int().positive().optional(),
  referenceAffaire: z.string().min(1).optional(),
});

// Modification des informations d'un chantier — réservé à l'Admin (le CA n'a
// pas ce droit, voir la refonte des rôles back-office : seul l'Admin peut
// corriger/supprimer un chantier une fois créé).
chantiersRouter.patch('/:reference', requireAuth, requireRole('admin'), async (req, res) => {
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
      horaires: d.horaires,
      consignes: d.consignes ? JSON.stringify(d.consignes) : undefined,
      typeMonteCharge: d.typeMonteCharge,
      capacite: d.capacite,
      niveaux: d.niveaux,
      referenceAffaire: d.referenceAffaire,
    },
    include: CHANTIER_INCLUDE,
  });
  res.json({ chantier: serializeChantier(chantier) });
});

// Suppression d'un chantier — réservé à l'Admin. Les points de contrôle,
// rattachements, documents terrain et documents chantier sont supprimés en
// cascade (voir onDelete: Cascade sur ces relations dans schema.prisma).
chantiersRouter.delete('/:reference', requireAuth, requireRole('admin'), async (req, res) => {
  const existing = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
  if (!existing) return res.status(404).json({ error: 'Chantier introuvable' });

  await prisma.chantier.delete({ where: { reference: req.params.reference } });
  res.status(204).send();
});

// Vérification de la veille (EX-22) : l'installateur ouvre son livret.
chantiersRouter.post('/:reference/livret-ouvert', requireAuth, async (req: AuthedRequest, res) => {
  const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
  if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

  const opened = new Set(JSON.parse(chantier.livretsOuvertsJson) as string[]);
  opened.add(req.auth!.userId);
  await prisma.chantier.update({
    where: { id: chantier.id },
    data: { livretsOuvertsJson: JSON.stringify([...opened]) },
  });
  res.status(204).send();
});

const pointUpdateSchema = z.object({
  status: z.enum(['vide', 'conforme', 'nonConforme']).optional(),
  photoPath: z.string().nullable().optional(),
  photo: z.string().optional(),
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

  const photoPath = parsed.data.photo
    ? await saveBase64File(parsed.data.photo, `point-${point.id}`)
    : parsed.data.photoPath === undefined
      ? undefined
      : parsed.data.photoPath;

  // Horodatage et attribution nominative de chaque validation/signalement,
  // liées au compte connecté (jamais au nom fourni par le client) — pris à
  // l'heure de l'action terrain (clientValidatedAt) plutôt qu'à l'heure de
  // synchronisation, qui peut survenir bien plus tard si l'installateur était hors-ligne.
  let validePar: string | undefined;
  let valideAt: Date | undefined;
  if (parsed.data.status !== undefined) {
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
  res.json({ point: updated });
});

// La transcription automatique (Whisper) n'est pas requise pour la V1 : un
// REX peut être une note vocale seule (audio sans texte) ou un texte saisi
// directement — l'un des deux suffit, mais au moins un est obligatoire.
const rexSchema = z
  .object({
    transcription: z.string().min(1).optional(),
    audio: z.string().optional(),
  })
  .refine((d) => d.transcription || d.audio, { message: 'Une transcription ou une note vocale est requise' });

chantiersRouter.post('/:reference/rex', requireAuth, requireRattachement, async (req, res) => {
  const parsed = rexSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  let rexAudioPath: string | undefined;
  if (parsed.data.audio) {
    rexAudioPath = await saveBase64File(parsed.data.audio, `rex-${req.params.reference}`);
  }

  const chantier = await prisma.chantier.update({
    where: { reference: req.params.reference },
    data: {
      rexValide: true,
      rexTranscription: parsed.data.transcription,
      rexAudioPath,
      rexSoumisAt: new Date(),
    },
    include: CHANTIER_INCLUDE,
  });
  res.json({ chantier: serializeChantier(chantier) });
});

const pvSchema = z.object({ signataire: z.string().min(1), signatureImage: z.string().optional() });

chantiersRouter.post('/:reference/pv', requireAuth, requireRattachement, async (req, res) => {
  const parsed = pvSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const existing = await prisma.chantier.findUnique({
    where: { reference: req.params.reference },
    include: { pointsControle: true },
  });
  if (!existing) return res.status(404).json({ error: 'Chantier introuvable' });
  if (existing.pvSigne) return res.status(409).json({ error: 'Le PV a déjà été signé pour ce chantier' });

  const autoControle = existing.pointsControle.filter((p) => p.type === 'autoControle');
  const isComplete = (p: (typeof autoControle)[number]) => p.status !== 'vide' && (!p.photoRequise || p.photoPath != null);
  const complete = autoControle.length > 0 && autoControle.every(isComplete);
  if (!complete) {
    return res.status(400).json({ error: "L'auto-contrôle doit être complet avant de signer le PV" });
  }

  let pvSignatureImagePath: string | undefined;
  if (parsed.data.signatureImage) {
    pvSignatureImagePath = await saveBase64File(parsed.data.signatureImage, `signature-${existing.id}`);
  }

  const chantier = await prisma.chantier.update({
    where: { reference: req.params.reference },
    data: {
      pvSigne: true,
      pvSigneur: parsed.data.signataire,
      pvSigneAt: new Date(),
      pvSignatureImagePath,
    },
    include: CHANTIER_INCLUDE,
  });
  res.json({ chantier: serializeChantier(chantier) });
});

const documentCategories = ['bonLivraison', 'documentClient', 'habilitation', 'constat', 'autre'] as const;
const documentSchema = z.object({
  titre: z.string().min(1),
  categorie: z.enum(documentCategories),
  file: z.string().min(1, 'Un fichier (photo ou PDF) est requis'),
});

chantiersRouter.post('/:reference/documents', requireAuth, requireRattachement, async (req: ChantierScopedRequest, res) => {
  const parsed = documentSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const chantier = req.chantier!;
  const filePath = await saveBase64File(parsed.data.file, `doc-${chantier.id}`);

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
  res.status(201).json({ document: doc });
});

const documentChantierSchema = z.object({
  type: z.enum(['securite', 'technique']),
  nom: z.string().min(1),
  file: z.string().min(1, 'Un fichier (photo ou PDF) est requis'),
});

// Documents de référence (PPSPS, plans, notices...) déposés par le CA depuis
// le back-office — consultés en lecture seule par l'installateur sur mobile
// (Modules 1-3), via le même mécanisme de cache hors-ligne que le reste du chantier.
chantiersRouter.post(
  '/:reference/documents-chantier',
  requireAuth,
  requireRole('chargeAffaires', 'direction', 'admin'),
  async (req, res) => {
    const parsed = documentChantierSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

    const chantier = await prisma.chantier.findUnique({ where: { reference: req.params.reference } });
    if (!chantier) return res.status(404).json({ error: 'Chantier introuvable' });

    const filePath = await saveBase64File(parsed.data.file, `doc-chantier-${chantier.id}`);

    await prisma.documentChantier.create({
      data: { chantierId: chantier.id, type: parsed.data.type, nom: parsed.data.nom, filePath },
    });

    const updated = await prisma.chantier.findUnique({ where: { id: chantier.id }, include: CHANTIER_INCLUDE });
    res.status(201).json({ chantier: serializeChantier(updated!) });
  },
);
