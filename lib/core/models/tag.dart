/// Dive tag (reusable, like buddies).
library;

class Tag {
  final int id;
  final String name;
  const Tag({required this.id, required this.name});
}

/// Where an inherited (automatic) tag of a dive comes from.
enum TagSource { site, diveType }

/// Tag a dive gets from its site or its dive type, not set by hand.
class InheritedTag {
  final Tag tag;
  final TagSource source;
  const InheritedTag(this.tag, this.source);
}
