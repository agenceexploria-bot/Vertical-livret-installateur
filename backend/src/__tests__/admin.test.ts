import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb, signup as doSignup } from './helpers';

const app = createApp();

const ONE_PX_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

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

async function createCa() {
  const passwordHash = await bcrypt.hash('demodemo', 10);
  const ca = await prisma.user.create({
    data: {
      nom: 'Martin', prenom: 'Sandrine', mobile: '0102030405', email: 's.martin@actiwork.fr',
      passwordHash, role: 'chargeAffaires', isActive: true,
    },
  });
  const login = await request(app).post('/auth/login').send({ identifier: 's.martin@actiwork.fr', password: 'demodemo' });
  return { user: ca, accessToken: login.body.accessToken as string };
}

beforeEach(async () => {
  await resetDb();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe('Validation des comptes internes par un Admin', () => {
  it('liste les comptes internes en attente et les valide', async () => {
    const adminToken = await createAdmin();
    const signup = await request(app).post('/auth/signup-interne').send({
      nom: 'Bernard', prenom: 'Julien', mobile: '0611223344', email: 'j.bernard@actiwork.fr',
      password: 'motdepasse', role: 'chargeAffaires',
    });

    const list = await request(app).get('/admin/comptes-internes').set('Authorization', `Bearer ${adminToken}`);
    expect(list.status).toBe(200);
    expect(list.body.comptesInternes).toHaveLength(1);
    expect(list.body.comptesInternes[0].isActive).toBe(false);

    const valider = await request(app)
      .post(`/admin/comptes-internes/${signup.body.user.id}/valider`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(valider.status).toBe(200);
    expect(valider.body.user.isActive).toBe(true);
  });

  it("refuse à un chargé d'affaires l'accès aux routes admin", async () => {
    const ca = await createCa();
    const res = await request(app).get('/admin/comptes-internes').set('Authorization', `Bearer ${ca.accessToken}`);
    expect(res.status).toBe(403);
  });

  it('refuse de valider un compte qui n\'est pas soumis à validation (ex. installateur)', async () => {
    const adminToken = await createAdmin();
    const signup = await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });

    const res = await request(app)
      .post(`/admin/comptes-internes/${signup.body.user.id}/valider`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(400);
  });
});

describe('Gestion globale des comptes (Admin)', () => {
  it('liste tous les comptes sauf les comptes Admin', async () => {
    const adminToken = await createAdmin();
    await createCa();
    await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });

    const res = await request(app).get('/admin/comptes').set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.comptes).toHaveLength(2);
    expect(res.body.comptes.every((u: { role: string }) => u.role !== 'admin')).toBe(true);
  });

  it("refuse à un chargé d'affaires l'accès à la gestion globale des comptes", async () => {
    const ca = await createCa();
    const res = await request(app).get('/admin/comptes').set('Authorization', `Bearer ${ca.accessToken}`);
    expect(res.status).toBe(403);
  });

  it('suspend puis réactive un compte CA', async () => {
    const adminToken = await createAdmin();
    const ca = await createCa();

    const suspendre = await request(app)
      .post(`/admin/comptes/${ca.user.id}/suspendre`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(suspendre.status).toBe(200);
    expect(suspendre.body.user.suspendu).toBe(true);

    const reactiver = await request(app)
      .post(`/admin/comptes/${ca.user.id}/reactiver`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(reactiver.status).toBe(200);
    expect(reactiver.body.user.suspendu).toBe(false);
  });

  it("réinitialise le mot de passe d'un compte CA — connexion possible avec le nouveau", async () => {
    const adminToken = await createAdmin();
    const ca = await createCa();

    const res = await request(app)
      .post(`/admin/comptes/${ca.user.id}/reinitialiser-mot-de-passe`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ password: 'nouveaumdp' });
    expect(res.status).toBe(204);

    const login = await request(app).post('/auth/login').send({ identifier: 's.martin@actiwork.fr', password: 'nouveaumdp' });
    expect(login.status).toBe(200);
  });

  it('supprime définitivement un compte CA', async () => {
    const adminToken = await createAdmin();
    const ca = await createCa();

    const res = await request(app).delete(`/admin/comptes/${ca.user.id}`).set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(204);

    const list = await request(app).get('/admin/comptes').set('Authorization', `Bearer ${adminToken}`);
    expect(list.body.comptes).toHaveLength(0);
  });

  it('refuse que l\'Admin se supprime lui-même', async () => {
    const adminToken = await createAdmin();
    const me = await request(app).get('/auth/me').set('Authorization', `Bearer ${adminToken}`);

    const res = await request(app).delete(`/admin/comptes/${me.body.user.id}`).set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(400);
  });

  it('refuse que l\'Admin agisse sur un autre compte Admin (suspension, suppression)', async () => {
    const adminToken = await createAdmin();
    const passwordHash = await bcrypt.hash('demodemo', 10);
    const autreAdmin = await prisma.user.create({
      data: {
        nom: 'Lefebvre', prenom: 'Autre', mobile: '0102030408', email: 'autre.admin@actiwork.fr',
        passwordHash, role: 'admin', isActive: true,
      },
    });

    const suspendre = await request(app)
      .post(`/admin/comptes/${autreAdmin.id}/suspendre`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(suspendre.status).toBe(404);

    const supprimer = await request(app).delete(`/admin/comptes/${autreAdmin.id}`).set('Authorization', `Bearer ${adminToken}`);
    expect(supprimer.status).toBe(404);
  });
});

describe("Tableau de bord d'activité Admin", () => {
  it('agrège inscriptions en attente, anomalies, PV signés et REX soumis', async () => {
    // Timeout relevé : chaque PATCH sur un point d'auto-contrôle vérifie
    // désormais le seuil de notification à 80% (requête supplémentaire), et
    // ce test en déclenche onze en parallèle contre la vraie base Neon.
    const adminToken = await createAdmin();
    const ca = await createCa();

    // Inscription en attente (installateur)
    await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });

    // Chantier avec un point en anomalie, un REX soumis et un PV signé
    const created = await request(app)
      .post('/chantiers')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({
        reference: 'LD64397', client: 'Costockage', adresse: '4 rue des Frères Lumière', ville: 'Meyzieu (69)',
        dateDebut: '2026-07-21T00:00:00.000Z', dateFin: '2026-07-23T00:00:00.000Z',
        contactNom: 'M. Weber', contactTel: '0612345678', horaires: '6h30-17h00',
        typeMonteCharge: 'Monte-charge non accompagné', capacite: '300 kg', niveaux: 2, referenceAffaire: 'AF-2026-001',
      });
    const pointId = created.body.chantier.receptionMarchandises[0].id;

    await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ status: 'nonConforme' });

    await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ transcription: 'Tout s\'est bien passé, quelques ajustements mineurs.' });

    // Compte installateur distinct de l'inscription "Thomas Roux" ci-dessus,
    // créé directement en base comme pour createCa/createAdmin.
    const installateurPasswordHash = await bcrypt.hash('demodemo', 10);
    const installateurUser = await prisma.user.create({
      data: {
        nom: 'Dubois', prenom: 'Julien', mobile: '0611223344', email: 'j.dubois@elevpro.fr',
        passwordHash: installateurPasswordHash, role: 'installateur', isActive: true,
      },
    });
    const installateurLogin = await request(app).post('/auth/login').send({ identifier: 'j.dubois@elevpro.fr', password: 'demodemo' });
    const installateurToken = installateurLogin.body.accessToken as string;
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ userId: installateurUser.id });
    await request(app)
      .post('/chantiers/LD64397/pv/document')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ file: `data:application/pdf;base64,${ONE_PX_PNG_BASE64}` });
    await request(app)
      .post('/chantiers/LD64397/pv/signature')
      .set('Authorization', `Bearer ${installateurToken}`)
      .send({ nomSignataire: 'M. Weber', fonctionSignataire: 'Client', file: `data:application/pdf;base64,${ONE_PX_PNG_BASE64}` });

    const feed = await request(app).get('/admin/activity').set('Authorization', `Bearer ${adminToken}`);
    expect(feed.status).toBe(200);
    expect(feed.body.inscriptionsEnAttente).toHaveLength(1);
    expect(feed.body.anomalies).toHaveLength(1);
    expect(feed.body.anomalies[0].chantierReference).toBe('LD64397');
    expect(feed.body.pvRecents).toHaveLength(1);
    expect(feed.body.pvRecents[0].pvSigneur).toBe('M. Weber');
    expect(feed.body.rexEnAttente).toHaveLength(1);
    expect(feed.body.rexEnAttente[0].rexTranscription).toContain('bien passé');
    expect(feed.body.pvRecents[0].pvSignatureImagePath).toMatch(/^https:\/\/blob\.vercel-storage\.com\/test\/pv-signe-.+\.pdf$/);
  });
});

describe('GET /admin/stats', () => {
  it('refuse à un chargé d\'affaires l\'accès aux statistiques', async () => {
    const ca = await createCa();
    const res = await request(app).get('/admin/stats').set('Authorization', `Bearer ${ca.accessToken}`);
    expect(res.status).toBe(403);
  });

  it('renvoie 8 semaines glissantes avec les compteurs de la semaine en cours', async () => {
    const adminToken = await createAdmin();
    const ca = await createCa();

    const created = await request(app)
      .post('/chantiers')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({
        reference: 'LD64397', client: 'Costockage', adresse: '4 rue des Frères Lumière', ville: 'Meyzieu (69)',
        dateDebut: '2026-07-21T00:00:00.000Z', dateFin: '2026-07-23T00:00:00.000Z',
        contactNom: 'M. Weber', contactTel: '0612345678', horaires: '6h30-17h00',
        typeMonteCharge: 'Monte-charge non accompagné', capacite: '300 kg', niveaux: 2, referenceAffaire: 'AF-2026-001',
      });
    const pointId = created.body.chantier.receptionMarchandises[0].id;

    await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ status: 'nonConforme' });

    await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ transcription: 'RAS.' });

    const installateurPasswordHash = await bcrypt.hash('demodemo', 10);
    const installateurUser = await prisma.user.create({
      data: {
        nom: 'Dubois', prenom: 'Julien', mobile: '0611223344', email: 'j.dubois@elevpro.fr',
        passwordHash: installateurPasswordHash, role: 'installateur', isActive: true,
      },
    });
    const installateurLogin = await request(app).post('/auth/login').send({ identifier: 'j.dubois@elevpro.fr', password: 'demodemo' });
    const installateurToken = installateurLogin.body.accessToken as string;
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ userId: installateurUser.id });
    await request(app)
      .post('/chantiers/LD64397/pv/document')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ file: `data:application/pdf;base64,${ONE_PX_PNG_BASE64}` });
    await request(app)
      .post('/chantiers/LD64397/pv/signature')
      .set('Authorization', `Bearer ${installateurToken}`)
      .send({ nomSignataire: 'M. Weber', fonctionSignataire: 'Client', file: `data:application/pdf;base64,${ONE_PX_PNG_BASE64}` });

    const res = await request(app).get('/admin/stats').set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.weeks).toHaveLength(8);

    const currentWeek = res.body.weeks[7];
    expect(currentWeek.pvSignes).toBe(1);
    expect(currentWeek.rexSoumis).toBe(1);
    expect(currentWeek.anomalies).toBe(1);
  });
});
