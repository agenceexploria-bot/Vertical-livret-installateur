import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb, signup as doSignup } from './helpers';

const app = createApp();

beforeEach(async () => {
  await resetDb();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe('POST /auth/signup', () => {
  it("crée un compte installateur en attente de validation", async () => {
    const res = await doSignup(app, {
      nom: 'Dupont',
      prenom: 'Jean',
      mobile: '06 11 22 33 44',
      email: 'jean.dupont@example.com',
      password: 'motdepasse',
    });

    expect(res.status).toBe(201);
    expect(res.body.user.role).toBe('installateur');
    expect(res.body.user.isActive).toBe(false);
    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
  });

  it('refuse une inscription sans email', async () => {
    const res = await doSignup(app, {
      nom: 'Dupont', prenom: 'Jean', mobile: '0611223344', password: 'motdepasse',
    });
    expect(res.status).toBe(400);
  });

  it('normalise le mobile (espaces retirés) pour éviter les doublons', async () => {
    await doSignup(app, {
      nom: 'Dupont', prenom: 'Jean', mobile: '0611223344', email: 'jean.dupont@example.com', password: 'motdepasse',
    });
    const res = await doSignup(app, {
      nom: 'Autre', prenom: 'Personne', mobile: '06 11 22 33 44', email: 'autre.personne@example.com', password: 'motdepasse',
    });
    expect(res.status).toBe(409);
  });

  it('refuse un mot de passe trop court', async () => {
    const res = await doSignup(app, {
      nom: 'Dupont', prenom: 'Jean', mobile: '0611223344', email: 'jean.dupont@example.com', password: '123',
    });
    expect(res.status).toBe(400);
  });

  it('accepte une inscription sans mobile (facultatif)', async () => {
    const res = await doSignup(app, {
      nom: 'Dupont', prenom: 'Jean', email: 'jean.dupont@example.com', password: 'motdepasse',
    });
    expect(res.status).toBe(201);
    expect(res.body.user.mobile).toBeNull();
  });

  it('refuse un signup sans ticket de vérification email', async () => {
    const res = await request(app).post('/auth/signup').send({
      nom: 'Dupont', prenom: 'Jean', email: 'jean.dupont@example.com', password: 'motdepasse',
    });
    expect(res.status).toBe(400);
  });

  it('refuse un signup dont le ticket ne correspond pas à l\'email soumis', async () => {
    const codeRes = await request(app).post('/auth/request-email-code').send({ email: 'jean.dupont@example.com' });
    const verifyRes = await request(app)
      .post('/auth/verify-email-code')
      .send({ email: 'jean.dupont@example.com', code: codeRes.body.code });

    const res = await request(app).post('/auth/signup').send({
      nom: 'Dupont', prenom: 'Jean', email: 'autre@example.com', password: 'motdepasse',
      verificationTicket: verifyRes.body.verificationTicket,
    });
    expect(res.status).toBe(400);
  });
});

describe('POST /auth/request-email-code', () => {
  it('envoie un code et le renvoie en clair en environnement de test', async () => {
    const res = await request(app).post('/auth/request-email-code').send({ email: 'jean.dupont@example.com' });
    expect(res.status).toBe(200);
    expect(res.body.code).toMatch(/^\d{6}$/);
  });

  it('bloque si un compte existe déjà avec cet email', async () => {
    await doSignup(app, { nom: 'Dupont', prenom: 'Jean', email: 'jean.dupont@example.com', password: 'motdepasse' });

    const res = await request(app).post('/auth/request-email-code').send({ email: 'jean.dupont@example.com' });
    expect(res.status).toBe(409);
  });
});

describe('POST /auth/verify-email-code', () => {
  it('refuse un code incorrect', async () => {
    await request(app).post('/auth/request-email-code').send({ email: 'jean.dupont@example.com' });
    const res = await request(app).post('/auth/verify-email-code').send({ email: 'jean.dupont@example.com', code: '000000' });
    expect(res.status).toBe(400);
  });

  it('refuse un code quand aucune demande n\'a été faite', async () => {
    const res = await request(app).post('/auth/verify-email-code').send({ email: 'inconnu@example.com', code: '123456' });
    expect(res.status).toBe(400);
  });

  it('bloque après 5 tentatives incorrectes', async () => {
    await request(app).post('/auth/request-email-code').send({ email: 'jean.dupont@example.com' });
    for (let i = 0; i < 5; i++) {
      await request(app).post('/auth/verify-email-code').send({ email: 'jean.dupont@example.com', code: '000000' });
    }
    const res = await request(app).post('/auth/verify-email-code').send({ email: 'jean.dupont@example.com', code: '000000' });
    expect(res.status).toBe(429);
  });

  it('renvoie un ticket de vérification pour un code correct', async () => {
    const codeRes = await request(app).post('/auth/request-email-code').send({ email: 'jean.dupont@example.com' });
    const res = await request(app)
      .post('/auth/verify-email-code')
      .send({ email: 'jean.dupont@example.com', code: codeRes.body.code });
    expect(res.status).toBe(200);
    expect(res.body.verificationTicket).toBeTruthy();
  });
});

describe('POST /auth/signup-interne', () => {
  it('crée un compte chargé d\'affaires en attente de validation par un admin', async () => {
    const res = await request(app).post('/auth/signup-interne').send({
      nom: 'Bernard', prenom: 'Julien', mobile: '0611223344', email: 'j.bernard@actiwork.fr',
      password: 'motdepasse', role: 'chargeAffaires',
    });

    expect(res.status).toBe(201);
    expect(res.body.user.role).toBe('chargeAffaires');
    expect(res.body.user.isActive).toBe(false);
    expect(res.body.accessToken).toBeTruthy();
  });

  it('refuse un email hors domaine @actiwork.fr', async () => {
    const res = await request(app).post('/auth/signup-interne').send({
      nom: 'Bernard', prenom: 'Julien', mobile: '0611223344', email: 'j.bernard@gmail.com',
      password: 'motdepasse', role: 'qualite',
    });
    expect(res.status).toBe(400);
  });

  it('refuse un rôle qui ne correspond pas à un compte interne', async () => {
    const res = await request(app).post('/auth/signup-interne').send({
      nom: 'Bernard', prenom: 'Julien', mobile: '0611223344', email: 'j.bernard@actiwork.fr',
      password: 'motdepasse', role: 'admin',
    });
    expect(res.status).toBe(400);
  });
});

describe('POST /auth/login', () => {
  beforeEach(async () => {
    await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });
  });

  it('connecte avec le mobile même formaté avec des espaces', async () => {
    const res = await request(app).post('/auth/login').send({
      identifier: '06 52 41 78 90',
      password: 'demodemo',
    });
    expect(res.status).toBe(200);
    expect(res.body.user.mobile).toBe('0652417890');
  });

  it('connecte avec l\'email', async () => {
    const res = await request(app).post('/auth/login').send({
      identifier: 't.roux@elevpro.fr',
      password: 'demodemo',
    });
    expect(res.status).toBe(200);
  });

  it('refuse un mauvais mot de passe', async () => {
    const res = await request(app).post('/auth/login').send({
      identifier: 't.roux@elevpro.fr',
      password: 'mauvais',
    });
    expect(res.status).toBe(401);
  });
});

describe('Comptes suspendus', () => {
  it('refuse la connexion d\'un compte suspendu', async () => {
    const signup = await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });
    await prisma.user.update({ where: { id: signup.body.user.id }, data: { suspendu: true } });

    const res = await request(app).post('/auth/login').send({ identifier: 't.roux@elevpro.fr', password: 'demodemo' });
    expect(res.status).toBe(403);
  });

  it('refuse le refresh d\'un compte suspendu après coup, avant l\'expiration du refresh token', async () => {
    const signup = await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });
    await prisma.user.update({ where: { id: signup.body.user.id }, data: { suspendu: true } });

    const res = await request(app).post('/auth/refresh').send({ refreshToken: signup.body.refreshToken });
    expect(res.status).toBe(401);
  });
});

describe('GET /auth/me', () => {
  it('refuse sans jeton', async () => {
    const res = await request(app).get('/auth/me');
    expect(res.status).toBe(401);
  });

  it('renvoie le profil avec un jeton valide', async () => {
    const signup = await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });
    const res = await request(app).get('/auth/me').set('Authorization', `Bearer ${signup.body.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.user.fullName).toBe('Thomas Roux');
  });
});

describe('POST /auth/refresh', () => {
  it('émet un nouveau jeton d\'accès à partir du refresh token', async () => {
    const signup = await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });
    const res = await request(app).post('/auth/refresh').send({ refreshToken: signup.body.refreshToken });
    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeTruthy();
  });

  it('refuse un refresh token invalide', async () => {
    const res = await request(app).post('/auth/refresh').send({ refreshToken: 'invalide' });
    expect(res.status).toBe(401);
  });
});

describe('Mot de passe oublié', () => {
  it('envoie un code et le renvoie en clair en environnement de test', async () => {
    await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });

    const res = await request(app).post('/auth/request-password-reset').send({ email: 't.roux@elevpro.fr' });
    expect(res.status).toBe(200);
    expect(res.body.sent).toBe(true);
    expect(res.body.code).toMatch(/^\d{6}$/);
  });

  it('renvoie succès sans code pour un email inconnu (ne révèle rien)', async () => {
    const res = await request(app).post('/auth/request-password-reset').send({ email: 'inconnu@example.com' });
    expect(res.status).toBe(200);
    expect(res.body.sent).toBe(true);
    expect(res.body.code).toBeUndefined();
  });

  it('réinitialise le mot de passe avec le bon code puis connecte avec le nouveau', async () => {
    await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });
    const codeRes = await request(app).post('/auth/request-password-reset').send({ email: 't.roux@elevpro.fr' });

    const resetRes = await request(app).post('/auth/reset-password').send({
      email: 't.roux@elevpro.fr', code: codeRes.body.code, password: 'nouveaumdp',
    });
    expect(resetRes.status).toBe(204);

    const ancien = await request(app).post('/auth/login').send({ identifier: 't.roux@elevpro.fr', password: 'demodemo' });
    expect(ancien.status).toBe(401);

    const nouveau = await request(app).post('/auth/login').send({ identifier: 't.roux@elevpro.fr', password: 'nouveaumdp' });
    expect(nouveau.status).toBe(200);
  });

  it('refuse un code incorrect', async () => {
    await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });
    await request(app).post('/auth/request-password-reset').send({ email: 't.roux@elevpro.fr' });

    const res = await request(app).post('/auth/reset-password').send({
      email: 't.roux@elevpro.fr', code: '000000', password: 'nouveaumdp',
    });
    expect(res.status).toBe(400);
  });

  it('refuse un code expiré', async () => {
    const signup = await doSignup(app, {
      nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
    });
    const codeRes = await request(app).post('/auth/request-password-reset').send({ email: 't.roux@elevpro.fr' });
    await prisma.user.update({
      where: { id: signup.body.user.id },
      data: { resetPasswordExpires: new Date(Date.now() - 1000) },
    });

    const res = await request(app).post('/auth/reset-password').send({
      email: 't.roux@elevpro.fr', code: codeRes.body.code, password: 'nouveaumdp',
    });
    expect(res.status).toBe(400);
  });

  it('refuse une réinitialisation pour un email inconnu', async () => {
    const res = await request(app).post('/auth/reset-password').send({
      email: 'inconnu@example.com', code: '123456', password: 'nouveaumdp',
    });
    expect(res.status).toBe(400);
  });
});
