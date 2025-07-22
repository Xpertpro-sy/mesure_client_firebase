// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurement_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MeasurementConfigAdapter extends TypeAdapter<MeasurementConfig> {
  @override
  final int typeId = 1;

  @override
  MeasurementConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MeasurementConfig(
      userId: fields[0] as String,
      measurements: (fields[1] as List).cast<CustomMeasurement>(),
      updatedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MeasurementConfig obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.measurements)
      ..writeByte(2)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeasurementConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CustomMeasurementAdapter extends TypeAdapter<CustomMeasurement> {
  @override
  final int typeId = 2;

  @override
  CustomMeasurement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomMeasurement(
      id: fields[0] as String,
      name: fields[1] as String,
      unit: fields[2] as String,
      defaultValue: fields[3] as String?,
      updatedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CustomMeasurement obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.defaultValue)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomMeasurementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
