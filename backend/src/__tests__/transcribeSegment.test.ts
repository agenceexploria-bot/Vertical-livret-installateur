import { describe, it, expect, beforeEach, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb, signup as doSignup, withStubbedTranscription, GROQ_TRANSCRIPTION_URL } from './helpers';

const app = createApp();

async function createInstallateurToken() {
  const signup = await doSignup(app, {
    nom: 'Roux', prenom: 'Thomas', mobile: '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
  });
  return signup.body.accessToken as string;
}

const ONE_PX_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

beforeEach(async () => {
  await resetDb();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe('POST /transcribe-segment', () => {
  it('refuse une requête non authentifiée', async () => {
    const res = await request(app)
      .post('/transcribe-segment')
      .send({ audio: `data:audio/webm;base64,${ONE_PX_PNG_BASE64}` });
    expect(res.status).toBe(401);
  });

  it('refuse un corps sans champ audio', async () => {
    const token = await createInstallateurToken();
    const res = await request(app).post('/transcribe-segment').set('Authorization', `Bearer ${token}`).send({});
    expect(res.status).toBe(400);
  });

  it('refuse une valeur qui n\'est pas une data URL valide', async () => {
    const token = await createInstallateurToken();
    const res = await request(app)
      .post('/transcribe-segment')
      .set('Authorization', `Bearer ${token}`)
      .send({ audio: 'pas-une-data-url' });
    expect(res.status).toBe(400);
  });

  it('transcrit le segment via Groq et renvoie le texte', async () => {
    const token = await createInstallateurToken();

    const res = await withStubbedTranscription(
      'GROQ_API_KEY',
      GROQ_TRANSCRIPTION_URL,
      new Response(JSON.stringify({ text: 'Tout est conforme.' }), { status: 200 }),
      () =>
        request(app)
          .post('/transcribe-segment')
          .set('Authorization', `Bearer ${token}`)
          .send({ audio: `data:audio/webm;base64,${ONE_PX_PNG_BASE64}` }),
    );

    expect(res.status).toBe(200);
    expect(res.body.text).toBe('Tout est conforme.');
  });

  it('renvoie text: null (pas une erreur HTTP) quand la transcription est désactivée (GROQ_API_KEY absente)', async () => {
    const token = await createInstallateurToken();
    const res = await request(app)
      .post('/transcribe-segment')
      .set('Authorization', `Bearer ${token}`)
      .send({ audio: `data:audio/webm;base64,${ONE_PX_PNG_BASE64}` });

    expect(res.status).toBe(200);
    expect(res.body.text).toBeNull();
  });

  it('renvoie text: null (pas une erreur HTTP) quand Groq refuse la requête', async () => {
    const token = await createInstallateurToken();
    const res = await withStubbedTranscription('GROQ_API_KEY', GROQ_TRANSCRIPTION_URL, new Response('erreur', { status: 500 }), () =>
      request(app)
        .post('/transcribe-segment')
        .set('Authorization', `Bearer ${token}`)
        .send({ audio: `data:audio/webm;base64,${ONE_PX_PNG_BASE64}` }),
    );

    expect(res.status).toBe(200);
    expect(res.body.text).toBeNull();
  });
});
