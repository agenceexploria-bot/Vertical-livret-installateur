import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import fs from 'fs';
import path from 'path';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb, signup as doSignup } from './helpers';

const ONE_PX_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

const app = createApp();

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

async function createInstallateur(overrides: Partial<{ isActive: boolean; mobile: string }> = {}) {
  const signup = await doSignup(app, {
    nom: 'Roux', prenom: 'Thomas', mobile: overrides.mobile ?? '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
  });
  if (overrides.isActive) {
    await prisma.user.update({ where: { id: signup.body.user.id }, data: { isActive: true } });
  }
  const login = await request(app).post('/auth/login').send({ identifier: overrides.mobile ?? '0652417890', password: 'demodemo' });
  return { user: signup.body.user, accessToken: login.body.accessToken as string };
}

async function createChantier(caToken: string, reference = 'LD64397') {
  return request(app)
    .post('/chantiers')
    .set('Authorization', `Bearer ${caToken}`)
    .send({
      reference,
      client: 'Costockage',
      adresse: '4 rue des Frères Lumière',
      ville: 'Meyzieu (69)',
      dateDebut: '2026-07-21T00:00:00.000Z',
      dateFin: '2026-07-23T00:00:00.000Z',
      contactNom: 'M. Weber',
      contactTel: '0612345678',
      horaires: '6h30-17h00',
      consignes: ['Badge obligatoire'],
      typeMonteCharge: 'Monte-charge non accompagné',
      capacite: '300 kg',
      niveaux: 2,
      referenceAffaire: 'AF-2026-001',
    });
}

beforeEach(async () => {
  await resetDb();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe('POST /chantiers', () => {
  it('un chargé d\'affaires peut créer un chantier avec ses points de contrôle pré-remplis', async () => {
    const ca = await createCa();
    const res = await createChantier(ca.accessToken);

    expect(res.status).toBe(201);
    expect(res.body.chantier.reference).toBe('LD64397');
    expect(res.body.chantier.receptionMarchandises).toHaveLength(5);
    expect(res.body.chantier.autoControle).toHaveLength(11);
    expect(res.body.chantier.installateursRattaches).toHaveLength(0);
  });

  it('refuse la création par un installateur', async () => {
    const installateur = await createInstallateur({ isActive: true });
    const res = await createChantier(installateur.accessToken);
    expect(res.status).toBe(403);
  });

  it('refuse une référence déjà existante', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);
    const res = await createChantier(ca.accessToken);
    expect(res.status).toBe(409);
  });
});

describe('GET /chantiers — rattachement (EX-04)', () => {
  it("un installateur non rattaché ne voit aucun chantier", async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);
    const installateur = await createInstallateur({ isActive: true });

    const res = await request(app).get('/chantiers').set('Authorization', `Bearer ${installateur.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.chantiers).toHaveLength(0);
  });

  it('un installateur rattaché voit le chantier ; le CA voit tout', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);
    const installateur = await createInstallateur({ isActive: true });

    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ userId: installateur.user.id });

    const asInstallateur = await request(app).get('/chantiers').set('Authorization', `Bearer ${installateur.accessToken}`);
    expect(asInstallateur.body.chantiers).toHaveLength(1);
    expect(asInstallateur.body.chantiers[0].installateursRattaches[0].id).toBe(installateur.user.id);

    const asCa = await request(app).get('/chantiers').set('Authorization', `Bearer ${ca.accessToken}`);
    expect(asCa.body.chantiers).toHaveLength(1);
  });
});

describe('Progression et modules', () => {
  it('coche un point de contrôle et met à jour la progression', async () => {
    const ca = await createCa();
    const created = await createChantier(ca.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;

    const patch = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ status: 'conforme', photoPath: 'photo.jpg' });
    expect(patch.status).toBe(200);

    const res = await request(app).get('/chantiers/LD64397').set('Authorization', `Bearer ${ca.accessToken}`);
    expect(res.body.chantier.progressionReception).toBeCloseTo(1 / 5);
  });

  it("génère l'auto-contrôle avec des catégories et des points de sécurité critiques", async () => {
    const ca = await createCa();
    const created = await createChantier(ca.accessToken);
    const autoControle = created.body.chantier.autoControle as { categorie: string; critique: boolean }[];

    expect(autoControle.some((p) => p.categorie === 'Portes palières' && p.critique)).toBe(true);
    expect(autoControle.every((p) => p.categorie && typeof p.critique === 'boolean')).toBe(true);
  });

  it('horodate et attribue nominativement la validation d\'un point au compte connecté', async () => {
    const ca = await createCa();
    const created = await createChantier(ca.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;
    const clientValidatedAt = '2026-07-23T08:15:00.000Z';

    const patch = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ status: 'conforme', photoPath: 'photo.jpg', clientValidatedAt });

    expect(patch.status).toBe(200);
    expect(patch.body.point.validePar).toBe('Sandrine Martin');
    expect(patch.body.point.valideAt).toBe(clientValidatedAt);
  });

  it("enregistre la photo d'un point de contrôle sur le disque et renvoie son chemin", async () => {
    const ca = await createCa();
    const created = await createChantier(ca.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;

    const patch = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ status: 'conforme', photo: `data:image/jpeg;base64,${ONE_PX_PNG_BASE64}` });

    expect(patch.status).toBe(200);
    const photoPath = patch.body.point.photoPath as string;
    expect(photoPath).toMatch(new RegExp(`^/uploads/point-${pointId}-.+\\.jpeg$`));

    const fileOnDisk = path.join(__dirname, '..', '..', 'uploads', path.basename(photoPath));
    expect(fs.existsSync(fileOnDisk)).toBe(true);
    fs.unlinkSync(fileOnDisk);
  });

  it('refuse de signer le PV tant que l\'auto-contrôle n\'est pas complet', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/pv')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ signataire: 'M. Weber' });

    expect(res.status).toBe(400);
  });

  it('signe le PV une fois l\'auto-contrôle complet, et refuse une seconde signature', async () => {
    const ca = await createCa();
    const created = await createChantier(ca.accessToken);

    await Promise.all(
      created.body.chantier.autoControle.map((p: { id: string }) =>
        request(app)
          .patch(`/chantiers/LD64397/points/${p.id}`)
          .set('Authorization', `Bearer ${ca.accessToken}`)
          .send({ status: 'conforme', photoPath: 'photo.jpg' }),
      ),
    );

    const res = await request(app)
      .post('/chantiers/LD64397/pv')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ signataire: 'M. Weber' });

    expect(res.status).toBe(200);
    expect(res.body.chantier.pvSigne).toBe(true);
    expect(res.body.chantier.pvSigneur).toBe('M. Weber');

    const second = await request(app)
      .post('/chantiers/LD64397/pv')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ signataire: 'Un autre' });
    expect(second.status).toBe(409);
  });

  it('enregistre l\'image de la signature sur le disque et renvoie son chemin', async () => {
    const ca = await createCa();
    const created = await createChantier(ca.accessToken);

    await Promise.all(
      created.body.chantier.autoControle.map((p: { id: string }) =>
        request(app)
          .patch(`/chantiers/LD64397/points/${p.id}`)
          .set('Authorization', `Bearer ${ca.accessToken}`)
          .send({ status: 'conforme', photoPath: 'photo.jpg' }),
      ),
    );

    const res = await request(app)
      .post('/chantiers/LD64397/pv')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ signataire: 'M. Weber', signatureImage: `data:image/png;base64,${ONE_PX_PNG_BASE64}` });

    expect(res.status).toBe(200);
    const imagePath = res.body.chantier.pvSignatureImagePath as string;
    expect(imagePath).toMatch(/^\/uploads\/signature-.+\.png$/);

    const filename = path.basename(imagePath);
    const fileOnDisk = path.join(__dirname, '..', '..', 'uploads', filename);
    expect(fs.existsSync(fileOnDisk)).toBe(true);
    expect(fs.readFileSync(fileOnDisk).equals(Buffer.from(ONE_PX_PNG_BASE64, 'base64'))).toBe(true);

    fs.unlinkSync(fileOnDisk);
  });
});

describe('POST /chantiers/:reference/rex', () => {
  it('accepte un REX texte seul (sans audio)', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ transcription: 'Tout s\'est bien passé.' });

    expect(res.status).toBe(200);
    expect(res.body.chantier.rexValide).toBe(true);
    expect(res.body.chantier.rexTranscription).toBe('Tout s\'est bien passé.');
  });

  it('accepte une note vocale seule (sans transcription) et enregistre le fichier audio', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ audio: `data:audio/webm;base64,${ONE_PX_PNG_BASE64}` });

    expect(res.status).toBe(200);
    expect(res.body.chantier.rexValide).toBe(true);
    expect(res.body.chantier.rexTranscription).toBeNull();
    const audioPath = res.body.chantier.rexAudioPath as string;
    expect(audioPath).toMatch(/^\/uploads\/rex-LD64397-.+\.webm$/);

    const fileOnDisk = path.join(__dirname, '..', '..', 'uploads', path.basename(audioPath));
    expect(fs.existsSync(fileOnDisk)).toBe(true);
    fs.unlinkSync(fileOnDisk);
  });

  it('refuse un REX sans transcription ni audio', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({});
    expect(res.status).toBe(400);
  });
});

describe('POST /chantiers/:reference/documents', () => {
  it('dépose un document (photo) et enregistre le fichier sur le disque', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/documents')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ titre: 'Bon de livraison', categorie: 'bonLivraison', file: `data:image/png;base64,${ONE_PX_PNG_BASE64}` });

    expect(res.status).toBe(201);
    expect(res.body.document.categorie).toBe('bonLivraison');
    const filePath = res.body.document.filePath as string;
    expect(filePath).toMatch(/^\/uploads\/doc-.+\.png$/);

    const fileOnDisk = path.join(__dirname, '..', '..', 'uploads', path.basename(filePath));
    expect(fs.existsSync(fileOnDisk)).toBe(true);
    fs.unlinkSync(fileOnDisk);
  });

  it('refuse un dépôt sans catégorie', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/documents')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ titre: 'Sans catégorie', file: `data:image/png;base64,${ONE_PX_PNG_BASE64}` });
    expect(res.status).toBe(400);
  });

  it('refuse un dépôt sans fichier', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/documents')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ titre: 'Sans fichier', categorie: 'constat' });
    expect(res.status).toBe(400);
  });
});

describe('Sécurité — rattachement obligatoire pour un installateur (bug 3B)', () => {
  it('refuse à un installateur non rattaché de modifier un point de contrôle', async () => {
    const ca = await createCa();
    const created = await createChantier(ca.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;
    const etranger = await createInstallateur({ isActive: true });

    const res = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${etranger.accessToken}`)
      .send({ status: 'conforme' });
    expect(res.status).toBe(403);
  });

  it('refuse à un installateur non rattaché de soumettre un REX', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);
    const etranger = await createInstallateur({ isActive: true });

    const res = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${etranger.accessToken}`)
      .send({ transcription: 'Tentative non autorisée' });
    expect(res.status).toBe(403);
  });

  it('refuse à un installateur non rattaché de signer le PV', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);
    const etranger = await createInstallateur({ isActive: true });

    const res = await request(app)
      .post('/chantiers/LD64397/pv')
      .set('Authorization', `Bearer ${etranger.accessToken}`)
      .send({ signataire: 'Tentative non autorisée' });
    expect(res.status).toBe(403);
  });

  it('refuse à un installateur non rattaché de déposer un document', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);
    const etranger = await createInstallateur({ isActive: true });

    const res = await request(app)
      .post('/chantiers/LD64397/documents')
      .set('Authorization', `Bearer ${etranger.accessToken}`)
      .send({ titre: 'Intrusion', categorie: 'constat', file: `data:image/png;base64,${ONE_PX_PNG_BASE64}` });
    expect(res.status).toBe(403);
  });

  it('autorise toujours un installateur bien rattaché à modifier un point', async () => {
    const ca = await createCa();
    const created = await createChantier(ca.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;
    const installateur = await createInstallateur({ isActive: true });
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ userId: installateur.user.id });

    const res = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ status: 'conforme' });
    expect(res.status).toBe(200);
  });

  it("refuse d'accéder à un point de contrôle appartenant à un autre chantier", async () => {
    const ca = await createCa();
    const chantierA = await createChantier(ca.accessToken, 'LD64397');
    await createChantier(ca.accessToken, 'LD91245');
    const pointDeA = chantierA.body.chantier.receptionMarchandises[0].id;

    const installateur = await createInstallateur({ isActive: true });
    // Rattaché à LD91245, mais pas à LD64397 — pointDeA appartient à LD64397.
    await request(app)
      .post('/chantiers/LD91245/rattacher')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ userId: installateur.user.id });

    const res = await request(app)
      .patch(`/chantiers/LD91245/points/${pointDeA}`)
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ status: 'conforme' });
    expect(res.status).toBe(404);
  });
});

describe('Sécurité — GET /chantiers filtré par rôle (bug 3A)', () => {
  it("refuse à l'Admin l'accès à la liste des chantiers", async () => {
    const passwordHash = await bcrypt.hash('demodemo', 10);
    await prisma.user.create({
      data: {
        nom: 'Lefebvre', prenom: 'Admin', mobile: '0102030407', email: 'admin@actiwork.fr',
        passwordHash, role: 'admin', isActive: true,
      },
    });
    const login = await request(app).post('/auth/login').send({ identifier: 'admin@actiwork.fr', password: 'demodemo' });

    const res = await request(app).get('/chantiers').set('Authorization', `Bearer ${login.body.accessToken}`);
    expect(res.status).toBe(403);
  });
});

describe('POST /chantiers/:reference/documents-chantier (Modules 1-3)', () => {
  it('permet au CA de déposer un document de référence, lisible ensuite via GET', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/documents-chantier')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ type: 'securite', nom: 'PPSPS', file: `data:image/png;base64,${ONE_PX_PNG_BASE64}` });

    expect(res.status).toBe(201);
    expect(res.body.chantier.documentsChantier).toHaveLength(1);
    expect(res.body.chantier.documentsChantier[0].type).toBe('securite');
    expect(res.body.chantier.documentsChantier[0].nom).toBe('PPSPS');
    const filePath = res.body.chantier.documentsChantier[0].filePath as string;
    expect(filePath).toMatch(/^\/uploads\/doc-chantier-.+\.png$/);

    const fileOnDisk = path.join(__dirname, '..', '..', 'uploads', path.basename(filePath));
    expect(fs.existsSync(fileOnDisk)).toBe(true);
    fs.unlinkSync(fileOnDisk);

    const get = await request(app).get('/chantiers/LD64397').set('Authorization', `Bearer ${ca.accessToken}`);
    expect(get.body.chantier.documentsChantier).toHaveLength(1);
  });

  it('refuse à un installateur de déposer un document de référence', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);
    const installateur = await createInstallateur({ isActive: true });

    const res = await request(app)
      .post('/chantiers/LD64397/documents-chantier')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ type: 'technique', nom: 'Plan', file: `data:image/png;base64,${ONE_PX_PNG_BASE64}` });
    expect(res.status).toBe(403);
  });

  it('refuse un type de document invalide', async () => {
    const ca = await createCa();
    await createChantier(ca.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/documents-chantier')
      .set('Authorization', `Bearer ${ca.accessToken}`)
      .send({ type: 'autre', nom: 'PPSPS', file: `data:image/png;base64,${ONE_PX_PNG_BASE64}` });
    expect(res.status).toBe(400);
  });
});
