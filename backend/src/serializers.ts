import { Chantier, ChantierInstallateur, DocumentChantier, DocumentTerrain, Habilitation, PointControle, User } from '@prisma/client';
import { isPointComplete } from './lib/pointControleStatus';

export function serializeUser(user: User & { habilitations?: Habilitation[] }) {
  return {
    id: user.id,
    nom: user.nom,
    prenom: user.prenom,
    fullName: `${user.prenom} ${user.nom}`,
    mobile: user.mobile,
    email: user.email,
    role: user.role,
    status: user.status,
    societe: user.societe,
    avatarUrl: user.avatarUrl,
    isActive: user.isActive,
    suspendu: user.suspendu,
    habilitations: (user.habilitations ?? []).map(serializeHabilitation),
  };
}

export function serializeHabilitation(h: Habilitation) {
  return { id: h.id, titre: h.titre, dateExpiration: h.dateExpiration, filePath: h.filePath };
}

export function serializePointControle(p: PointControle) {
  return {
    id: p.id,
    type: p.type,
    libelle: p.libelle,
    categorie: p.categorie,
    critique: p.critique,
    photoRequise: p.photoRequise,
    status: p.status,
    photoPath: p.photoPath,
    validePar: p.validePar,
    valideAt: p.valideAt,
    ordre: p.ordre,
  };
}

export function serializeDocumentTerrain(d: DocumentTerrain & { auteur?: User }) {
  return {
    id: d.id,
    titre: d.titre,
    categorie: d.categorie,
    filePath: d.filePath,
    horodatage: d.horodatage,
    auteur: d.auteur ? `${d.auteur.prenom} ${d.auteur.nom}` : undefined,
    auteurId: d.auteurId,
  };
}

export function serializeDocumentChantier(d: DocumentChantier) {
  return {
    id: d.id,
    type: d.type,
    nom: d.nom,
    nomFichierOriginal: d.nomFichierOriginal,
    filePath: d.filePath,
    createdAt: d.createdAt,
  };
}

export function serializeChantier(
  c: Chantier & {
    pointsControle?: PointControle[];
    installateurs?: (ChantierInstallateur & { user: User })[];
    documentsTerrain?: (DocumentTerrain & { auteur: User })[];
    documentsChantier?: DocumentChantier[];
    chargeAffaires?: User | null;
  },
) {
  const reception = (c.pointsControle ?? []).filter((p) => p.type === 'reception');
  const autoControle = (c.pointsControle ?? []).filter((p) => p.type === 'autoControle');

  return {
    reference: c.reference,
    client: c.client,
    adresse: c.adresse,
    ville: c.ville,
    dateDebut: c.dateDebut,
    dateFin: c.dateFin,
    contactNom: c.contactNom,
    contactTel: c.contactTel,
    horaires: c.horaires,
    consignes: JSON.parse(c.consignes) as string[],
    typeMonteCharge: c.typeMonteCharge,
    capacite: c.capacite,
    niveaux: c.niveaux,
    referenceAffaire: c.referenceAffaire,
    chargeAffairesId: c.chargeAffairesId,
    chargeAffairesNom: c.chargeAffaires ? `${c.chargeAffaires.prenom} ${c.chargeAffaires.nom}` : null,
    syncStatus: c.syncStatus,
    rexValide: c.rexValide,
    rexTranscription: c.rexTranscription,
    rexAudioPath: c.rexAudioPath,
    pvPdfPath: c.pvPdfPath,
    pvSigne: c.pvSigne,
    pvSigneur: c.pvSigneur,
    pvFonctionSignataire: c.pvFonctionSignataire,
    pvSigneAt: c.pvSigneAt,
    pvSignatureImagePath: c.pvSignatureImagePath,
    livretsOuverts: JSON.parse(c.livretsOuvertsJson) as string[],
    receptionMarchandises: reception.map(serializePointControle),
    autoControle: autoControle.map(serializePointControle),
    progressionReception: reception.length === 0 ? 0 : reception.filter(isPointComplete).length / reception.length,
    progressionAutoControle: autoControle.length === 0 ? 0 : autoControle.filter(isPointComplete).length / autoControle.length,
    installateursRattaches: (c.installateurs ?? []).map((r) => serializeUser(r.user)),
    docsTerrain: (c.documentsTerrain ?? []).map((d) => serializeDocumentTerrain({ ...d, auteur: d.auteur })),
    documentsChantier: (c.documentsChantier ?? []).map(serializeDocumentChantier),
  };
}
