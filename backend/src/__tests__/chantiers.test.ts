import { describe, it, expect, beforeEach, afterAll, vi } from 'vitest';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import { PDFDocument } from 'pdf-lib';
import { put } from '@vercel/blob';
import { createApp } from '../app';
import { prisma } from '../prisma';
import { resetDb, signup as doSignup } from './helpers';

const ONE_PX_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
const SIGNATURE_PNG_DATA_URL = `data:image/png;base64,${ONE_PX_PNG_BASE64}`;

const app = createApp();

// Les endpoints n'acceptent plus le fichier en base64 : l'app le dépose
// d'abord directement sur Vercel Blob (voir routes/uploads.ts), puis
// transmet l'URL obtenue. En test, `put` est mocké (voir vitest.setup.ts) —
// l'appeler ici simule ce dépôt direct et alimente le même faux stockage que
// celui que relit `fetchBlobFile` (ex. pour la fusion du PV).
async function fakeUpload(filename: string, base64: string, contentType: string): Promise<string> {
  const uniqueFilename = `${Date.now()}-${Math.round(Math.random() * 1e6)}-${filename}`;
  const { url } = await put(uniqueFilename, Buffer.from(base64, 'base64'), { access: 'public', contentType });
  return url;
}

// Un vrai PDF valide est nécessaire depuis que la signature fusionne le
// gabarit côté serveur avec pdf-lib (voir pvMerge.ts) — contrairement à
// l'ancien flux, où le fichier reçu par /pv/signature n'était jamais
// réellement ouvert/parsé côté backend (déjà fusionné côté app).
async function minimalPdfFileUrl(): Promise<string> {
  const doc = await PDFDocument.create();
  doc.addPage([595, 842]);
  const bytes = await doc.save();
  return fakeUpload('gabarit.pdf', Buffer.from(bytes).toString('base64'), 'application/pdf');
}

async function createCt() {
  const passwordHash = await bcrypt.hash('demodemo', 10);
  const ct = await prisma.user.create({
    data: {
      nom: 'Martin', prenom: 'Sandrine', mobile: '0102030405', email: 's.martin@actiwork.fr',
      passwordHash, role: 'coordinateurTravaux', isActive: true,
    },
  });
  const login = await request(app).post('/auth/login').send({ identifier: 's.martin@actiwork.fr', password: 'demodemo' });
  return { user: ct, accessToken: login.body.accessToken as string };
}

async function createAdmin() {
  const passwordHash = await bcrypt.hash('demodemo', 10);
  const admin = await prisma.user.create({
    data: {
      nom: 'Lefebvre', prenom: 'Admin', mobile: '0102030407', email: 'admin@actiwork.fr',
      passwordHash, role: 'admin', isActive: true,
    },
  });
  const login = await request(app).post('/auth/login').send({ identifier: 'admin@actiwork.fr', password: 'demodemo' });
  return { user: admin, accessToken: login.body.accessToken as string };
}

async function createInstallateur(overrides: Partial<{ isActive: boolean; mobile: string }> = {}) {
  const signup = await doSignup(app, {
    nom: 'Roux', prenom: 'Thomas', mobile: overrides.mobile ?? '0652417890', email: 't.roux@elevpro.fr', password: 'demodemo',
  });
  if (overrides.isActive) {
    await prisma.user.update({ where: { id: signup.body.user.id }, data: { isActive: true } });
  }
  const login = await request(app).post('/auth/login').send({ identifier: 't.roux@elevpro.fr', password: 'demodemo' });
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
  it('un coordinateur travaux peut créer un chantier avec ses points de contrôle pré-remplis', async () => {
    const ct = await createCt();
    const res = await createChantier(ct.accessToken);

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
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const res = await createChantier(ct.accessToken);
    expect(res.status).toBe(409);
  });
});

describe('GET /chantiers — rattachement (EX-04)', () => {
  it("un installateur non rattaché ne voit aucun chantier", async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await createInstallateur({ isActive: true });

    const res = await request(app).get('/chantiers').set('Authorization', `Bearer ${installateur.accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.chantiers).toHaveLength(0);
  });

  it('un installateur rattaché voit le chantier ; le CT voit tout', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await createInstallateur({ isActive: true });

    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ userId: installateur.user.id });

    const asInstallateur = await request(app).get('/chantiers').set('Authorization', `Bearer ${installateur.accessToken}`);
    expect(asInstallateur.body.chantiers).toHaveLength(1);
    expect(asInstallateur.body.chantiers[0].installateursRattaches[0].id).toBe(installateur.user.id);

    const asCt = await request(app).get('/chantiers').set('Authorization', `Bearer ${ct.accessToken}`);
    expect(asCt.body.chantiers).toHaveLength(1);
  });
});

describe('Progression et modules', () => {
  it('coche un point de contrôle et met à jour la progression', async () => {
    const ct = await createCt();
    const created = await createChantier(ct.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;

    const patch = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ status: 'conforme', photoPath: 'photo.jpg' });
    expect(patch.status).toBe(200);

    const res = await request(app).get('/chantiers/LD64397').set('Authorization', `Bearer ${ct.accessToken}`);
    expect(res.body.chantier.progressionReception).toBeCloseTo(1 / 5);
  });

  it("génère l'auto-contrôle avec des catégories et des points de sécurité critiques", async () => {
    const ct = await createCt();
    const created = await createChantier(ct.accessToken);
    const autoControle = created.body.chantier.autoControle as { categorie: string; critique: boolean }[];

    expect(autoControle.some((p) => p.categorie === 'Portes palières' && p.critique)).toBe(true);
    expect(autoControle.every((p) => p.categorie && typeof p.critique === 'boolean')).toBe(true);
  });

  it('horodate et attribue nominativement la validation d\'un point au compte connecté', async () => {
    const ct = await createCt();
    const created = await createChantier(ct.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;
    const clientValidatedAt = '2026-07-23T08:15:00.000Z';

    const patch = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ status: 'conforme', photoPath: 'photo.jpg', clientValidatedAt });

    expect(patch.status).toBe(200);
    expect(patch.body.point.validePar).toBe('Sandrine Martin');
    expect(patch.body.point.valideAt).toBe(clientValidatedAt);
  });

  it("enregistre la photo d'un point de contrôle sur le stockage distant et renvoie son URL", async () => {
    const ct = await createCt();
    const created = await createChantier(ct.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;

    const photoUrl = await fakeUpload(`point-${pointId}.jpg`, ONE_PX_PNG_BASE64, 'image/jpeg');
    const patch = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ status: 'conforme', photoUrl });

    expect(patch.status).toBe(200);
    expect(patch.body.point.photoPath).toBe(photoUrl);
  });

  // Emplacement quelconque, valide pour une page A4 (595 x 842 pts) — voir
  // minimalPdfFileUrl (échelle module, tout en haut du fichier).
  const SIGNATURE_PLACEMENT = { pageNumber: 1, x: 350, y: 80, width: 180, height: 70 };

  it('le CT dépose le gabarit PV — ne le valide pas', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/pv/document')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ fileUrl: await minimalPdfFileUrl() });

    expect(res.status).toBe(200);
    expect(res.body.chantier.pvPdfPath).toBeTruthy();
    expect(res.body.chantier.pvSigne).toBe(false);
  });

  it('l\'installateur signe le PV déposé par le CT, avec la seule image de la signature', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await createInstallateur({ isActive: true });
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ userId: installateur.user.id });

    await request(app)
      .post('/chantiers/LD64397/pv/document')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ fileUrl: await minimalPdfFileUrl() });

    const res = await request(app)
      .post('/chantiers/LD64397/pv/signature')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ nomSignataire: 'M. Weber', fonctionSignataire: 'Client', signatureImage: SIGNATURE_PNG_DATA_URL, ...SIGNATURE_PLACEMENT });

    expect(res.status).toBe(200);
    expect(res.body.chantier.pvSigne).toBe(true);
    expect(res.body.chantier.pvSigneur).toBe('M. Weber');
    expect(res.body.chantier.pvFonctionSignataire).toBe('Client');
  });

  it('refuse de re-signer un PV déjà signé — seule une suppression par le CT/Admin déverrouille', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await createInstallateur({ isActive: true });
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ userId: installateur.user.id });
    await request(app)
      .post('/chantiers/LD64397/pv/document')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ fileUrl: await minimalPdfFileUrl() });
    await request(app)
      .post('/chantiers/LD64397/pv/signature')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ nomSignataire: 'M. Weber', fonctionSignataire: 'Client', signatureImage: SIGNATURE_PNG_DATA_URL, ...SIGNATURE_PLACEMENT });

    const second = await request(app)
      .post('/chantiers/LD64397/pv/signature')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ nomSignataire: 'Un autre', fonctionSignataire: 'Responsable technique', signatureImage: SIGNATURE_PNG_DATA_URL, ...SIGNATURE_PLACEMENT });
    expect(second.status).toBe(400);

    // La suppression par le CT repasse pvSigne à false : la signature redevient possible.
    await request(app).delete('/chantiers/LD64397/pv').set('Authorization', `Bearer ${ct.accessToken}`);
    await request(app)
      .post('/chantiers/LD64397/pv/document')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ fileUrl: await minimalPdfFileUrl() });
    const third = await request(app)
      .post('/chantiers/LD64397/pv/signature')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ nomSignataire: 'Un autre', fonctionSignataire: 'Responsable technique', signatureImage: SIGNATURE_PNG_DATA_URL, ...SIGNATURE_PLACEMENT });
    expect(third.status).toBe(200);
    expect(third.body.chantier.pvSigneur).toBe('Un autre');
  }, 30000);

  it('refuse de signer si le CT n\'a pas encore déposé de gabarit', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await createInstallateur({ isActive: true });
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ userId: installateur.user.id });

    const res = await request(app)
      .post('/chantiers/LD64397/pv/signature')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ nomSignataire: 'M. Weber', fonctionSignataire: 'Client', signatureImage: SIGNATURE_PNG_DATA_URL, ...SIGNATURE_PLACEMENT });
    expect(res.status).toBe(400);
  }, 30000);

  it('enregistre le PDF fusionné sur le stockage distant et renvoie son URL', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await createInstallateur({ isActive: true });
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ userId: installateur.user.id });
    await request(app)
      .post('/chantiers/LD64397/pv/document')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ fileUrl: await minimalPdfFileUrl() });

    const res = await request(app)
      .post('/chantiers/LD64397/pv/signature')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ nomSignataire: 'M. Weber', fonctionSignataire: 'Client', signatureImage: SIGNATURE_PNG_DATA_URL, ...SIGNATURE_PLACEMENT });

    expect(res.status).toBe(200);
    const imagePath = res.body.chantier.pvSignatureImagePath as string;
    expect(imagePath).toMatch(/^https:\/\/teststoreid\.public\.blob\.vercel-storage\.com\/test\/pv-signe-.+\.pdf$/);
  }, 30000);
});

describe('POST /chantiers/:reference/pv/reponses (formulaire PV interactif)', () => {
  const REPONSES_MINIMALES = {
    identite: { maitreOeuvre: 'SCI Duval', operation: 'Rénovation', lot: 'Lot 4' },
    receptionInstallation: [{ id: '1.1', reponse: 'oui', observation: null }],
    documentsRemis: [{ id: '2.1', reponse: 'non', observation: 'À transmettre plus tard' }],
    servicesSupplementaires: [{ id: '3.1', reponse: 'non', observation: null }],
    natureDePose: ['Monte-charge accompagné'],
    quantite: '1',
    reserves: 'Grincement rail gauche',
    remarques: 'RAS en dehors des réserves.',
    temoignageClient: 'Équipe professionnelle.',
  };

  async function rattacherInstallateur(ctToken: string) {
    const installateur = await createInstallateur({ isActive: true });
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ctToken}`)
      .send({ userId: installateur.user.id });
    return installateur;
  }

  it('génère le PDF, verrouille le PV et enregistre les réponses', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await rattacherInstallateur(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/pv/reponses')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({
        reponses: REPONSES_MINIMALES,
        dateReception: '2026-08-28',
        nomSignataire: 'M. Weber',
        fonctionSignataire: 'Client',
        signatureImage: SIGNATURE_PNG_DATA_URL,
      });

    expect(res.status).toBe(200);
    expect(res.body.chantier.pvSigne).toBe(true);
    expect(res.body.chantier.pvSigneur).toBe('M. Weber');
    expect(res.body.chantier.pvFonctionSignataire).toBe('Client');
    expect(res.body.chantier.pvSignatureImagePath).toMatch(/\.pdf$/);
  }, 60000);

  it('accepte des champs optionnels envoyés à null (comportement du client Flutter quand ils sont laissés vides)', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await rattacherInstallateur(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/pv/reponses')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({
        reponses: {
          ...REPONSES_MINIMALES,
          identite: { maitreOeuvre: null, operation: null, lot: null },
          quantite: null,
          reserves: null,
          remarques: null,
          temoignageClient: null,
        },
        dateReception: '2026-08-28',
        nomSignataire: 'M. Weber',
        fonctionSignataire: 'Client',
        signatureImage: SIGNATURE_PNG_DATA_URL,
      });

    expect(res.status).toBe(200);
    expect(res.body.chantier.pvSigne).toBe(true);
  }, 60000);

  it('refuse si le chantier utilise déjà le gabarit PDF (ancien flux)', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await rattacherInstallateur(ct.accessToken);
    await request(app)
      .post('/chantiers/LD64397/pv/document')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ fileUrl: await minimalPdfFileUrl() });

    const res = await request(app)
      .post('/chantiers/LD64397/pv/reponses')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({
        reponses: REPONSES_MINIMALES,
        dateReception: '2026-08-28',
        nomSignataire: 'M. Weber',
        fonctionSignataire: 'Client',
        signatureImage: SIGNATURE_PNG_DATA_URL,
      });
    expect(res.status).toBe(400);
  }, 60000);

  it('refuse de re-signer un PV déjà validé via le formulaire', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await rattacherInstallateur(ct.accessToken);
    const body = {
      reponses: REPONSES_MINIMALES,
      dateReception: '2026-08-28',
      nomSignataire: 'M. Weber',
      fonctionSignataire: 'Client',
      signatureImage: SIGNATURE_PNG_DATA_URL,
    };
    await request(app).post('/chantiers/LD64397/pv/reponses').set('Authorization', `Bearer ${installateur.accessToken}`).send(body);

    const second = await request(app)
      .post('/chantiers/LD64397/pv/reponses')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send(body);
    expect(second.status).toBe(400);
  }, 60000);

  it('rejette un rôle non installateur', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/pv/reponses')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({
        reponses: REPONSES_MINIMALES,
        dateReception: '2026-08-28',
        nomSignataire: 'M. Weber',
        fonctionSignataire: 'Client',
        signatureImage: SIGNATURE_PNG_DATA_URL,
      });
    expect(res.status).toBe(403);
  });
});

describe('POST /chantiers/:reference/rex', () => {
  it('accepte un REX texte seul (sans audio)', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ transcription: 'Tout s\'est bien passé.' });

    expect(res.status).toBe(200);
    expect(res.body.chantier.rex).toHaveLength(1);
    expect(res.body.chantier.rex[0].transcription).toBe('Tout s\'est bien passé.');
  });

  it('accepte une note vocale seule (sans transcription) et enregistre le fichier audio', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const audioUrl = await fakeUpload('rex.webm', ONE_PX_PNG_BASE64, 'audio/webm');

    const res = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ audioUrl });

    expect(res.status).toBe(200);
    expect(res.body.chantier.rex[0].transcription).toBeNull();
    expect(res.body.chantier.rex[0].audioPath).toBe(audioUrl);
  });

  // OPENAI_API_KEY est explicitement absente en test (voir vitest.setup.ts) —
  // ces deux tests la renseignent temporairement et interceptent l'appel
  // Whisper pour ne jamais faire de vrai appel réseau payant.
  async function withStubbedOpenAi<T>(openAiResponse: Response, run: () => Promise<T>): Promise<T> {
    const previousKey = process.env.OPENAI_API_KEY;
    const previousFetch = globalThis.fetch;
    process.env.OPENAI_API_KEY = 'test-openai-key';
    globalThis.fetch = vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
      const url = typeof input === 'string' ? input : input.toString();
      if (url === 'https://api.openai.com/v1/audio/transcriptions') return openAiResponse;
      return previousFetch(input, init);
    }) as typeof fetch;
    try {
      return await run();
    } finally {
      globalThis.fetch = previousFetch;
      if (previousKey === undefined) delete process.env.OPENAI_API_KEY;
      else process.env.OPENAI_API_KEY = previousKey;
    }
  }

  it('transcrit automatiquement la note vocale quand OPENAI_API_KEY est configurée', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const audioUrl = await fakeUpload('rex.webm', ONE_PX_PNG_BASE64, 'audio/webm');

    const res = await withStubbedOpenAi(
      new Response(JSON.stringify({ text: 'Tout est conforme, RAS.' }), { status: 200 }),
      () =>
        request(app)
          .post('/chantiers/LD64397/rex')
          .set('Authorization', `Bearer ${ct.accessToken}`)
          .send({ audioUrl }),
    );

    expect(res.status).toBe(200);
    expect(res.body.chantier.rex[0].transcription).toBe('Tout est conforme, RAS.');
  });

  it("n'empêche pas la création du REX si la transcription automatique échoue", async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const audioUrl = await fakeUpload('rex.webm', ONE_PX_PNG_BASE64, 'audio/webm');

    const res = await withStubbedOpenAi(new Response('erreur', { status: 500 }), () =>
      request(app)
        .post('/chantiers/LD64397/rex')
        .set('Authorization', `Bearer ${ct.accessToken}`)
        .send({ audioUrl }),
    );

    expect(res.status).toBe(200);
    expect(res.body.chantier.rex[0].transcription).toBeNull();
    expect(res.body.chantier.rex[0].audioPath).toBe(audioUrl);
  });

  it('refuse un REX sans transcription ni audio', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('autorise plusieurs REX sur le même chantier (l\'installateur a oublié quelque chose)', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ transcription: 'Premier REX.' });

    const res = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ transcription: 'Deuxième REX.' });
    expect(res.status).toBe(200);
    expect(res.body.chantier.rex).toHaveLength(2);
    expect(res.body.chantier.rex.map((r: { transcription: string }) => r.transcription).sort()).toEqual([
      'Deuxième REX.',
      'Premier REX.',
    ]);
  });
});

describe('DELETE /chantiers/:reference/rex/:rexId', () => {
  it('le CT supprime une entrée REX précise, sans affecter les autres', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ transcription: 'À corriger.' });
    const second = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ transcription: 'À garder.' });
    const rexId = second.body.chantier.rex.find((r: { transcription: string }) => r.transcription === 'À corriger.').id;

    const del = await request(app)
      .delete(`/chantiers/LD64397/rex/${rexId}`)
      .set('Authorization', `Bearer ${ct.accessToken}`);
    expect(del.status).toBe(200);
    expect(del.body.chantier.rex).toHaveLength(1);
    expect(del.body.chantier.rex[0].transcription).toBe('À garder.');
  });

  it('l\'Admin peut aussi supprimer une entrée REX', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const created = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ transcription: 'À corriger.' });
    const rexId = created.body.chantier.rex[0].id;

    const admin = await createAdmin();
    const del = await request(app)
      .delete(`/chantiers/LD64397/rex/${rexId}`)
      .set('Authorization', `Bearer ${admin.accessToken}`);
    expect(del.status).toBe(200);
    expect(del.body.chantier.rex).toHaveLength(0);
  });

  it('refuse à un installateur de supprimer une entrée REX', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const created = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ transcription: 'À corriger.' });
    const rexId = created.body.chantier.rex[0].id;

    const installateur = await createInstallateur({ isActive: true });
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ userId: installateur.user.id });

    const res = await request(app)
      .delete(`/chantiers/LD64397/rex/${rexId}`)
      .set('Authorization', `Bearer ${installateur.accessToken}`);
    expect(res.status).toBe(403);
  });

  it('renvoie 404 si l\'entrée REX n\'existe pas', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .delete('/chantiers/LD64397/rex/inexistant')
      .set('Authorization', `Bearer ${ct.accessToken}`);
    expect(res.status).toBe(404);
  });

  it('supprime aussi la note vocale associée', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const created = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ audioUrl: await fakeUpload('rex.webm', ONE_PX_PNG_BASE64, 'audio/webm') });
    const rexId = created.body.chantier.rex[0].id;

    const del = await request(app)
      .delete(`/chantiers/LD64397/rex/${rexId}`)
      .set('Authorization', `Bearer ${ct.accessToken}`);
    expect(del.status).toBe(200);
    expect(del.body.chantier.rex).toHaveLength(0);
  });
});

describe('DELETE /chantiers/:reference (suppression définitive, Admin uniquement)', () => {
  it('supprime le chantier ainsi que les fichiers de ses documents/REX/PV associés', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    await request(app)
      .post('/chantiers/LD64397/documents-chantier')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ type: 'securite', nom: 'PPSPS', fileUrl: await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png') });
    await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ audioUrl: await fakeUpload('rex.webm', ONE_PX_PNG_BASE64, 'audio/webm') });

    const admin = await createAdmin();
    const del = await request(app)
      .delete('/chantiers/LD64397')
      .set('Authorization', `Bearer ${admin.accessToken}`);
    expect(del.status).toBe(204);

    const get = await request(app).get('/chantiers/LD64397').set('Authorization', `Bearer ${admin.accessToken}`);
    expect(get.status).toBe(404);
  });

  it('refuse à un CT de supprimer un chantier', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .delete('/chantiers/LD64397')
      .set('Authorization', `Bearer ${ct.accessToken}`);
    expect(res.status).toBe(403);
  });
});

describe('POST /chantiers/:reference/documents', () => {
  it('dépose un document (photo) et enregistre le fichier sur le stockage distant', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const fileUrl = await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png');

    const res = await request(app)
      .post('/chantiers/LD64397/documents')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ titre: 'Bon de livraison', categorie: 'bonLivraison', fileUrl });

    expect(res.status).toBe(201);
    expect(res.body.document.categorie).toBe('bonLivraison');
    expect(res.body.document.filePath).toBe(fileUrl);
  });

  it('refuse un dépôt sans catégorie', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/documents')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ titre: 'Sans catégorie', fileUrl: await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png') });
    expect(res.status).toBe(400);
  });

  it('refuse un dépôt sans fichier', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/documents')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ titre: 'Sans fichier', categorie: 'constat' });
    expect(res.status).toBe(400);
  });

  // Le type de fichier est désormais restreint en amont, au moment de la
  // génération du jeton d'upload (voir routes/uploads.ts et son test dédié) —
  // cette route-ci ne fait plus que vérifier que l'URL fournie pointe
  // effectivement vers notre store Vercel Blob, pour empêcher qu'un client
  // fasse enregistrer une URL arbitraire comme si elle avait été déposée légitimement.
  it('refuse une URL de fichier qui ne pointe pas vers notre store Vercel Blob', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/documents')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ titre: 'Fichier suspect', categorie: 'constat', fileUrl: 'https://evil.example.com/malware.svg' });
    expect(res.status).toBe(400);
  });
});

describe('Sécurité — rattachement obligatoire pour un installateur (bug 3B)', () => {
  it('refuse à un installateur non rattaché de modifier un point de contrôle', async () => {
    const ct = await createCt();
    const created = await createChantier(ct.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;
    const etranger = await createInstallateur({ isActive: true });

    const res = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${etranger.accessToken}`)
      .send({ status: 'conforme' });
    expect(res.status).toBe(403);
  });

  it('refuse à un installateur non rattaché de soumettre un REX', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const etranger = await createInstallateur({ isActive: true });

    const res = await request(app)
      .post('/chantiers/LD64397/rex')
      .set('Authorization', `Bearer ${etranger.accessToken}`)
      .send({ transcription: 'Tentative non autorisée' });
    expect(res.status).toBe(403);
  });

  it('refuse à un installateur non rattaché de signer le PV', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    await request(app)
      .post('/chantiers/LD64397/pv/document')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ fileUrl: await fakeUpload('doc.pdf', ONE_PX_PNG_BASE64, 'application/pdf') });
    const etranger = await createInstallateur({ isActive: true });

    const res = await request(app)
      .post('/chantiers/LD64397/pv/signature')
      .set('Authorization', `Bearer ${etranger.accessToken}`)
      .send({ nomSignataire: 'Tentative', fonctionSignataire: 'Non autorisée', fileUrl: await fakeUpload('doc.pdf', ONE_PX_PNG_BASE64, 'application/pdf') });
    expect(res.status).toBe(403);
  });

  it('refuse à un installateur non rattaché de déposer un document', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const etranger = await createInstallateur({ isActive: true });

    const res = await request(app)
      .post('/chantiers/LD64397/documents')
      .set('Authorization', `Bearer ${etranger.accessToken}`)
      .send({ titre: 'Intrusion', categorie: 'constat', fileUrl: await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png') });
    expect(res.status).toBe(403);
  });

  it('autorise toujours un installateur bien rattaché à modifier un point', async () => {
    const ct = await createCt();
    const created = await createChantier(ct.accessToken);
    const pointId = created.body.chantier.receptionMarchandises[0].id;
    const installateur = await createInstallateur({ isActive: true });
    await request(app)
      .post('/chantiers/LD64397/rattacher')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ userId: installateur.user.id });

    const res = await request(app)
      .patch(`/chantiers/LD64397/points/${pointId}`)
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ status: 'conforme' });
    expect(res.status).toBe(200);
  });

  it('refuse à un installateur non rattaché de consulter le détail d\'un chantier (GET /:reference)', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const etranger = await createInstallateur({ isActive: true });

    const res = await request(app)
      .get('/chantiers/LD64397')
      .set('Authorization', `Bearer ${etranger.accessToken}`);
    expect(res.status).toBe(403);
  });

  it("refuse d'accéder à un point de contrôle appartenant à un autre chantier", async () => {
    const ct = await createCt();
    const chantierA = await createChantier(ct.accessToken, 'LD64397');
    await createChantier(ct.accessToken, 'LD91245');
    const pointDeA = chantierA.body.chantier.receptionMarchandises[0].id;

    const installateur = await createInstallateur({ isActive: true });
    // Rattaché à LD91245, mais pas à LD64397 — pointDeA appartient à LD64397.
    await request(app)
      .post('/chantiers/LD91245/rattacher')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ userId: installateur.user.id });

    const res = await request(app)
      .patch(`/chantiers/LD91245/points/${pointDeA}`)
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ status: 'conforme' });
    expect(res.status).toBe(404);
  });
});

describe("Rôles back-office — l'Admin a toutes les fonctionnalités du CT", () => {
  it("permet à l'Admin d'accéder à la liste des chantiers (super-CT, depuis la fusion des rôles)", async () => {
    const passwordHash = await bcrypt.hash('demodemo', 10);
    await prisma.user.create({
      data: {
        nom: 'Lefebvre', prenom: 'Admin', mobile: '0102030407', email: 'admin@actiwork.fr',
        passwordHash, role: 'admin', isActive: true,
      },
    });
    const login = await request(app).post('/auth/login').send({ identifier: 'admin@actiwork.fr', password: 'demodemo' });

    const res = await request(app).get('/chantiers').set('Authorization', `Bearer ${login.body.accessToken}`);
    expect(res.status).toBe(200);
  });
});

describe('POST /chantiers/:reference/documents-chantier (Modules 1-3)', () => {
  it('permet au CT de déposer un document de référence, lisible ensuite via GET', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const fileUrl = await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png');

    const res = await request(app)
      .post('/chantiers/LD64397/documents-chantier')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ type: 'securite', nom: 'PPSPS', fileUrl });

    expect(res.status).toBe(201);
    expect(res.body.chantier.documentsChantier).toHaveLength(1);
    expect(res.body.chantier.documentsChantier[0].type).toBe('securite');
    expect(res.body.chantier.documentsChantier[0].nom).toBe('PPSPS');
    expect(res.body.chantier.documentsChantier[0].filePath).toBe(fileUrl);

    const get = await request(app).get('/chantiers/LD64397').set('Authorization', `Bearer ${ct.accessToken}`);
    expect(get.body.chantier.documentsChantier).toHaveLength(1);
  });

  it('nommer le document est optionnel — le nom du fichier d\'origine fait l\'affaire', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const fileUrl = await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png');

    const res = await request(app)
      .post('/chantiers/LD64397/documents-chantier')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ type: 'securite', nomFichierOriginal: 'PPSPS_signe.pdf', fileUrl });

    expect(res.status).toBe(201);
    expect(res.body.chantier.documentsChantier[0].nom).toBe('PPSPS_signe.pdf');
  });

  it('refuse à un installateur de déposer un document de référence', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);
    const installateur = await createInstallateur({ isActive: true });

    const res = await request(app)
      .post('/chantiers/LD64397/documents-chantier')
      .set('Authorization', `Bearer ${installateur.accessToken}`)
      .send({ type: 'technique', nom: 'Plan', fileUrl: await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png') });
    expect(res.status).toBe(403);
  });

  it('refuse un type de document invalide', async () => {
    const ct = await createCt();
    await createChantier(ct.accessToken);

    const res = await request(app)
      .post('/chantiers/LD64397/documents-chantier')
      .set('Authorization', `Bearer ${ct.accessToken}`)
      .send({ type: 'autre', nom: 'PPSPS', fileUrl: await fakeUpload('doc.png', ONE_PX_PNG_BASE64, 'image/png') });
    expect(res.status).toBe(400);
  });
});
