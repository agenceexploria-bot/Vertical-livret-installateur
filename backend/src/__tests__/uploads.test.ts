import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import { getPayloadFromClientToken } from '@vercel/blob/client';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb, signup as doSignup } from './helpers';

const app = createApp();

async function createInstallateurToken() {
  const signup = await doSignup(app, {
    nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
  });
  return signup.body.accessToken as string;
}

async function createCtToken() {
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

// Le jeton d'upload direct (voir routes/uploads.ts) est ce qui permet de
// contourner la limite de 4,5 Mo imposée par Vercel sur le corps des requêtes
// des fonctions serverless — ces tests vérifient que la génération de jeton
// est bien authentifiée et que le type/la taille autorisés dépendent
// uniquement du `kind` demandé, jamais de ce que le client déclare en plus.
describe('POST /uploads/token', () => {
  it('refuse une demande de jeton non authentifiée', async () => {
    const res = await request(app)
      .post('/uploads/token')
      .send({ type: 'blob.generate-client-token', payload: { pathname: 'x.png', callbackUrl: 'http://x', clientPayload: JSON.stringify({ kind: 'avatar' }), multipart: false } });
    expect(res.status).toBe(401);
  });

  it('délivre un jeton restreint au type et à la taille prévus pour le kind demandé', async () => {
    const token = await createInstallateurToken();

    const res = await request(app)
      .post('/uploads/token')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'blob.generate-client-token',
        payload: { pathname: 'x.png', callbackUrl: 'http://x', clientPayload: JSON.stringify({ kind: 'avatar' }), multipart: false },
      });

    expect(res.status).toBe(200);
    const payload = getPayloadFromClientToken(res.body.clientToken as string);
    expect(payload.allowedContentTypes).toEqual(['image/jpeg', 'image/png']);
    expect(payload.maximumSizeInBytes).toBe(10 * 1024 * 1024);
  });

  it('autorise les vidéos pour les documents terrain (installateur)', async () => {
    const token = await createInstallateurToken();

    const res = await request(app)
      .post('/uploads/token')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'blob.generate-client-token',
        payload: { pathname: 'x.mp4', callbackUrl: 'http://x', clientPayload: JSON.stringify({ kind: 'documentTerrain' }), multipart: false },
      });

    expect(res.status).toBe(200);
    const payload = getPayloadFromClientToken(res.body.clientToken as string);
    expect(payload.allowedContentTypes).toContain('video/mp4');
  });

  it('autorise les vidéos pour les documents chantier (CT/direction/admin)', async () => {
    const token = await createCtToken();

    const res = await request(app)
      .post('/uploads/token')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'blob.generate-client-token',
        payload: { pathname: 'x.mp4', callbackUrl: 'http://x', clientPayload: JSON.stringify({ kind: 'documentChantier' }), multipart: false },
      });

    expect(res.status).toBe(200);
    const payload = getPayloadFromClientToken(res.body.clientToken as string);
    expect(payload.allowedContentTypes).toContain('video/mp4');
  });

  it('refuse un installateur pour les documents chantier (réservés CT/direction/admin)', async () => {
    const token = await createInstallateurToken();

    const res = await request(app)
      .post('/uploads/token')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'blob.generate-client-token',
        payload: { pathname: 'x.mp4', callbackUrl: 'http://x', clientPayload: JSON.stringify({ kind: 'documentChantier' }), multipart: false },
      });

    expect(res.status).toBe(400);
  });

  it('refuse un installateur pour le PV gabarit (réservé CT/direction/admin)', async () => {
    const token = await createInstallateurToken();

    const res = await request(app)
      .post('/uploads/token')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'blob.generate-client-token',
        payload: { pathname: 'x.pdf', callbackUrl: 'http://x', clientPayload: JSON.stringify({ kind: 'pvDocument' }), multipart: false },
      });

    expect(res.status).toBe(400);
  });

  it('refuse un kind inconnu', async () => {
    const token = await createInstallateurToken();

    const res = await request(app)
      .post('/uploads/token')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'blob.generate-client-token',
        payload: { pathname: 'x.png', callbackUrl: 'http://x', clientPayload: JSON.stringify({ kind: 'inconnu' }), multipart: false },
      });

    expect(res.status).toBe(400);
  });
});
