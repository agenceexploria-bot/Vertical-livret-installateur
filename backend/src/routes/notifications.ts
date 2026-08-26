import { Router } from 'express';
import { prisma } from '../prisma';
import { requireAuth, requireRole } from '../middleware/auth';

export const notificationsRouter = Router();

notificationsRouter.get('/', requireAuth, requireRole('coordinateurTravaux', 'admin'), async (_req, res) => {
  const notifications = await prisma.notification.findMany({
    include: { chantier: true },
    orderBy: { createdAt: 'desc' },
  });
  res.json({
    notifications: notifications.map((n) => ({
      id: n.id,
      type: n.type,
      message: n.message,
      lue: n.lue,
      createdAt: n.createdAt,
      chantierReference: n.chantier.reference,
    })),
  });
});

notificationsRouter.patch('/:id/lue', requireAuth, requireRole('coordinateurTravaux', 'admin'), async (req, res) => {
  const existing = await prisma.notification.findUnique({ where: { id: req.params.id } });
  if (!existing) return res.status(404).json({ error: 'Notification introuvable' });

  const notification = await prisma.notification.update({ where: { id: req.params.id }, data: { lue: true } });
  res.json({ notification });
});
