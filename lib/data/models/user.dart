enum UserRole { installateur, coordinateurTravaux, qualite, direction, admin }
enum UserStatus { salarie, sousTraitant }

UserRole userRoleFromJson(String value) => UserRole.values.firstWhere((r) => r.name == value);
UserStatus? userStatusFromJson(String? value) =>
    value == null ? null : UserStatus.values.firstWhere((s) => s.name == value);

class Habilitation {
  final String? id;
  final String titre;
  final DateTime dateExpiration;
  final String? filePath;

  Habilitation({
    this.id,
    required this.titre,
    required this.dateExpiration,
    this.filePath,
  });

  bool get isExpired => dateExpiration.isBefore(DateTime.now());
  bool get expiresSoon => dateExpiration.isBefore(DateTime.now().add(const Duration(days: 30)));

  factory Habilitation.fromJson(Map<String, dynamic> json) => Habilitation(
        id: json['id'] as String?,
        titre: json['titre'] as String,
        dateExpiration: DateTime.parse(json['dateExpiration'] as String),
        filePath: json['filePath'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titre': titre,
        'dateExpiration': dateExpiration.toIso8601String(),
        'filePath': filePath,
      };
}

class User {
  final String id;
  final String nom;
  final String prenom;
  final String? mobile;
  final String? email;
  final UserRole role;
  final UserStatus? status;
  final String? societe;
  final String? avatarUrl;
  final List<Habilitation> habilitations;
  final bool isActive;
  final bool suspendu;

  User({
    required this.id,
    required this.nom,
    required this.prenom,
    this.mobile,
    this.email,
    required this.role,
    this.status,
    this.societe,
    this.avatarUrl,
    this.habilitations = const [],
    this.isActive = true,
    this.suspendu = false,
  });

  String get fullName => '$prenom $nom';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        nom: json['nom'] as String,
        prenom: json['prenom'] as String,
        mobile: json['mobile'] as String?,
        email: json['email'] as String?,
        role: userRoleFromJson(json['role'] as String),
        status: userStatusFromJson(json['status'] as String?),
        societe: json['societe'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        habilitations: ((json['habilitations'] as List?) ?? [])
            .map((h) => Habilitation.fromJson(h as Map<String, dynamic>))
            .toList(),
        isActive: json['isActive'] as bool? ?? false,
        suspendu: json['suspendu'] as bool? ?? false,
      );

  /// Sérialisation pour le cache local (session hors-ligne) — miroir de [fromJson].
  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'prenom': prenom,
        'mobile': mobile,
        'email': email,
        'role': role.name,
        'status': status?.name,
        'societe': societe,
        'avatarUrl': avatarUrl,
        'habilitations': habilitations.map((h) => h.toJson()).toList(),
        'isActive': isActive,
        'suspendu': suspendu,
      };
}
