import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import fs from 'fs';
import path from 'path';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb } from './helpers';

const ONE_PX_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

const app = createApp();

async function createInstallateur() {
  const signup = await request(app).post('/auth/signup').send({
    nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
  });
  return signup.body.accessToken as string;
}

async function createCa() {
  const passwordHash = await bcrypt.hash('demodemo', 10);
  await prisma.user.create({
    data: {
      nom: 'Martin', prenom: 'Sandrine', mobile: '0102030405', email: 's.martin@actiwork.fr',
      passwordHash, role: 'chargeAffaires', isActive: true,
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
  it('un compte nouvellement inscrit apparaît en attente pour le CA', async () => {
    const caToken = await createCa();
    await request(app).post('/auth/signup').send({ nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo' });

    const res = await request(app).get('/comptes').set('Authorization', `Bearer ${caToken}`);
    expect(res.status).toBe(200);
    expect(res.body.installateurs).toHaveLength(1);
    expect(res.body.installateurs[0].isActive).toBe(false);
  });

  it('le CA peut valider un compte, qui devient alors actif', async () => {
    const caToken = await createCa();
    const signup = await request(app).post('/auth/signup').send({ nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo' });

    const res = await request(app)
      .post(`/comptes/${signup.body.user.id}/valider`)
      .set('Authorization', `Bearer ${caToken}`);
    expect(res.status).toBe(200);
    expect(res.body.user.isActive).toBe(true);
  });

  it('un installateur ne peut pas accéder à la liste des comptes', async () => {
    const signup = await request(app).post('/auth/signup').send({ nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo' });
    const res = await request(app).get('/comptes').set('Authorization', `Bearer ${signup.body.accessToken}`);
    expect(res.status).toBe(403);
  });

  it('suspendre puis réactiver un compte fonctionne', async () => {
    const caToken = await createCa();
    const signup = await request(app).post('/auth/signup').send({ nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo' });
    await request(app).post(`/comptes/${signup.body.user.id}/valider`).set('Authorization', `Bearer ${caToken}`);

    const suspended = await request(app).post(`/comptes/${signup.body.user.id}/suspendre`).set('Authorization', `Bearer ${caToken}`);
    expect(suspended.body.user.suspendu).toBe(true);

    const reactivated = await request(app).post(`/comptes/${signup.body.user.id}/reactiver`).set('Authorization', `Bearer ${caToken}`);
    expect(reactivated.body.user.suspendu).toBe(false);
    expect(reactivated.body.user.isActive).toBe(true);
  });
});

describe('POST /comptes/moi/habilitations (EX-13)', () => {
  it('téléverse un vrai certificat et enregistre le fichier sur le disque', async () => {
    const token = await createInstallateur();

    const res = await request(app)
      .post('/comptes/moi/habilitations')
      .set('Authorization', `Bearer ${token}`)
      .send({
        titre: 'Habilitation électrique BR',
        dateExpiration: '2027-03-12T00:00:00.000Z',
        file: `data:image/png;base64,${ONE_PX_PNG_BASE64}`,
      });

    expect(res.status).toBe(201);
    const filePath = res.body.habilitation.filePath as string;
    expect(filePath).toMatch(/^\/uploads\/habilitation-.+\.png$/);

    const fileOnDisk = path.join(__dirname, '..', '..', 'uploads', path.basename(filePath));
    expect(fs.existsSync(fileOnDisk)).toBe(true);
    fs.unlinkSync(fileOnDisk);

    const caToken = await createCa();
    const list = await request(app).get('/comptes').set('Authorization', `Bearer ${caToken}`);
    expect(list.body.installateurs[0].habilitations[0].filePath).toBe(filePath);
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
