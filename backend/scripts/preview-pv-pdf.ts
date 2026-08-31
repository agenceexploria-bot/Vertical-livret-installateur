// Script ponctuel de vérification visuelle — génère un PDF PV d'exemple sans
// dépendre de la base de données, pour contrôler la mise en page. Usage :
// npx tsx scripts/preview-pv-pdf.ts (écrit /tmp equivalent puis à supprimer).
import { writeFileSync } from 'node:fs';
import { genererPdfPvFormulaire } from '../src/lib/pvFormPdf';
import { VERTICAL_LOGO_PNG_BASE64 } from '../src/lib/verticalLogoPng';

// Réutilise le logo comme substitut de signature pour ce test de mise en
// page (seule la géométrie/l'échelle nous intéresse ici, pas le contenu réel).
const fakeSignaturePng = () => Buffer.from(VERTICAL_LOGO_PNG_BASE64, 'base64');

async function main() {
  const bytes = await genererPdfPvFormulaire({
    chantier: {
      reference: 'LD64397',
      client: 'SCI Les Tilleuls',
      adresse: '12 rue de la Paix, 75002 Paris',
      referenceAffaire: 'AFF-2026-0042',
      contactNom: 'Mme Dubois',
    },
    reponses: {
      identite: { maitreOeuvre: 'Cabinet Architecte Martin', operation: 'Réhabilitation lot ascenseur', lot: 'Lot 12 — Monte-charge' },
      receptionInstallation: [
        { id: '1.1', reponse: 'oui', observation: null },
        { id: '1.2', reponse: 'oui', observation: null },
        { id: '1.3', reponse: 'non', observation: 'Le mode secours déclenche un bruit anormal, intervention prévue sous 48h.' },
        { id: '1.4', reponse: 'oui', observation: null },
      ],
      documentsRemis: [
        { id: '2.1', reponse: 'oui', observation: null },
        { id: '2.2', reponse: 'oui', observation: null },
        { id: '2.3', reponse: 'oui', observation: null },
        { id: '2.4', reponse: 'non', observation: 'À transmettre par email la semaine prochaine.' },
        { id: '2.5', reponse: 'oui', observation: null },
      ],
      servicesSupplementaires: [{ id: '3.1', reponse: 'oui', observation: null }],
      natureDePose: ['Monte-charge accompagné', 'Autre (habillage…)'],
      quantite: '1',
      reserves: "Grincement léger au niveau du rail gauche en position haute — à surveiller lors de la prochaine visite d'entretien.",
      remarques: "RAS en dehors des réserves mentionnées ci-dessus. L'installation est conforme au plan d'exécution fourni.",
      temoignageClient: "Équipe très professionnelle, chantier propre, délais respectés. Nous recommandons Vertical sans hésiter.",
    },
    dateReception: new Date('2026-08-28'),
    nomSignataire: 'M. Weber',
    fonctionSignataire: 'Directeur technique',
    signaturePngBytes: fakeSignaturePng(),
  });
  writeFileSync('preview-pv.pdf', bytes);
  console.log(`PDF généré : ${bytes.byteLength} bytes -> backend/preview-pv.pdf`);
}

main();
