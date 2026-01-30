// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_request.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubscriptionRequestAdapter extends TypeAdapter<SubscriptionRequest> {
  @override
  final int typeId = 4;

  @override
  SubscriptionRequest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubscriptionRequest(
      userId: fields[0] as String,
      email: fields[1] as String,
      phoneNumber: fields[2] as String?,
      amount: fields[3] as int,
      transactionId: fields[4] as String,
      subscriptionType: fields[5] as String,
      submittedAt: fields[6] as DateTime,
      status: fields[7] as String,
      adminComment: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SubscriptionRequest obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.phoneNumber)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.transactionId)
      ..writeByte(5)
      ..write(obj.subscriptionType)
      ..writeByte(6)
      ..write(obj.submittedAt)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.adminComment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionRequestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
