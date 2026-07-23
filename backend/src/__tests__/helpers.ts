import { prisma } from '../prisma';

export async function resetDb() {
  await prisma.documentTerrain.deleteMany();
  await prisma.pointControle.deleteMany();
  await prisma.chantierInstallateur.deleteMany();
  await prisma.chantier.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.habilitation.deleteMany();
  await prisma.user.deleteMany();
}
