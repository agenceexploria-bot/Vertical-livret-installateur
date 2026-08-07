import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb, signup as doSignup } from './helpers';

const app = createApp();

async function createInstallateur() {
  const signup = await doSignup(app, {
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

// Pusher n'est pas configuré en environnement de test (variables PUSHER_*
// vides dans .env), donc `authorizeChannel` renvoie toujours `null` — la
// route répond alors 503 une fois le contrôle de rôle passé. Ces tests
// vérifient précisément ce contrôle de rôle (la partie sécurité de la
// correction), indépendante de la configuration Pusher elle-même.
describe('POST /pusher/auth', () => {
  it('refuse une requête non authentifiée', async () => {
    const res = await request(app).post('/pusher/auth').send({ socket_id: '123.456', channel_name: 'private-app-events' });
    expect(res.status).toBe(401);
  });

  it('autorise un installateur sur private-app-events (503 : Pusher non configuré en test)', async () => {
    const token = await createInstallateur();
    const res = await request(app)
      .post('/pusher/auth')
      .set('Authorization', `Bearer ${token}`)
      .send({ socket_id: '123.456', channel_name: 'private-app-events' });
    expect(res.status).toBe(503);
  });

  it('refuse un installateur sur private-notifications', async () => {
    const token = await createInstallateur();
    const res = await request(app)
      .post('/pusher/auth')
      .set('Authorization', `Bearer ${token}`)
      .send({ socket_id: '123.456', channel_name: 'private-notifications' });
    expect(res.status).toBe(403);
  });

  it('autorise un CA sur private-notifications (503 : Pusher non configuré en test)', async () => {
    const token = await createCa();
    const res = await request(app)
      .post('/pusher/auth')
      .set('Authorization', `Bearer ${token}`)
      .send({ socket_id: '123.456', channel_name: 'private-notifications' });
    expect(res.status).toBe(503);
  });

  it('refuse un nom de canal inconnu', async () => {
    const token = await createCa();
    const res = await request(app)
      .post('/pusher/auth')
      .set('Authorization', `Bearer ${token}`)
      .send({ socket_id: '123.456', channel_name: 'private-autre-chose' });
    expect(res.status).toBe(403);
  });
});
