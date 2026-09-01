import { describe, it, expect, afterEach } from 'vitest';
import { isOwnBlobUrl } from '../lib/imageStorage';

// isOwnBlobUrl n'était couvert par AUCUN test avant ce fichier — voir le bug
// qu'il vient de corriger : le store id extrait de BLOB_READ_WRITE_TOKEN
// (index 3, format vercel_blob_rw_<storeId>_<secret>) peut contenir des
// majuscules (ex. store réel de prod : TA6DWgjnlXI8K52T, voir BLOB_STORE_ID),
// alors que `new URL(...).hostname` est TOUJOURS renvoyé en minuscules par la
// spec WHATWG URL. Sans normaliser les deux côtés à la même casse, la
// comparaison stricte rejetait TOUT fichier réellement déposé sur un store
// dont l'id contient une majuscule — 400 systématique, resté invisible tant
// que deux bugs antérieurs de la chaîne d'upload (RangeError, puis 403 MIME)
// empêchaient d'atteindre cette validation.
describe('isOwnBlobUrl', () => {
  const original = process.env.BLOB_READ_WRITE_TOKEN;
  afterEach(() => {
    process.env.BLOB_READ_WRITE_TOKEN = original;
  });

  it('accepte une URL réelle même quand le store id du jeton contient des majuscules (régression du bug de casse)', () => {
    process.env.BLOB_READ_WRITE_TOKEN = 'vercel_blob_rw_TA6DWgjnlXI8K52T_secret';
    expect(isOwnBlobUrl('https://ta6dwgjnlxi8k52t.public.blob.vercel-storage.com/x-abc123.pdf')).toBe(true);
  });

  it('accepte une URL dont le store id est déjà tout en minuscules', () => {
    process.env.BLOB_READ_WRITE_TOKEN = 'vercel_blob_rw_teststoreid_secret';
    expect(isOwnBlobUrl('https://teststoreid.public.blob.vercel-storage.com/x-abc123.pdf')).toBe(true);
  });

  it('refuse une URL pointant vers un autre store Blob (même suffixe de domaine)', () => {
    process.env.BLOB_READ_WRITE_TOKEN = 'vercel_blob_rw_teststoreid_secret';
    expect(isOwnBlobUrl('https://unautrestore.public.blob.vercel-storage.com/x.pdf')).toBe(false);
  });

  it('refuse un domaine arbitraire se faisant passer pour notre store', () => {
    process.env.BLOB_READ_WRITE_TOKEN = 'vercel_blob_rw_teststoreid_secret';
    expect(isOwnBlobUrl('https://teststoreid.public.blob.vercel-storage.com.evil.com/x.pdf')).toBe(false);
  });

  it('refuse une URL non https', () => {
    process.env.BLOB_READ_WRITE_TOKEN = 'vercel_blob_rw_teststoreid_secret';
    expect(isOwnBlobUrl('http://teststoreid.public.blob.vercel-storage.com/x.pdf')).toBe(false);
  });

  it('refuse une URL malformée sans lever', () => {
    process.env.BLOB_READ_WRITE_TOKEN = 'vercel_blob_rw_teststoreid_secret';
    expect(isOwnBlobUrl('pas-une-url')).toBe(false);
  });

  it('refuse toute URL si BLOB_READ_WRITE_TOKEN est absent', () => {
    delete process.env.BLOB_READ_WRITE_TOKEN;
    expect(isOwnBlobUrl('https://teststoreid.public.blob.vercel-storage.com/x.pdf')).toBe(false);
  });
});
