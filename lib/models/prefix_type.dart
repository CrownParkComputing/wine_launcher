enum PrefixType {
  wine,
  proton;

  String get displayName {
    switch (this) {
      case PrefixType.wine:
        return 'Wine';
      case PrefixType.proton:
        return 'Proton';
    }
  }
} 