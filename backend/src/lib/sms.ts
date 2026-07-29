// Numéro déjà au format E.164 (international, valable pour tous les pays) :
// "+" suivi de l'indicatif pays puis du numéro national.
const E164_REGEX = /^\+[1-9]\d{7,14}$/;

// Format local français historique (ex. "0652417890", voir normalizeMobile
// dans auth.ts) — conservé pour ne pas casser les comptes créés avant
// l'ouverture à l'international.
const FR_LOCAL_REGEX = /^0\d{9}$/;

export function isValidMobileInput(value: string): boolean {
  return E164_REGEX.test(value) || FR_LOCAL_REGEX.test(value);
}

// Retire la mise en forme (espaces, tirets, parenthèses...) d'un numéro saisi
// par un utilisateur, en préservant le "+" de tête s'il est présent.
export function normalizePhoneInput(value: string): string {
  const trimmed = value.trim();
  const digits = trimmed.replace(/\D/g, '');
  return trimmed.startsWith('+') ? `+${digits}` : digits;
}

export const MOBILE_FORMAT_ERROR =
  "Numéro de mobile invalide — veuillez le saisir avec l'indicatif pays au format international (ex : +33612345678, +237677123456).";
