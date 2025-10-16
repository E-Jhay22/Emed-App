class InventoryTxn {
  final String id;
  final String itemId;
  final String itemName;
  final String type; // receive | dispense | adjust
  final int delta;
  final int newQuantity;
  final String? patientName;
  final String? notes;
  final String actorId;
  final String? actorName;
  final DateTime createdAt;

  InventoryTxn({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.delta,
    required this.newQuantity,
    this.patientName,
    this.notes,
    required this.actorId,
    this.actorName,
    required this.createdAt,
  });

  factory InventoryTxn.fromJson(Map<String, dynamic> json) => InventoryTxn(
    id: json['id'] as String,
    itemId: json['item_id'] as String,
    itemName: (json['item_name'] as String?) ?? '',
    type: (json['type'] as String?) ?? '',
    delta: (json['delta'] is int)
        ? json['delta'] as int
        : int.tryParse('${json['delta']}') ?? 0,
    newQuantity: (json['new_quantity'] is int)
        ? json['new_quantity'] as int
        : int.tryParse('${json['new_quantity']}') ?? 0,
    patientName: json['patient_name'] as String?,
    notes: json['notes'] as String?,
    actorId: json['actor_id'] as String,
    actorName: json['actor_name'] as String?,
    createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
  );
}
