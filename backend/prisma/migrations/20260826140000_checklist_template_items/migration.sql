-- Listes de réception/contrôle éditables par l'Admin (renommer, ajouter,
-- supprimer des items) — remplace les tableaux en dur de checklistDefaults.ts,
-- appliqués désormais à la création de chaque nouveau chantier.
CREATE TABLE "ChecklistTemplateItem" (
    "id" TEXT NOT NULL,
    "type" "PointType" NOT NULL,
    "categorie" TEXT NOT NULL DEFAULT 'generale',
    "libelle" TEXT NOT NULL,
    "critique" BOOLEAN NOT NULL DEFAULT false,
    "ordre" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "ChecklistTemplateItem_pkey" PRIMARY KEY ("id")
);

-- Reprise des listes par défaut telles qu'elles existaient dans le code
-- (checklistDefaults.ts) — comportement inchangé tant que l'Admin ne modifie
-- rien depuis la nouvelle interface.
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-reception-0', 'reception', 'Réception', 'Réception point 1', false, 0);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-reception-1', 'reception', 'Réception', 'Réception point 2', false, 1);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-reception-2', 'reception', 'Réception', 'Réception point 3', false, 2);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-reception-3', 'reception', 'Réception', 'Réception point 4', false, 3);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-reception-4', 'reception', 'Réception', 'Réception point 5', false, 4);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-5', 'autoControle', 'Mécanique', 'Fixation du treuil et des poulies', false, 0);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-6', 'autoControle', 'Mécanique', 'Alignement des rails de guidage', false, 1);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-7', 'autoControle', 'Mécanique', 'Serrage des attaches de câbles', false, 2);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-8', 'autoControle', 'Mécanique', 'Niveau et aplomb de la structure', false, 3);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-9', 'autoControle', 'Portes palières', 'Verrouillage des portes palières', true, 4);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-10', 'autoControle', 'Portes palières', 'Serrures de gâches', true, 5);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-11', 'autoControle', 'Portes palières', 'Asservissement porte/cabine', true, 6);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-12', 'autoControle', 'Portes palières', 'Étanchéité des seuils de porte', false, 7);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-13', 'autoControle', 'Essais', 'Essai de charge nominale', false, 8);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-14', 'autoControle', 'Essais', 'Essai des fins de course', false, 9);
INSERT INTO "ChecklistTemplateItem" (id, type, categorie, libelle, critique, ordre) VALUES ('seed-autoControle-15', 'autoControle', 'Essais', 'Essai du dispositif d''arrêt d''urgence', true, 10);
