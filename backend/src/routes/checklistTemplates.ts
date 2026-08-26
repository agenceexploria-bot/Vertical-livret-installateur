import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { requireAuth, requireRole } from '../middleware/auth';

export const checklistTemplatesRouter = Router();

// Listes de réception/contrôle appliquées à la création d'un nouveau chantier
// (voir POST /chantiers) — gérées ici par l'Admin (renommer, ajouter,
// supprimer des items). Modifier ces listes n'a aucun effet rétroactif sur
// les chantiers déjà créés, dont les PointControle sont des lignes indépendantes.
checklistTemplatesRouter.get('/', requireAuth, requireRole('admin'), async (_req, res) => {
  const items = await prisma.checklistTemplateItem.findMany({ orderBy: [{ type: 'asc' }, { ordre: 'asc' }] });
  res.json({ items });
});

const createSchema = z.object({
  type: z.enum(['reception', 'autoControle']),
  categorie: z.string().min(1),
  libelle: z.string().min(1),
  critique: z.boolean().default(false),
});

checklistTemplatesRouter.post('/', requireAuth, requireRole('admin'), async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  // Ajouté à la suite des items existants du même type, pour ne pas
  // perturber l'ordre déjà en place.
  const last = await prisma.checklistTemplateItem.findFirst({
    where: { type: parsed.data.type },
    orderBy: { ordre: 'desc' },
  });
  const item = await prisma.checklistTemplateItem.create({
    data: { ...parsed.data, ordre: (last?.ordre ?? -1) + 1 },
  });
  res.status(201).json({ item });
});

const updateSchema = z.object({
  categorie: z.string().min(1).optional(),
  libelle: z.string().min(1).optional(),
  critique: z.boolean().optional(),
  ordre: z.number().int().optional(),
});

checklistTemplatesRouter.patch('/:id', requireAuth, requireRole('admin'), async (req, res) => {
  const parsed = updateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const existing = await prisma.checklistTemplateItem.findUnique({ where: { id: req.params.id } });
  if (!existing) return res.status(404).json({ error: 'Item introuvable' });

  const item = await prisma.checklistTemplateItem.update({ where: { id: req.params.id }, data: parsed.data });
  res.json({ item });
});

checklistTemplatesRouter.delete('/:id', requireAuth, requireRole('admin'), async (req, res) => {
  const existing = await prisma.checklistTemplateItem.findUnique({ where: { id: req.params.id } });
  if (!existing) return res.status(404).json({ error: 'Item introuvable' });

  await prisma.checklistTemplateItem.delete({ where: { id: req.params.id } });
  res.status(204).send();
});
