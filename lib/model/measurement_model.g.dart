// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurement_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MeasurementAdapter extends TypeAdapter<Measurement> {
  @override
  final int typeId = 0;

  @override
  Measurement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Measurement(
      id: fields[0] as String?,
      clientName: fields[1] as String,
      createdAt: fields[2] as DateTime,
      garmentImageUrl: fields[3] as String,
      measurements: (fields[4] as Map).cast<String, dynamic>(),
      modeImageUrl: fields[5] as String,
      phoneNumber: fields[6] as String,
      price: fields[7] as double?,
      advance: fields[8] as double?,
      userId: fields[9] as String,
      status: fields[10] as String,
      syncedAt: fields[11] as DateTime?,
      uuid: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Measurement obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientName)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.garmentImageUrl)
      ..writeByte(4)
      ..write(obj.measurements)
      ..writeByte(5)
      ..write(obj.modeImageUrl)
      ..writeByte(6)
      ..write(obj.phoneNumber)
      ..writeByte(7)
      ..write(obj.price)
      ..writeByte(8)
      ..write(obj.advance)
      ..writeByte(9)
      ..write(obj.userId)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.syncedAt)
      ..writeByte(12)
      ..write(obj.uuid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeasurementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
