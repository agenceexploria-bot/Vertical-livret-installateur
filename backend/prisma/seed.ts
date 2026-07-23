import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import { RECEPTION_POINTS, AUTO_CONTROLE_POINTS } from '../src/lib/checklistDefaults';

const prisma = new PrismaClient();

async function main() {
  const password = await bcrypt.hash('demodemo', 10);

  const thomas = await prisma.user.upsert({
    where: { mobile: '0652417890' },
    update: {},
    create: {
      nom: 'Roux',
      prenom: 'Thomas',
      mobile: '0652417890',
      email: 't.roux@elevpro.fr',
      passwordHash: password,
      role: 'installateur',
      status: 'sousTraitant',
      societe: "Elev'Pro",
      isActive: true,
      habilitations: {
        create: [
          { titre: 'Habilitation électrique BR', dateExpiration: new Date('2027-03-12') },
          { titre: 'Travail en hauteur', dateExpiration: new Date('2026-08-30') },
        ],
      },
    },
  });

  const diallo = await prisma.user.upsert({
    where: { mobile: '0670112233' },
    update: {},
    create: {
      nom: 'Diallo',
      prenom: 'Karim',
      mobile: '0670112233',
      email: 'k.diallo@vertical.fr',
      passwordHash: password,
      role: 'installateur',
      status: 'salarie',
      isActive: true,
      habilitations: { create: [{ titre: 'Habilitation électrique BR', dateExpiration: new Date('2027-01-10') }] },
    },
  });

  const costa = await prisma.user.upsert({
    where: { mobile: '0681223344' },
    update: {},
    create: {
      nom: 'Costa',
      prenom: 'Mario',
      mobile: '0681223344',
      email: 'm.costa@vertical.fr',
      passwordHash: password,
      role: 'installateur',
      status: 'salarie',
      isActive: true,
      habilitations: { create: [{ titre: 'Habilitation électrique BR', dateExpiration: new Date('2026-08-04') }] },
    },
  });

  await prisma.user.upsert({
    where: { mobile: '0692334455' },
    update: {},
    create: {
      nom: 'Petit',
      prenom: 'Julie',
      mobile: '0692334455',
      email: 'j.petit@levtech.fr',
      passwordHash: password,
      role: 'installateur',
      status: 'sousTraitant',
      societe: 'LevTech',
      isActive: true,
      suspendu: true,
    },
  });

  await prisma.user.upsert({
    where: { mobile: '0102030405' },
    update: {},
    create: {
      nom: 'Martin',
      prenom: 'Sandrine',
      mobile: '0102030405',
      email: 's.martin@actiwork.fr',
      passwordHash: password,
      role: 'chargeAffaires',
      isActive: true,
    },
  });

  await prisma.user.upsert({
    where: { mobile: '0102030406' },
    update: {},
    create: {
      nom: 'Dupuis',
      prenom: 'Quentin',
      mobile: '0102030406',
      email: 'q.dupuis@actiwork.fr',
      passwordHash: password,
      role: 'qualite',
      isActive: true,
    },
  });

  await prisma.user.upsert({
    where: { mobile: '0102030407' },
    update: {},
    create: {
      nom: 'Lefebvre',
      prenom: 'Admin',
      mobile: '0102030407',
      email: 'admin@actiwork.fr',
      passwordHash: password,
      role: 'admin',
      isActive: true,
    },
  });

  const chantier1 = await prisma.chantier.upsert({
    where: { reference: 'LD64397' },
    update: {},
    create: {
      reference: 'LD64397',
      client: 'Costockage',
      adresse: '4 rue des Frères Lumière',
      ville: 'Meyzieu (69)',
      dateDebut: new Date('2026-07-21'),
      dateFin: new Date('2026-07-23'),
      contactNom: 'M. Weber',
      contactTel: '0612345678',
      horaires: '6h30-17h00',
      consignes: JSON.stringify([
        "Badge obligatoire à l'accueil",
        'Casque et chaussures de sécurité S3',
        'Gilet haute visibilité allée B',
      ]),
      typeMonteCharge: 'Monte-charge non accompagné',
      capacite: '300 kg',
      niveaux: 2,
      referenceAffaire: 'AF-2026-001',
      syncStatus: 'charge',
      pointsControle: {
        create: [...RECEPTION_POINTS, ...AUTO_CONTROLE_POINTS],
      },
      installateurs: { create: [{ userId: thomas.id }, { userId: costa.id }] },
    },
  });

  await prisma.chantier.upsert({
    where: { reference: 'LD91245' },
    update: {},
    create: {
      reference: 'LD91245',
      client: 'Transgourmet Ouest',
      adresse: '12 avenue des Landes',
      ville: 'Saint-Herblain (44)',
      dateDebut: new Date('2026-08-04'),
      dateFin: new Date('2026-08-05'),
      contactNom: 'Contact Transgourmet',
      contactTel: '0200000000',
      horaires: '8h00-18h00',
      consignes: JSON.stringify(['Consignes standard']),
      typeMonteCharge: 'Monte-charge accompagné',
      capacite: '500 kg',
      niveaux: 3,
      referenceAffaire: 'AF-2026-042',
      pointsControle: {
        create: [...RECEPTION_POINTS, ...AUTO_CONTROLE_POINTS],
      },
    },
  });

  console.log('Seed terminé.', { thomas: thomas.id, diallo: diallo.id, chantier1: chantier1.id });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
