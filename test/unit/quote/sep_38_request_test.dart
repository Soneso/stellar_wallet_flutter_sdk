// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// Outbound-request forwarding tests for SEP-38 (Anchor RFQ).
///
/// These tests construct [Sep38] directly with a [MockClient] so that every
/// HTTP request issued by the underlying base-SDK SEP38QuoteService is captured.
/// The captured request is then inspected to assert that the wallet-SDK wrapper
/// forwards ALL optional parameters to the quote server, in particular both
/// sell_delivery_method AND buy_delivery_method. The buy_delivery_method
/// assertions are the regression guard for the previously-dropped
/// buyDeliveryMethod parameter in price()/prices().
void main() {
  // Service address used to construct the Sep38 wrapper. The trailing slash is
  // intentional: the base SDK appends the endpoint (price/prices/quote) to it.
  const serviceAddress = 'http://api.stellar.org/quotes-sep38/';

  // A syntactically valid, decodable JWT (sub/iss/iat/exp claims). The
  // AuthToken constructor decodes the JWT, so an opaque string would throw.
  const jwt =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0';

  const sellAsset = 'iso4217:BRL';
  const buyAsset =
      'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';

  // Minimal but complete SEP38PriceResponse JSON. fee.total/fee.asset are
  // required by SEP38Fee.fromJson; total_price/price/sell_amount/buy_amount are
  // required by SEP38PriceResponse.fromJson.
  String priceResponseJson() => json.encode({
        'total_price': '5.42',
        'price': '5.00',
        'sell_amount': '542',
        'buy_amount': '100',
        'fee': {
          'total': '42.00',
          'asset': 'iso4217:BRL',
        },
      });

  // Minimal SEP38PricesResponse JSON. buy_assets entries require asset/price/
  // decimals.
  String pricesResponseJson() => json.encode({
        'buy_assets': [
          {
            'asset': 'iso4217:BRL',
            'price': '0.18',
            'decimals': 2,
          }
        ],
      });

  group('price() outbound request forwarding', () {
    test(
        'forwards both sell_delivery_method and buy_delivery_method plus all '
        'core params on the GET query (regression guard for dropped '
        'buyDeliveryMethod)', () async {
      late Uri capturedUri;

      final mock = MockClient((request) async {
        capturedUri = request.url;
        expect(request.method, 'GET');
        return http.Response(priceResponseJson(), 200);
      });

      final sep38 = Sep38(serviceAddress,
          httpClient: mock, token: AuthToken(jwt));

      final response = await sep38.price(
        context: 'sep31',
        sellAsset: sellAsset,
        buyAsset: buyAsset,
        sellAmount: '542',
        sellDeliveryMethod: 'PIX',
        buyDeliveryMethod: 'ACH',
        countryCode: 'BRA',
      );

      final params = capturedUri.queryParameters;

      // The buy_delivery_method MUST be present and carry the exact value.
      // This is the core regression assertion.
      expect(params.containsKey('buy_delivery_method'), isTrue,
          reason:
              'buy_delivery_method must be forwarded to the quote server');
      expect(params['buy_delivery_method'], 'ACH');

      // sell_delivery_method must be forwarded too.
      expect(params['sell_delivery_method'], 'PIX');

      // All remaining params must be forwarded with their exact values.
      expect(params['context'], 'sep31');
      expect(params['sell_asset'], sellAsset);
      expect(params['buy_asset'], buyAsset);
      expect(params['sell_amount'], '542');
      expect(params['country_code'], 'BRA');

      // sellAmount was provided, so buy_amount must NOT be sent.
      expect(params.containsKey('buy_amount'), isFalse);

      // The endpoint path must be the price endpoint.
      expect(capturedUri.path.endsWith('/price'), isTrue);

      // The parsed response is surfaced unchanged through the wrapper.
      expect(response.totalPrice, '5.42');
      expect(response.price, '5.00');
      expect(response.sellAmount, '542');
      expect(response.buyAmount, '100');
      expect(response.fee.total, '42.00');
      expect(response.fee.asset, 'iso4217:BRL');
    });

    test(
        'with buyAmount (XOR amount) forwards buy_amount and omits sell_amount, '
        'still forwarding buy_delivery_method', () async {
      late Uri capturedUri;

      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(priceResponseJson(), 200);
      });

      final sep38 = Sep38(serviceAddress,
          httpClient: mock, token: AuthToken(jwt));

      await sep38.price(
        context: 'sep6',
        sellAsset: buyAsset,
        buyAsset: sellAsset,
        buyAmount: '500',
        sellDeliveryMethod: 'WIRE',
        buyDeliveryMethod: 'PIX',
        countryCode: 'BRA',
      );

      final params = capturedUri.queryParameters;

      expect(params['buy_amount'], '500');
      expect(params.containsKey('sell_amount'), isFalse);
      expect(params['buy_delivery_method'], 'PIX');
      expect(params['sell_delivery_method'], 'WIRE');
      expect(params['context'], 'sep6');
      expect(params['sell_asset'], buyAsset);
      expect(params['buy_asset'], sellAsset);
      expect(params['country_code'], 'BRA');
    });
  });

  group('prices() outbound request forwarding', () {
    test(
        'forwards both sell_delivery_method and buy_delivery_method plus '
        'sell_asset/sell_amount/country_code', () async {
      late Uri capturedUri;

      final mock = MockClient((request) async {
        capturedUri = request.url;
        expect(request.method, 'GET');
        return http.Response(pricesResponseJson(), 200);
      });

      final sep38 = Sep38(serviceAddress,
          httpClient: mock, token: AuthToken(jwt));

      final response = await sep38.prices(
        sellAsset: buyAsset,
        sellAmount: '100',
        sellDeliveryMethod: 'WIRE',
        buyDeliveryMethod: 'ACH',
        countryCode: 'BRA',
      );

      final params = capturedUri.queryParameters;

      // Regression assertion: buy_delivery_method must be present.
      expect(params.containsKey('buy_delivery_method'), isTrue,
          reason:
              'buy_delivery_method must be forwarded to the quote server');
      expect(params['buy_delivery_method'], 'ACH');

      expect(params['sell_delivery_method'], 'WIRE');
      expect(params['sell_asset'], buyAsset);
      expect(params['sell_amount'], '100');
      expect(params['country_code'], 'BRA');

      expect(capturedUri.path.endsWith('/prices'), isTrue);

      // Response is surfaced through the wrapper.
      expect(response.buyAssets.length, 1);
      expect(response.buyAssets[0].asset, 'iso4217:BRL');
      expect(response.buyAssets[0].price, '0.18');
      expect(response.buyAssets[0].decimals, 2);
    });

    test('omits optional delivery methods and country code when not provided',
        () async {
      late Uri capturedUri;

      final mock = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(pricesResponseJson(), 200);
      });

      final sep38 = Sep38(serviceAddress,
          httpClient: mock, token: AuthToken(jwt));

      await sep38.prices(
        sellAsset: buyAsset,
        sellAmount: '100',
      );

      final params = capturedUri.queryParameters;

      expect(params['sell_asset'], buyAsset);
      expect(params['sell_amount'], '100');
      expect(params.containsKey('sell_delivery_method'), isFalse);
      expect(params.containsKey('buy_delivery_method'), isFalse);
      expect(params.containsKey('country_code'), isFalse);
    });
  });

  group('error translation', () {
    test('price(): HTTP 400 from quote server -> BadRequestDataException',
        () async {
      final mock = MockClient((request) async {
        return http.Response(
            json.encode({'error': 'unsupported sell_asset'}), 400);
      });

      final sep38 = Sep38(serviceAddress,
          httpClient: mock, token: AuthToken(jwt));

      await expectLater(
        sep38.price(
          context: 'sep31',
          sellAsset: sellAsset,
          buyAsset: buyAsset,
          sellAmount: '542',
        ),
        throwsA(isA<BadRequestDataException>().having(
            (e) => e.message, 'message', 'unsupported sell_asset')),
      );
    });

    test('prices(): HTTP 400 from quote server -> BadRequestDataException',
        () async {
      final mock = MockClient((request) async {
        return http.Response(
            json.encode({'error': 'missing sell_amount'}), 400);
      });

      final sep38 = Sep38(serviceAddress,
          httpClient: mock, token: AuthToken(jwt));

      await expectLater(
        sep38.prices(sellAsset: buyAsset, sellAmount: '100'),
        throwsA(isA<BadRequestDataException>()
            .having((e) => e.message, 'message', 'missing sell_amount')),
      );
    });

    test(
        'requestQuote(): HTTP 403 from quote server -> '
        'QuoteRequestPermissionDenied', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        return http.Response(json.encode({'error': 'SAD not allowed'}), 403);
      });

      final sep38 = Sep38(serviceAddress,
          httpClient: mock, token: AuthToken(jwt));

      await expectLater(
        sep38.requestQuote(
          context: 'sep31',
          sellAsset: sellAsset,
          buyAsset: buyAsset,
          buyAmount: '100',
        ),
        throwsA(isA<QuoteRequestPermissionDenied>()
            .having((e) => e.message, 'message', 'SAD not allowed')),
      );
    });

    test('requestQuote(): HTTP 400 from quote server -> BadRequestDataException',
        () async {
      final mock = MockClient((request) async {
        return http.Response(json.encode({'error': 'bad quote request'}), 400);
      });

      final sep38 = Sep38(serviceAddress,
          httpClient: mock, token: AuthToken(jwt));

      await expectLater(
        sep38.requestQuote(
          context: 'sep31',
          sellAsset: sellAsset,
          buyAsset: buyAsset,
          buyAmount: '100',
        ),
        throwsA(isA<BadRequestDataException>()
            .having((e) => e.message, 'message', 'bad quote request')),
      );
    });
  });

  group('requestQuote() outbound request body forwarding', () {
    // Minimal SEP38QuoteResponse JSON for a successful firm quote.
    String firmQuoteJson() => json.encode({
          'id': 'de762cda-a193-4961-861e-57b31fed6eb3',
          'expires_at': '2024-02-01T10:40:14+0000',
          'total_price': '5.42',
          'price': '5.00',
          'sell_asset': sellAsset,
          'sell_amount': '542',
          'buy_asset': buyAsset,
          'buy_amount': '100',
          'fee': {
            'total': '8.40',
            'asset': buyAsset,
          },
        });

    test(
        'forwards both sell_delivery_method and buy_delivery_method in the '
        'POST body', () async {
      late Map<String, dynamic> capturedBody;

      final mock = MockClient((request) async {
        capturedBody = json.decode(request.body) as Map<String, dynamic>;
        return http.Response(firmQuoteJson(), 200);
      });

      final sep38 = Sep38(serviceAddress,
          httpClient: mock, token: AuthToken(jwt));

      final response = await sep38.requestQuote(
        context: 'sep31',
        sellAsset: sellAsset,
        buyAsset: buyAsset,
        buyAmount: '100',
        sellDeliveryMethod: 'PIX',
        buyDeliveryMethod: 'ACH',
        countryCode: 'BRA',
      );

      expect(capturedBody['context'], 'sep31');
      expect(capturedBody['sell_asset'], sellAsset);
      expect(capturedBody['buy_asset'], buyAsset);
      expect(capturedBody['buy_amount'], '100');
      expect(capturedBody.containsKey('sell_amount'), isFalse);
      expect(capturedBody['sell_delivery_method'], 'PIX');
      expect(capturedBody['buy_delivery_method'], 'ACH');
      expect(capturedBody['country_code'], 'BRA');

      expect(response.id, 'de762cda-a193-4961-861e-57b31fed6eb3');
      expect(response.sellAsset, sellAsset);
      expect(response.buyAsset, buyAsset);
      expect(response.fee.total, '8.40');
    });
  });
}
