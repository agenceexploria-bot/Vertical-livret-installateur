import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import { put } from '@vercel/blob';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb, signup as doSignup } from './helpers';

const ONE_PX_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

const app = createApp();

// Les endpoints n'acceptent plus le fichier en base64 : l'app le dépose
// d'abord directement sur Vercel Blob (voir routes/uploads.ts), puis
// transmet l'URL obtenue. En test, `put` est mocké (voir vitest.setup.ts) —
// l'appeler ici simule ce dépôt direct.
async function fakeUpload(filename: string, base64: string, contentType: string): Promise<string> {
  const uniqueFilename = `${Date.now()}-${Math.round(Math.random() * 1e6)}-${filename}`;
  const { url } = await put(uniqueFilename, Buffer.from(base64, 'base64'), { access: 'public', contentType });
  return url;
}

async function createInstallateur() {
  const signup = await doSignup(app, {
    nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
  });
  return signup.body.accessToken as string;
}

async function createCt() {
  const passwordHash = await bcrypt.hash('demodemo', 10);
  await prisma.user.create({
    data: {
      nom: 'Martin', prenom: 'Sandrine', mobile: '0102030405', email: 's.martin@actiwork.fr',
      passwordHash, role: 'coordinateurTravaux', isActive: true,
    },
  });
  const login = await request(app).post('/auth/login').send({ identifier: 's.martin@actiwork.fr', password: 'demodemo' });
  return login.body.accessToken as string;
}

beforeEach(async () => {
  await resetDb();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe('Cycle de vie des comptes installateurs (EX-01 à EX-06)', () => {
  it('un compte nouvellement inscrit apparaît en attente pour le CT', async () => {
    const caToken = await createCt();
    await doSignup(app, { nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo' });

    const res = await request(app).get('/comptes').set('Authorization', `Bearer ${caToken}`);
    expect(res.status).toBe(200);
    expect(res.body.installateurs).toHaveLength(1);
    expect(res.body.installateurs[0].isActive).toBe(false);
  });

  it('le CT peut valider un compte, qui devient alors actif', async () => {
    const caToken = await createCt();
    const signup = await doSignup(app, { nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo' });

    const res = await request(app)
      .post(`/comptes/${signup.body.user.id}/valider`)
      .set('Authorization', `Bearer ${caToken}`);
    expect(res.status).toBe(200);
    expect(res.body.user.isActive).toBe(true);
  });

  it('un installateur ne peut pas accéder à la liste des comptes', async () => {
    const signup = await doSignup(app, { nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo' });
    const res = await request(app).get('/comptes').set('Authorization', `Bearer ${signup.body.accessToken}`);
    expect(res.status).toBe(403);
  });

  it('suspendre puis réactiver un compte fonctionne', async () => {
    const caToken = await createCt();
    const signup = await doSignup(app, { nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo' });
    await request(app).post(`/comptes/${signup.body.user.id}/valider`).set('Authorization', `Bearer ${caToken}`);

    const suspended = await request(app).post(`/comptes/${signup.body.user.id}/suspendre`).set('Authorization', `Bearer ${caToken}`);
    expect(suspended.body.user.suspendu).toBe(true);

    const reactivated = await request(app).post(`/comptes/${signup.body.user.id}/reactiver`).set('Authorization', `Bearer ${caToken}`);
    expect(reactivated.body.user.suspendu).toBe(false);
    expect(reactivated.body.user.isActive).toBe(true);
  });
});

describe('comptes.ts ne doit agir que sur des comptes installateurs', () => {
  it('refuse à un CT de suspendre un autre compte interne (ex. un Admin)', async () => {
    const caToken = await createCt();
    const passwordHash = await bcrypt.hash('demodemo', 10);
    const admin = await prisma.user.create({
      data: {
        nom: 'Lefebvre', prenom: 'Admin', mobile: '0102030407', email: 'admin@actiwork.fr',
        passwordHash, role: 'admin', isActive: true,
      },
    });

    const res = await request(app)
      .post(`/comptes/${admin.id}/suspendre`)
      .set('Authorization', `Bearer ${caToken}`);
    expect(res.status).toBe(404);

    const stillActive = await prisma.user.findUnique({ where: { id: admin.id } });
    expect(stillActive?.suspendu).toBe(false);
  });
});

describe('POST /comptes/moi/habilitations (EX-13)', () => {
  it('téléverse un vrai certificat et enregistre le fichier sur le stockage distant', async () => {
    const token = await createInstallateur();
    const fileUrl = await fakeUpload('habilitation.png', ONE_PX_PNG_BASE64, 'image/png');

    const res = await request(app)
      .post('/comptes/moi/habilitations')
      .set('Authorization', `Bearer ${token}`)
      .send({
        titre: 'Habilitation électrique BR',
        dateExpiration: '2027-03-12T00:00:00.000Z',
        fileUrl,
      });

    expect(res.status).toBe(201);
    expect(res.body.habilitation.filePath).toBe(fileUrl);

    const caToken = await createCt();
    const list = await request(app).get('/comptes').set('Authorization', `Bearer ${caToken}`);
    expect(list.body.installateurs[0].habilitations[0].filePath).toBe(fileUrl);
  });

  it('refuse un certificat sans fichier', async () => {
    const token = await createInstallateur();

    const res = await request(app)
      .post('/comptes/moi/habilitations')
      .set('Authorization', `Bearer ${token}`)
      .send({ titre: 'Habilitation électrique BR', dateExpiration: '2027-03-12T00:00:00.000Z' });
    expect(res.status).toBe(400);
  });
});

describe('DELETE /comptes/:id (suppression définitive, Admin uniquement)', () => {
  it('supprime le compte ainsi que le fichier de son certificat', async () => {
    const token = await createInstallateur();
    await request(app)
      .post('/comptes/moi/habilitations')
      .set('Authorization', `Bearer ${token}`)
      .send({
        titre: 'Habilitation électrique BR',
        dateExpiration: '2027-03-12T00:00:00.000Z',
        fileUrl: await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png'),
      });
    const me = await request(app).get('/auth/me').set('Authorization', `Bearer ${token}`);

    const passwordHash = await bcrypt.hash('demodemo', 10);
    await prisma.user.create({
      data: {
        nom: 'Lefebvre', prenom: 'Admin', mobile: '0102030407', email: 'admin@actiwork.fr',
        passwordHash, role: 'admin', isActive: true,
      },
    });
    const adminLogin = await request(app).post('/auth/login').send({ identifier: 'admin@actiwork.fr', password: 'demodemo' });

    const res = await request(app)
      .delete(`/comptes/${me.body.user.id}`)
      .set('Authorization', `Bearer ${adminLogin.body.accessToken}`);
    expect(res.status).toBe(204);

    const list = await request(app).get('/comptes').set('Authorization', `Bearer ${adminLogin.body.accessToken}`);
    expect(list.body.installateurs).toHaveLength(0);
  });
});

describe('POST /comptes/moi/avatar', () => {
  it('téléverse une photo de profil et enregistre le fichier sur le stockage distant', async () => {
    const token = await createInstallateur();
    const fileUrl = await fakeUpload('avatar.png', ONE_PX_PNG_BASE64, 'image/png');

    const res = await request(app)
      .post('/comptes/moi/avatar')
      .set('Authorization', `Bearer ${token}`)
      .send({ fileUrl });

    expect(res.status).toBe(200);
    expect(res.body.user.avatarUrl).toBe(fileUrl);
  });

  it('remplace la photo précédente plutôt que d\'en accumuler plusieurs', async () => {
    const token = await createInstallateur();

    const first = await request(app)
      .post('/comptes/moi/avatar')
      .set('Authorization', `Bearer ${token}`)
      .send({ fileUrl: await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png') });
    const second = await request(app)
      .post('/comptes/moi/avatar')
      .set('Authorization', `Bearer ${token}`)
      .send({ fileUrl: await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png') });

    expect(second.status).toBe(200);
    expect(second.body.user.avatarUrl).not.toBe(first.body.user.avatarUrl);
  });

  // Le type de fichier est désormais restreint en amont, au moment de la
  // génération du jeton d'upload (kind "avatar", voir routes/uploads.ts) —
  // cette route-ci ne vérifie plus que l'URL pointe vers notre store Blob.
  it('refuse une URL de fichier qui ne pointe pas vers notre store Vercel Blob', async () => {
    const token = await createInstallateur();

    const res = await request(app)
      .post('/comptes/moi/avatar')
      .set('Authorization', `Bearer ${token}`)
      .send({ fileUrl: 'https://evil.example.com/malware.png' });
    expect(res.status).toBe(400);
  });

  it('refuse une requête sans fichier', async () => {
    const token = await createInstallateur();

    const res = await request(app).post('/comptes/moi/avatar').set('Authorization', `Bearer ${token}`).send({});
    expect(res.status).toBe(400);
  });
});

describe('DELETE /comptes/moi/avatar', () => {
  it('supprime la photo de profil et repasse avatarUrl à null', async () => {
    const token = await createInstallateur();
    await request(app)
      .post('/comptes/moi/avatar')
      .set('Authorization', `Bearer ${token}`)
      .send({ fileUrl: await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png') });

    const res = await request(app).delete('/comptes/moi/avatar').set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.user.avatarUrl).toBeNull();
  });

  it('est idempotente quand il n\'y a déjà pas de photo', async () => {
    const token = await createInstallateur();

    const res = await request(app).delete('/comptes/moi/avatar').set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.user.avatarUrl).toBeNull();
  });
});

describe('PATCH /comptes/moi', () => {
  it('modifie le nom et le prénom du compte connecté', async () => {
    const token = await createInstallateur();

    const res = await request(app)
      .patch('/comptes/moi')
      .set('Authorization', `Bearer ${token}`)
      .send({ nom: 'Nouveau', prenom: 'Prénom' });

    expect(res.status).toBe(200);
    expect(res.body.user.fullName).toBe('Prénom Nouveau');
  });

  it('refuse un email déjà utilisé par un autre compte', async () => {
    const token = await createInstallateur();
    await doSignup(app, { nom: 'Autre', prenom: 'Personne', email: 'autre@example.com', password: 'demodemo' });

    const res = await request(app)
      .patch('/comptes/moi')
      .set('Authorization', `Bearer ${token}`)
      .send({ email: 'autre@example.com' });
    expect(res.status).toBe(409);
  });
});
