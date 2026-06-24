// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  group('FieldType Tests', () {
    test('predefined constants expose the expected string values', () {
      expect(FieldType.string.value, 'string');
      expect(FieldType.binary.value, 'binary');
      expect(FieldType.number.value, 'number');
      expect(FieldType.date.value, 'date');
    });

    test('value getter and toString reflect the wrapped value', () {
      final type = FieldType('custom');
      expect(type.value, 'custom');
      expect(type.toString(), 'custom');
    });

    test('toString of predefined constant returns its value', () {
      expect(FieldType.binary.toString(), 'binary');
      expect(FieldType.string.toString(), 'string');
    });

    test('equality is value based across const and constructed instances', () {
      expect(FieldType('binary'), equals(FieldType.binary));
      expect(FieldType.binary, equals(FieldType('binary')));
      expect(FieldType('string') == FieldType.string, isTrue);
      expect(FieldType.number == FieldType('number'), isTrue);
    });

    test('identical instance is equal to itself', () {
      const type = FieldType.date;
      expect(type == type, isTrue);
      expect(identical(type, FieldType.date), isTrue);
    });

    test('instances with different values are not equal', () {
      expect(FieldType.binary == FieldType.number, isFalse);
      expect(FieldType('string') == FieldType('binary'), isFalse);
      expect(FieldType.string == FieldType.date, isFalse);
    });

    test('equality against a non FieldType object is false', () {
      // ignore: unrelated_type_equality_checks
      expect(FieldType.binary == 'binary', isFalse);
      expect(FieldType.string == Object(), isFalse);
    });

    test('hashCode is equal for value-equal instances', () {
      expect(FieldType('binary').hashCode, FieldType.binary.hashCode);
      expect(FieldType('number').hashCode, FieldType.number.hashCode);
      expect(FieldType.string.hashCode, FieldType('string').hashCode);
    });

    test('value-equal instances behave as one key in a set', () {
      final set = <FieldType>{
        FieldType.binary,
        FieldType('binary'),
        FieldType.number,
      };
      expect(set.length, 2);
      expect(set.contains(FieldType('number')), isTrue);
    });

    group('fromString Tests', () {
      test('maps "binary" to the binary constant', () {
        final result = FieldType.fromString('binary');
        expect(identical(result, FieldType.binary), isTrue);
        expect(result.value, 'binary');
      });

      test('maps "number" to the number constant', () {
        final result = FieldType.fromString('number');
        expect(identical(result, FieldType.number), isTrue);
        expect(result.value, 'number');
      });

      test('maps "date" to the date constant', () {
        final result = FieldType.fromString('date');
        expect(identical(result, FieldType.date), isTrue);
        expect(result.value, 'date');
      });

      test('maps "string" to the string constant', () {
        final result = FieldType.fromString('string');
        expect(identical(result, FieldType.string), isTrue);
        expect(result.value, 'string');
      });

      test('maps an unknown type to the string default', () {
        final result = FieldType.fromString('unknown_type');
        expect(identical(result, FieldType.string), isTrue);
        expect(result.value, 'string');
      });

      test('empty string falls back to the string default', () {
        final result = FieldType.fromString('');
        expect(identical(result, FieldType.string), isTrue);
        expect(result.value, 'string');
      });

      test('matching is case sensitive so "Binary" falls back to string', () {
        final result = FieldType.fromString('Binary');
        expect(identical(result, FieldType.string), isTrue);
        expect(result.value, 'string');
      });
    });
  });

  group('Sep12Status Tests', () {
    test('predefined constants expose the expected string values', () {
      expect(Sep12Status.needsInfo.value, 'NEEDS_INFO');
      expect(Sep12Status.accepted.value, 'ACCEPTED');
      expect(Sep12Status.processing.value, 'PROCESSING');
      expect(Sep12Status.rejected.value, 'REJECTED');
      expect(Sep12Status.verificationRequired.value, 'VERIFICATION_REQUIRED');
    });

    test('value getter and toString reflect the wrapped value', () {
      final status = Sep12Status('CUSTOM_STATUS');
      expect(status.value, 'CUSTOM_STATUS');
      expect(status.toString(), 'CUSTOM_STATUS');
    });

    test('toString of predefined constant returns its value', () {
      expect(Sep12Status.accepted.toString(), 'ACCEPTED');
      expect(Sep12Status.needsInfo.toString(), 'NEEDS_INFO');
    });

    test('equality is value based across const and constructed instances', () {
      expect(Sep12Status('ACCEPTED'), equals(Sep12Status.accepted));
      expect(Sep12Status.needsInfo, equals(Sep12Status('NEEDS_INFO')));
      expect(
          Sep12Status('VERIFICATION_REQUIRED') ==
              Sep12Status.verificationRequired,
          isTrue);
    });

    test('identical instance is equal to itself', () {
      const status = Sep12Status.rejected;
      expect(status == status, isTrue);
      expect(identical(status, Sep12Status.rejected), isTrue);
    });

    test('instances with different values are not equal', () {
      expect(Sep12Status.accepted == Sep12Status.rejected, isFalse);
      expect(Sep12Status('ACCEPTED') == Sep12Status('PROCESSING'), isFalse);
    });

    test('equality against a non Sep12Status object is false', () {
      // ignore: unrelated_type_equality_checks
      expect(Sep12Status.accepted == 'ACCEPTED', isFalse);
      expect(Sep12Status.needsInfo == Object(), isFalse);
    });

    test('hashCode is equal for value-equal instances', () {
      expect(Sep12Status('ACCEPTED').hashCode, Sep12Status.accepted.hashCode);
      expect(Sep12Status('REJECTED').hashCode, Sep12Status.rejected.hashCode);
    });

    test('value-equal instances behave as one key in a set', () {
      final set = <Sep12Status>{
        Sep12Status.accepted,
        Sep12Status('ACCEPTED'),
        Sep12Status.rejected,
      };
      expect(set.length, 2);
      expect(set.contains(Sep12Status('REJECTED')), isTrue);
    });
  });

  group('Field Tests', () {
    test('from maps all populated base SDK fields', () {
      final infoField = flutter_sdk.GetCustomerInfoField(
        'date',
        'Date of birth',
        ['1990', '1991', '1992'],
        false,
      );

      final field = Field.from(infoField);

      expect(field.type, equals(FieldType.date));
      expect(field.type.value, 'date');
      expect(field.description, 'Date of birth');
      expect(field.choices, ['1990', '1991', '1992']);
      expect(field.optional, isFalse);
    });

    test('from preserves null optional fields as null', () {
      final infoField = flutter_sdk.GetCustomerInfoField(
        'string',
        null,
        null,
        null,
      );

      final field = Field.from(infoField);

      expect(field.type, equals(FieldType.string));
      expect(field.description, isNull);
      expect(field.choices, isNull);
      expect(field.optional, isNull);
    });

    test('from maps an unknown type to the string default', () {
      final infoField = flutter_sdk.GetCustomerInfoField(
        'totally_unknown',
        null,
        null,
        true,
      );

      final field = Field.from(infoField);

      expect(field.type, equals(FieldType.string));
      expect(field.optional, isTrue);
    });

    test('from preserves an empty choices list as empty (not null)', () {
      final infoField = flutter_sdk.GetCustomerInfoField(
        'number',
        'A number',
        <String>[],
        true,
      );

      final field = Field.from(infoField);

      expect(field.type, equals(FieldType.number));
      expect(field.choices, isNotNull);
      expect(field.choices, isEmpty);
    });
  });

  group('ProvidedField Tests', () {
    test('from maps all populated base SDK fields including status', () {
      final infoProvidedField = flutter_sdk.GetCustomerInfoProvidedField(
        'binary',
        'Government ID',
        ['passport', 'license'],
        false,
        'ACCEPTED',
        null,
      );

      final providedField = ProvidedField.from(infoProvidedField);

      expect(providedField.type, equals(FieldType.binary));
      expect(providedField.description, 'Government ID');
      expect(providedField.choices, ['passport', 'license']);
      expect(providedField.optional, isFalse);
      expect(providedField.status, isNotNull);
      expect(providedField.status, equals(Sep12Status.accepted));
      expect(providedField.error, isNull);
    });

    test('from leaves status null when base SDK status is null', () {
      final infoProvidedField = flutter_sdk.GetCustomerInfoProvidedField(
        'string',
        null,
        null,
        null,
        null,
        null,
      );

      final providedField = ProvidedField.from(infoProvidedField);

      expect(providedField.type, equals(FieldType.string));
      expect(providedField.description, isNull);
      expect(providedField.choices, isNull);
      expect(providedField.optional, isNull);
      expect(providedField.status, isNull);
      expect(providedField.error, isNull);
    });

    test('from maps a rejected status with an error message', () {
      final infoProvidedField = flutter_sdk.GetCustomerInfoProvidedField(
        'string',
        'Email address',
        null,
        true,
        'REJECTED',
        'The email address is invalid',
      );

      final providedField = ProvidedField.from(infoProvidedField);

      expect(providedField.type, equals(FieldType.string));
      expect(providedField.status, equals(Sep12Status.rejected));
      expect(providedField.error, 'The email address is invalid');
      expect(providedField.optional, isTrue);
    });

    test('from maps an unknown type to the string default', () {
      final infoProvidedField = flutter_sdk.GetCustomerInfoProvidedField(
        'mystery',
        null,
        null,
        null,
        'PROCESSING',
        null,
      );

      final providedField = ProvidedField.from(infoProvidedField);

      expect(providedField.type, equals(FieldType.string));
      expect(providedField.status, equals(Sep12Status.processing));
    });

    test('from preserves a non standard status value verbatim', () {
      final infoProvidedField = flutter_sdk.GetCustomerInfoProvidedField(
        'string',
        null,
        null,
        null,
        'SOME_CUSTOM_STATUS',
        null,
      );

      final providedField = ProvidedField.from(infoProvidedField);

      expect(providedField.status, isNotNull);
      expect(providedField.status!.value, 'SOME_CUSTOM_STATUS');
    });
  });

  group('AddCustomerResponse Tests', () {
    test('from copies the id from the base SDK response', () {
      final infoResponse =
          flutter_sdk.PutCustomerInfoResponse('customer-id-123');

      final response = AddCustomerResponse.from(infoResponse);

      expect(response.id, 'customer-id-123');
    });

    test('constructor stores the provided id', () {
      final response = AddCustomerResponse('abc');
      expect(response.id, 'abc');
    });
  });

  group('GetCustomerResponse Tests', () {
    test('from maps status, id and message', () {
      final infoResponse = flutter_sdk.GetCustomerInfoResponse(
        'cust-1',
        'ACCEPTED',
        null,
        null,
        'All good',
      );

      final response = GetCustomerResponse.from(infoResponse);

      expect(response.id, 'cust-1');
      expect(response.sep12Status, equals(Sep12Status.accepted));
      expect(response.message, 'All good');
    });

    test('from leaves fields and providedFields null when base SDK has null',
        () {
      final infoResponse = flutter_sdk.GetCustomerInfoResponse(
        null,
        'NEEDS_INFO',
        null,
        null,
        null,
      );

      final response = GetCustomerResponse.from(infoResponse);

      expect(response.id, isNull);
      expect(response.sep12Status, equals(Sep12Status.needsInfo));
      expect(response.message, isNull);
      expect(response.fields, isNull);
      expect(response.providedFields, isNull);
    });

    test('from produces an empty fields map when base SDK fields are empty', () {
      final infoResponse = flutter_sdk.GetCustomerInfoResponse(
        'cust-2',
        'NEEDS_INFO',
        <String, flutter_sdk.GetCustomerInfoField>{},
        null,
        null,
      );

      final response = GetCustomerResponse.from(infoResponse);

      expect(response.fields, isNotNull);
      expect(response.fields, isEmpty);
      expect(response.providedFields, isNull);
    });

    test('from maps each entry of a populated fields map', () {
      final infoResponse = flutter_sdk.GetCustomerInfoResponse(
        'cust-3',
        'NEEDS_INFO',
        {
          'first_name': flutter_sdk.GetCustomerInfoField(
            'string',
            'First name',
            null,
            false,
          ),
          'photo_id_front': flutter_sdk.GetCustomerInfoField(
            'binary',
            'Front of ID',
            null,
            true,
          ),
        },
        null,
        null,
      );

      final response = GetCustomerResponse.from(infoResponse);

      expect(response.fields, isNotNull);
      expect(response.fields!.length, 2);

      final firstName = response.fields!['first_name']!;
      expect(firstName.type, equals(FieldType.string));
      expect(firstName.description, 'First name');
      expect(firstName.optional, isFalse);

      final photoId = response.fields!['photo_id_front']!;
      expect(photoId.type, equals(FieldType.binary));
      expect(photoId.description, 'Front of ID');
      expect(photoId.optional, isTrue);
    });

    test('from produces an empty providedFields map when base SDK is empty', () {
      final infoResponse = flutter_sdk.GetCustomerInfoResponse(
        'cust-4',
        'PROCESSING',
        null,
        <String, flutter_sdk.GetCustomerInfoProvidedField>{},
        null,
      );

      final response = GetCustomerResponse.from(infoResponse);

      expect(response.providedFields, isNotNull);
      expect(response.providedFields, isEmpty);
      expect(response.fields, isNull);
    });

    test('from maps each entry of a populated providedFields map', () {
      final infoResponse = flutter_sdk.GetCustomerInfoResponse(
        'cust-5',
        'PROCESSING',
        null,
        {
          'email_address': flutter_sdk.GetCustomerInfoProvidedField(
            'string',
            'Email',
            null,
            false,
            'ACCEPTED',
            null,
          ),
          'bank_account': flutter_sdk.GetCustomerInfoProvidedField(
            'string',
            'Bank account',
            null,
            true,
            'REJECTED',
            'Invalid account number',
          ),
        },
        null,
      );

      final response = GetCustomerResponse.from(infoResponse);

      expect(response.providedFields, isNotNull);
      expect(response.providedFields!.length, 2);

      final email = response.providedFields!['email_address']!;
      expect(email.type, equals(FieldType.string));
      expect(email.status, equals(Sep12Status.accepted));
      expect(email.error, isNull);

      final bank = response.providedFields!['bank_account']!;
      expect(bank.status, equals(Sep12Status.rejected));
      expect(bank.error, 'Invalid account number');
      expect(bank.optional, isTrue);
    });

    test('from maps both fields and providedFields together', () {
      final infoResponse = flutter_sdk.GetCustomerInfoResponse(
        'cust-6',
        'NEEDS_INFO',
        {
          'last_name': flutter_sdk.GetCustomerInfoField(
            'string',
            'Last name',
            null,
            false,
          ),
        },
        {
          'first_name': flutter_sdk.GetCustomerInfoProvidedField(
            'string',
            'First name',
            null,
            false,
            'ACCEPTED',
            null,
          ),
        },
        'More info needed',
      );

      final response = GetCustomerResponse.from(infoResponse);

      expect(response.fields!.keys, contains('last_name'));
      expect(response.providedFields!.keys, contains('first_name'));
      expect(response.sep12Status, equals(Sep12Status.needsInfo));
      expect(response.message, 'More info needed');
    });

    test('from preserves a non standard status value verbatim', () {
      final infoResponse = flutter_sdk.GetCustomerInfoResponse(
        'cust-7',
        'CUSTOM_STATE',
        null,
        null,
        null,
      );

      final response = GetCustomerResponse.from(infoResponse);

      expect(response.sep12Status.value, 'CUSTOM_STATE');
    });
  });
}
