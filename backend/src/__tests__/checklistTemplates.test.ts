import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb, signup as doSignup } from './helpers';

const app = createApp();

async function createAdmin() {
  const passwordHash = await bcrypt.hash('demodemo', 10);
  await prisma.user.create({
    data: {
      nom: 'Lefebvre', prenom: 'Admin', mobile: '0102030407', email: 'admin@actiwork.fr',
      passwordHash, role: 'admin', isActive: true,
    },
  });
  const login = await request(app).post('/auth/login').send({ identifier: 'admin@actiwork.fr', password: 'demodemo' });
  return login.body.accessToken as string;
}

async function createInstallateurToken() {
  const signup = await doSignup(app, {
    nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
  });
  return signup.body.accessToken as string;
}

beforeEach(async () => {
  await resetDb();
  await prisma.checklistTemplateItem.deleteMany();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe('GET /checklist-templates', () => {
  it('liste les items, réservé à l\'Admin', async () => {
    await prisma.checklistTemplateItem.create({
      data: { type: 'reception', categorie: 'Réception', libelle: 'Bon de livraison présent', ordre: 0 },
    });
    const token = await createAdmin();

    const res = await request(app).get('/checklist-templates').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0].libelle).toBe('Bon de livraison présent');
  });

  it('refuse un installateur', async () => {
    const token = await createInstallateurToken();
    const res = await request(app).get('/checklist-templates').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });
});

describe('POST /checklist-templates', () => {
  it('ajoute un item à la suite des autres du même type', async () => {
    const token = await createAdmin();
    await prisma.checklistTemplateItem.create({
      data: { type: 'autoControle', categorie: 'Mécanique', libelle: 'Existant', ordre: 0 },
    });

    const res = await request(app)
      .post('/checklist-templates')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'autoControle', categorie: 'Mécanique', libelle: 'Nouveau point', critique: true });

    expect(res.status).toBe(201);
    expect(res.body.item.ordre).toBe(1);
    expect(res.body.item.critique).toBe(true);
  });

  it('refuse un item sans libellé', async () => {
    const token = await createAdmin();
    const res = await request(app)
      .post('/checklist-templates')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'reception', categorie: 'Réception', libelle: '' });
    expect(res.status).toBe(400);
  });
});

describe('PATCH /checklist-templates/:id', () => {
  it('renomme un item existant', async () => {
    const token = await createAdmin();
    const item = await prisma.checklistTemplateItem.create({
      data: { type: 'reception', categorie: 'Réception', libelle: 'Ancien nom', ordre: 0 },
    });

    const res = await request(app)
      .patch(`/checklist-templates/${item.id}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ libelle: 'Nouveau nom' });

    expect(res.status).toBe(200);
    expect(res.body.item.libelle).toBe('Nouveau nom');
  });

  it('renvoie 404 pour un item inexistant', async () => {
    const token = await createAdmin();
    const res = await request(app)
      .patch('/checklist-templates/inexistant')
      .set('Authorization', `Bearer ${token}`)
      .send({ libelle: 'X' });
    expect(res.status).toBe(404);
  });
});

describe('DELETE /checklist-templates/:id', () => {
  it('supprime un item', async () => {
    const token = await createAdmin();
    const item = await prisma.checklistTemplateItem.create({
      data: { type: 'reception', categorie: 'Réception', libelle: 'À supprimer', ordre: 0 },
    });

    const res = await request(app).delete(`/checklist-templates/${item.id}`).set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(204);

    const list = await request(app).get('/checklist-templates').set('Authorization', `Bearer ${token}`);
    expect(list.body.items).toHaveLength(0);
  });

  it('ne modifie pas les chantiers déjà créés', async () => {
    const passwordHash = await bcrypt.hash('demodemo', 10);
    const ct = await prisma.user.create({
      data: {
        nom: 'Martin', prenom: 'Sandrine', mobile: '0102030405', email: 's.martin@actiwork.fr',
        passwordHash, role: 'coordinateurTravaux', isActive: true,
      },
    });
    const ctLogin = await request(app).post('/auth/login').send({ identifier: 's.martin@actiwork.fr', password: 'demodemo' });
    const item = await prisma.checklistTemplateItem.create({
      data: { type: 'reception', categorie: 'Réception', libelle: 'Point A', ordre: 0 },
    });

    const created = await request(app)
      .post('/chantiers')
      .set('Authorization', `Bearer ${ctLogin.body.accessToken}`)
      .send({
        reference: 'LD64397', client: 'Costockage', adresse: '4 rue des Frères Lumière', ville: 'Meyzieu',
        dateDebut: '2026-07-21T00:00:00.000Z', dateFin: '2026-07-23T00:00:00.000Z',
        contactNom: 'M. Weber', contactTel: '0612345678', horaires: '6h30-17h00', consignes: [],
        typeMonteCharge: 'Non accompagné', capacite: '300 kg', niveaux: 2, referenceAffaire: 'AF-2026-001',
      });
    expect(created.body.chantier.receptionMarchandises).toHaveLength(1);
    expect(created.body.chantier.receptionMarchandises[0].libelle).toBe('Point A');

    const admin = await createAdmin();
    await request(app).delete(`/checklist-templates/${item.id}`).set('Authorization', `Bearer ${admin}`);

    const reloaded = await request(app).get('/chantiers/LD64397').set('Authorization', `Bearer ${ctLogin.body.accessToken}`);
    expect(reloaded.body.chantier.receptionMarchandises).toHaveLength(1);
    expect(reloaded.body.chantier.receptionMarchandises[0].libelle).toBe('Point A');
  });
});
