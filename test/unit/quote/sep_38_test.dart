// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  // Service address used to construct the Sep38 wrapper. No network calls are
  // exercised by these tests; only the pure validation guards and the *.from
  // converters are covered here.
  const serviceAddress = 'http://api.stellar.org/quotes-sep38/';

  // A syntactically valid, decodable JWT (sub/iss/iat/exp claims). The
  // AuthToken constructor decodes the JWT, so an opaque string would throw.
  const jwt =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0';

  group('price() amount validation Tests', () {
    late Sep38 sep38;

    setUp(() {
      sep38 = Sep38(serviceAddress, token: AuthToken(jwt));
    });

    test('throws ValidationException when both sellAmount and buyAmount given',
        () async {
      await expectLater(
        sep38.price(
          context: 'sep31',
          sellAsset: 'iso4217:BRL',
          buyAsset:
              'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
          sellAmount: '100',
          buyAmount: '20',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException when neither sellAmount nor buyAmount given',
        () async {
      await expectLater(
        sep38.price(
          context: 'sep31',
          sellAsset: 'iso4217:BRL',
          buyAsset:
              'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('ValidationException message identifies the XOR requirement', () async {
      try {
        await sep38.price(
          context: 'sep31',
          sellAsset: 'iso4217:BRL',
          buyAsset:
              'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
          sellAmount: '100',
          buyAmount: '20',
        );
        fail('Expected ValidationException to be thrown');
      } on ValidationException catch (e) {
        expect(
            e.message,
            'The caller must provide either [sellAmount] or [buyAmount], '
            'but not both.');
      }
    });
  });

  group('requestQuote() amount validation Tests', () {
    late Sep38 sep38;

    setUp(() {
      sep38 = Sep38(serviceAddress, token: AuthToken(jwt));
    });

    test('throws ValidationException when both sellAmount and buyAmount given',
        () async {
      await expectLater(
        sep38.requestQuote(
          context: 'sep31',
          sellAsset: 'iso4217:BRL',
          buyAsset:
              'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
          sellAmount: '100',
          buyAmount: '20',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException when neither amount given', () async {
      await expectLater(
        sep38.requestQuote(
          context: 'sep31',
          sellAsset: 'iso4217:BRL',
          buyAsset:
              'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('ValidationException message identifies the XOR requirement', () async {
      try {
        await sep38.requestQuote(
          context: 'sep31',
          sellAsset: 'iso4217:BRL',
          buyAsset:
              'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
        );
        fail('Expected ValidationException to be thrown');
      } on ValidationException catch (e) {
        expect(
            e.message,
            'The caller must provide either [sellAmount] or [buyAmount], '
            'but not both.');
      }
    });
  });

  group('Auth guard Tests', () {
    test(
        'requestQuote throws QuoteEndpointAuthRequired when no token configured',
        () async {
      final sep38 = Sep38(serviceAddress);
      await expectLater(
        sep38.requestQuote(
          context: 'sep31',
          sellAsset: 'iso4217:BRL',
          buyAsset:
              'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
          sellAmount: '100',
        ),
        throwsA(isA<QuoteEndpointAuthRequired>()),
      );
    });

    test(
        'requestQuote auth guard precedes amount validation when no token given',
        () async {
      // Both amounts are supplied (an amount-XOR violation), but with no token
      // available the auth guard must fire first.
      final sep38 = Sep38(serviceAddress);
      await expectLater(
        sep38.requestQuote(
          context: 'sep31',
          sellAsset: 'iso4217:BRL',
          buyAsset:
              'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
          sellAmount: '100',
          buyAmount: '20',
        ),
        throwsA(isA<QuoteEndpointAuthRequired>()),
      );
    });

    test('getQuote throws QuoteEndpointAuthRequired when no token configured',
        () async {
      final sep38 = Sep38(serviceAddress);
      await expectLater(
        sep38.getQuote('de762cda-a193-4961-861e-57b31fed6eb3'),
        throwsA(isA<QuoteEndpointAuthRequired>()),
      );
    });

    test('QuoteEndpointAuthRequired carries an explanatory message for getQuote',
        () async {
      final sep38 = Sep38(serviceAddress);
      try {
        await sep38.getQuote('de762cda-a193-4961-861e-57b31fed6eb3');
        fail('Expected QuoteEndpointAuthRequired to be thrown');
      } on QuoteEndpointAuthRequired catch (e) {
        expect(e.message,
            'The getQuote endpoint requires SEP-10 authentication');
      }
    });
  });

  group('QuotesInfoResponse.from Tests', () {
    test('maps each base SDK asset into a QuoteInfoAsset preserving order', () {
      final infoResponse = flutter_sdk.SEP38InfoResponse([
        flutter_sdk.SEP38Asset(
          'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
        ),
        flutter_sdk.SEP38Asset(
          'iso4217:BRL',
          countryCodes: ['BRA'],
        ),
      ]);

      final result = QuotesInfoResponse.from(infoResponse);

      expect(result.assets.length, 2);
      expect(
          result.assets[0].asset,
          'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN');
      expect(result.assets[1].asset, 'iso4217:BRL');
      expect(result.assets[1].countryCodes, ['BRA']);
    });

    test('maps an empty asset list to an empty QuoteInfoAsset list', () {
      final result = QuotesInfoResponse.from(flutter_sdk.SEP38InfoResponse([]));
      expect(result.assets, isEmpty);
    });
  });

  group('QuoteInfoAsset.from Tests', () {
    test('null delivery methods stay null', () {
      final asset = flutter_sdk.SEP38Asset('iso4217:BRL');

      final result = QuoteInfoAsset.from(asset);

      expect(result.asset, 'iso4217:BRL');
      expect(result.sellDeliveryMethods, isNull);
      expect(result.buyDeliveryMethods, isNull);
      expect(result.countryCodes, isNull);
    });

    test('empty delivery method lists are normalized to null', () {
      // The converter treats empty lists the same as absent (null) data.
      final asset = flutter_sdk.SEP38Asset(
        'iso4217:BRL',
        sellDeliveryMethods: [],
        buyDeliveryMethods: [],
      );

      final result = QuoteInfoAsset.from(asset);

      expect(result.sellDeliveryMethods, isNull);
      expect(result.buyDeliveryMethods, isNull);
    });

    test('populated sell and buy delivery methods are mapped fully', () {
      final asset = flutter_sdk.SEP38Asset(
        'iso4217:BRL',
        sellDeliveryMethods: [
          flutter_sdk.Sep38SellDeliveryMethod(
              'cash', 'Deposit cash BRL at one of our agent locations.'),
          flutter_sdk.Sep38SellDeliveryMethod(
              'PIX', "Send BRL directly to the Anchor's bank account."),
        ],
        buyDeliveryMethods: [
          flutter_sdk.Sep38BuyDeliveryMethod(
              'cash', 'Pick up cash BRL at one of our payout locations.'),
        ],
        countryCodes: ['BRA'],
      );

      final result = QuoteInfoAsset.from(asset);

      expect(result.asset, 'iso4217:BRL');
      expect(result.countryCodes, ['BRA']);

      expect(result.sellDeliveryMethods, isNotNull);
      expect(result.sellDeliveryMethods!.length, 2);
      expect(result.sellDeliveryMethods![0].name, 'cash');
      expect(result.sellDeliveryMethods![0].description,
          'Deposit cash BRL at one of our agent locations.');
      expect(result.sellDeliveryMethods![1].name, 'PIX');
      expect(result.sellDeliveryMethods![1].description,
          "Send BRL directly to the Anchor's bank account.");

      expect(result.buyDeliveryMethods, isNotNull);
      expect(result.buyDeliveryMethods!.length, 1);
      expect(result.buyDeliveryMethods![0].name, 'cash');
      expect(result.buyDeliveryMethods![0].description,
          'Pick up cash BRL at one of our payout locations.');
    });

    test('null countryCodes is preserved when delivery methods are present', () {
      final asset = flutter_sdk.SEP38Asset(
        'iso4217:BRL',
        sellDeliveryMethods: [
          flutter_sdk.Sep38SellDeliveryMethod('cash', 'desc'),
        ],
      );

      final result = QuoteInfoAsset.from(asset);

      expect(result.countryCodes, isNull);
      expect(result.sellDeliveryMethods!.length, 1);
    });
  });

  group('QuoteAssetIndicativePrices.from Tests', () {
    test('maps buy assets including decimals precision', () {
      final response = flutter_sdk.SEP38PricesResponse([
        flutter_sdk.SEP38BuyAsset('iso4217:BRL', '0.18', 2),
        flutter_sdk.SEP38BuyAsset(
            'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
            '1.00',
            7),
      ]);

      final result = QuoteAssetIndicativePrices.from(response);

      expect(result.buyAssets.length, 2);
      expect(result.buyAssets[0].asset, 'iso4217:BRL');
      expect(result.buyAssets[0].price, '0.18');
      expect(result.buyAssets[0].decimals, 2);
      expect(result.buyAssets[1].decimals, 7);
    });

    test('empty buy asset list maps to empty list', () {
      final result =
          QuoteAssetIndicativePrices.from(flutter_sdk.SEP38PricesResponse([]));
      expect(result.buyAssets, isEmpty);
    });
  });

  group('QuoteBuyAsset.from Tests', () {
    test('maps asset, price and decimals exactly', () {
      final buyAsset = flutter_sdk.SEP38BuyAsset('iso4217:BRL', '0.18', 2);

      final result = QuoteBuyAsset.from(buyAsset);

      expect(result.asset, 'iso4217:BRL');
      expect(result.price, '0.18');
      expect(result.decimals, 2);
    });

    test('preserves zero decimals', () {
      final result =
          QuoteBuyAsset.from(flutter_sdk.SEP38BuyAsset('iso4217:JPY', '1', 0));
      expect(result.decimals, 0);
    });
  });

  group('ConversionFee.from Tests', () {
    test('maps total and asset with null details when none provided', () {
      final fee = flutter_sdk.SEP38Fee('42.00', 'iso4217:BRL');

      final result = ConversionFee.from(fee);

      expect(result.total, '42.00');
      expect(result.asset, 'iso4217:BRL');
      expect(result.details, isNull);
    });

    test('empty details list is normalized to null', () {
      final fee = flutter_sdk.SEP38Fee('42.00', 'iso4217:BRL', details: []);

      final result = ConversionFee.from(fee);

      expect(result.details, isNull);
    });

    test('maps populated details preserving name, amount and description', () {
      final fee = flutter_sdk.SEP38Fee(
        '10.00',
        'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
        details: [
          flutter_sdk.SEP38FeeDetails('Service fee', '5.00'),
          flutter_sdk.SEP38FeeDetails('PIX fee', '5.00',
              description:
                  'Fee charged in order to process the outgoing BRL PIX transaction.'),
        ],
      );

      final result = ConversionFee.from(fee);

      expect(result.total, '10.00');
      expect(result.asset,
          'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN');
      expect(result.details, isNotNull);
      expect(result.details!.length, 2);

      expect(result.details![0].name, 'Service fee');
      expect(result.details![0].amount, '5.00');
      expect(result.details![0].description, isNull);

      expect(result.details![1].name, 'PIX fee');
      expect(result.details![1].amount, '5.00');
      expect(result.details![1].description,
          'Fee charged in order to process the outgoing BRL PIX transaction.');
    });
  });

  group('ConversionFeeDetails.from Tests', () {
    test('maps a detail without description', () {
      final detail = flutter_sdk.SEP38FeeDetails('Service fee', '8.40');

      final result = ConversionFeeDetails.from(detail);

      expect(result.name, 'Service fee');
      expect(result.amount, '8.40');
      expect(result.description, isNull);
    });

    test('maps a detail with description', () {
      final detail = flutter_sdk.SEP38FeeDetails('PIX fee', '55.5556',
          description:
              'Fee charged in order to process the outgoing PIX transaction.');

      final result = ConversionFeeDetails.from(detail);

      expect(result.name, 'PIX fee');
      expect(result.amount, '55.5556');
      expect(result.description,
          'Fee charged in order to process the outgoing PIX transaction.');
    });
  });

  group('QuoteAssetPairIndicativePrice.from Tests', () {
    test('maps top-level price fields and nested fee', () {
      final priceResponse = flutter_sdk.SEP38PriceResponse(
        '5.42',
        '5.00',
        '542',
        '100',
        flutter_sdk.SEP38Fee('42.00', 'iso4217:BRL'),
      );

      final result = QuoteAssetPairIndicativePrice.from(priceResponse);

      expect(result.totalPrice, '5.42');
      expect(result.price, '5.00');
      expect(result.sellAmount, '542');
      expect(result.buyAmount, '100');
      expect(result.fee.total, '42.00');
      expect(result.fee.asset, 'iso4217:BRL');
      expect(result.fee.details, isNull);
    });

    test('maps nested fee details when present', () {
      final priceResponse = flutter_sdk.SEP38PriceResponse(
        '0.20',
        '0.18',
        '100',
        '500',
        flutter_sdk.SEP38Fee(
          '55.5556',
          'iso4217:BRL',
          details: [
            flutter_sdk.SEP38FeeDetails('PIX fee', '55.5556',
                description:
                    'Fee charged in order to process the outgoing PIX transaction.'),
          ],
        ),
      );

      final result = QuoteAssetPairIndicativePrice.from(priceResponse);

      expect(result.fee.details, isNotNull);
      expect(result.fee.details!.length, 1);
      expect(result.fee.details![0].name, 'PIX fee');
      expect(result.fee.details![0].amount, '55.5556');
      expect(result.fee.details![0].description,
          'Fee charged in order to process the outgoing PIX transaction.');
    });
  });

  group('FirmQuote.from Tests', () {
    test('maps all firm quote fields including expiresAt and nested fee', () {
      final expiresAt = DateTime.utc(2024, 2, 1, 10, 40, 14);
      final quoteResponse = flutter_sdk.SEP38QuoteResponse(
        'de762cda-a193-4961-861e-57b31fed6eb3',
        expiresAt,
        '5.42',
        '5.00',
        'iso4217:BRL',
        '542',
        'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
        '100',
        flutter_sdk.SEP38Fee(
          '8.40',
          'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
          details: [
            flutter_sdk.SEP38FeeDetails('Service fee', '8.40'),
          ],
        ),
      );

      final result = FirmQuote.from(quoteResponse);

      expect(result.id, 'de762cda-a193-4961-861e-57b31fed6eb3');
      expect(result.expiresAt, expiresAt);
      expect(result.totalPrice, '5.42');
      expect(result.price, '5.00');
      expect(result.sellAsset, 'iso4217:BRL');
      expect(result.sellAmount, '542');
      expect(result.buyAsset,
          'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN');
      expect(result.buyAmount, '100');
      expect(result.fee.total, '8.40');
      expect(result.fee.asset,
          'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN');
      expect(result.fee.details, isNotNull);
      expect(result.fee.details!.length, 1);
      expect(result.fee.details![0].name, 'Service fee');
      expect(result.fee.details![0].amount, '8.40');
    });

    test('preserves expiresAt as the exact DateTime value', () {
      final expiresAt = DateTime.utc(2030, 12, 31, 23, 59, 59);
      final quoteResponse = flutter_sdk.SEP38QuoteResponse(
        'quote-id',
        expiresAt,
        '1.0',
        '1.0',
        'iso4217:USD',
        '10',
        'iso4217:EUR',
        '9',
        flutter_sdk.SEP38Fee('0.1', 'iso4217:USD'),
      );

      final result = FirmQuote.from(quoteResponse);

      expect(result.expiresAt, expiresAt);
      expect(result.expiresAt.isUtc, isTrue);
    });
  });
}
