// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  // A real-looking, well formed Stellar account id used throughout the tests.
  const accountId =
      'GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7';

  // Horizon /accounts/<id> 404 error document shape. The base SDK's
  // ResponseHandler turns any status >= 400 into a flutter_sdk.ErrorResponse
  // whose .code is the HTTP status code.
  String notFoundBody() => json.encode({
        'type': 'https://stellar.org/horizon-errors/not_found',
        'title': 'Resource Missing',
        'status': 404,
        'detail':
            'The resource at the url requested was not found. This is usually '
                'occurs for one of two reasons: The url requested is not valid, '
                'or no data in our database could be found with the parameters '
                'provided.',
      });

  // Horizon 5xx error document shape (used to assert the non-404 path).
  String serverErrorBody() => json.encode({
        'type': 'https://stellar.org/horizon-errors/server_error',
        'title': 'Internal Server Error',
        'status': 500,
        'detail': 'An error occurred while processing this request.',
      });

  // A valid, fully populated Horizon account document that the base SDK's
  // AccountResponse.fromJson can parse. Shape mirrors the base SDK's own
  // account_response_test.dart fixtures.
  Map<String, dynamic> accountJson() => {
        'account_id': accountId,
        'sequence': '123456789012345',
        'paging_token': '123456789012345',
        'subentry_count': 1,
        'home_domain': 'example.com',
        'last_modified_ledger': 987654,
        'last_modified_time': '2024-01-15T10:30:00Z',
        'thresholds': {
          'low_threshold': 1,
          'med_threshold': 2,
          'high_threshold': 3,
        },
        'flags': {
          'auth_required': false,
          'auth_revocable': false,
          'auth_immutable': false,
          'auth_clawback_enabled': false,
        },
        'balances': [
          {
            'asset_type': 'native',
            'balance': '1000.0000000',
            'buying_liabilities': '0.0000000',
            'selling_liabilities': '0.0000000',
          },
        ],
        'signers': [
          {
            'key': accountId,
            'type': 'ed25519_public_key',
            'weight': 1,
          },
        ],
        'data': <String, dynamic>{},
        '_links': {
          'effects': {'href': '/accounts/test/effects'},
          'offers': {'href': '/accounts/test/offers'},
          'operations': {'href': '/accounts/test/operations'},
          'self': {'href': '/accounts/test'},
          'transactions': {'href': '/accounts/test/transactions'},
          'payments': {'href': '/accounts/test/payments'},
          'trades': {'href': '/accounts/test/trades'},
          'data': {'href': '/accounts/test/data/{key}', 'templated': true},
        },
        'num_sponsoring': 0,
        'num_sponsored': 0,
      };

  // A single Horizon payment operation record (type_i 1 -> PaymentOperation).
  Map<String, dynamic> paymentRecord(String id) => {
        '_links': {
          'self': {'href': '/operations/$id'},
          'transaction': {'href': '/transactions/txhash$id'},
          'effects': {'href': '/operations/$id/effects'},
          'succeeds': {'href': '/effects?order=desc&cursor=$id'},
          'precedes': {'href': '/effects?order=asc&cursor=$id'},
        },
        'id': id,
        'paging_token': id,
        'transaction_successful': true,
        'source_account': accountId,
        'type': 'payment',
        'type_i': 1,
        'created_at': '2024-01-15T10:30:00Z',
        'transaction_hash':
            'b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020',
        'asset_type': 'native',
        'from': accountId,
        'to': 'GDUKMGUGDZQK6YHYA5Z6AY2G4XDSZPSZ3SW5UN3ARVMO6QSRDWP5YLEX',
        'amount': '100.0000000',
      };

  // A Horizon page wrapping the given operation records.
  Map<String, dynamic> paymentsPage(List<Map<String, dynamic>> records) => {
        '_links': {
          'self': {'href': '/accounts/$accountId/payments?cursor=&limit=10'},
          'next': {'href': '/accounts/$accountId/payments?cursor=2&limit=10'},
          'prev': {'href': '/accounts/$accountId/payments?cursor=1&limit=10'},
        },
        '_embedded': {
          'records': records,
        },
      };

  // A single Horizon transaction record. Shape mirrors the base SDK's
  // TransactionResponse.fromJson required fields (memo_type, signatures, etc.).
  Map<String, dynamic> transactionRecord(String id) => {
        '_links': {
          'self': {'href': '/transactions/$id'},
          'account': {'href': '/accounts/$accountId'},
          'ledger': {'href': '/ledgers/987654'},
          'operations': {'href': '/transactions/$id/operations'},
          'effects': {'href': '/transactions/$id/effects'},
          'precedes': {'href': '/transactions?order=asc&cursor=$id'},
          'succeeds': {'href': '/transactions?order=desc&cursor=$id'},
        },
        'id': id,
        'paging_token': id,
        'successful': true,
        'hash': id,
        'ledger': 987654,
        'created_at': '2024-01-15T10:30:00Z',
        'source_account': accountId,
        'source_account_sequence': '123456789012340',
        'fee_account': accountId,
        'fee_charged': '100',
        'max_fee': '100',
        'operation_count': 1,
        'envelope_xdr': 'AAAAAg==',
        'result_xdr': 'AAAAAA==',
        'result_meta_xdr': 'AAAAAA==',
        'fee_meta_xdr': 'AAAAAA==',
        'memo_type': 'none',
        'signatures': ['c2lnbmF0dXJl'],
      };

  // A Horizon page wrapping the given transaction records.
  Map<String, dynamic> transactionsPage(
          List<Map<String, dynamic>> records) =>
      {
        '_links': {
          'self': {
            'href': '/accounts/$accountId/transactions?cursor=&limit=10'
          },
          'next': {
            'href': '/accounts/$accountId/transactions?cursor=2&limit=10'
          },
          'prev': {
            'href': '/accounts/$accountId/transactions?cursor=1&limit=10'
          },
        },
        '_embedded': {
          'records': records,
        },
      };

  // Helper that builds a wallet whose Horizon HTTP calls all route through the
  // supplied mock client via ApplicationConfiguration.defaultClient.
  AccountService accountServiceWith(http.Client mockClient) {
    final wallet = Wallet(
      StellarConfiguration.testNet,
      applicationConfiguration:
          ApplicationConfiguration(defaultClient: mockClient),
    );
    return wallet.stellar().account();
  }

  group('getInfo', () {
    test('returns parsed AccountResponse on a valid account document',
        () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/accounts/$accountId');
        return http.Response(json.encode(accountJson()), 200);
      });

      final account = await accountServiceWith(mock).getInfo(accountId);

      expect(account, isA<flutter_sdk.AccountResponse>());
      expect(account.accountId, accountId);
      expect(account.sequenceNumber, BigInt.parse('123456789012345'));
      expect(account.balances, hasLength(1));
      expect(account.balances.first.assetType, 'native');
      expect(account.balances.first.balance, '1000.0000000');
    });

    test('throws ValidationException when the account does not exist (404)',
        () async {
      final mock = MockClient((request) async {
        return http.Response(notFoundBody(), 404);
      });

      await expectLater(
        accountServiceWith(mock).getInfo(accountId),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws HorizonRequestFailedException on a non-404 error (500)',
        () async {
      final mock = MockClient((request) async {
        return http.Response(serverErrorBody(), 500);
      });

      await expectLater(
        accountServiceWith(mock).getInfo(accountId),
        throwsA(isA<HorizonRequestFailedException>()
            .having((e) => e.errorCode, 'errorCode', 500)),
      );
    });
  });

  group('accountExists', () {
    test('returns true when Horizon returns a valid account document',
        () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/accounts/$accountId');
        return http.Response(json.encode(accountJson()), 200);
      });

      final exists = await accountServiceWith(mock).accountExists(accountId);
      expect(exists, isTrue);
    });

    test('returns false when Horizon returns 404', () async {
      final mock = MockClient((request) async {
        return http.Response(notFoundBody(), 404);
      });

      final exists = await accountServiceWith(mock).accountExists(accountId);
      expect(exists, isFalse);
    });

    test('throws HorizonRequestFailedException on a non-404 error (500)',
        () async {
      final mock = MockClient((request) async {
        return http.Response(serverErrorBody(), 500);
      });

      await expectLater(
        accountServiceWith(mock).accountExists(accountId),
        throwsA(isA<HorizonRequestFailedException>()
            .having((e) => e.errorCode, 'errorCode', 500)),
      );
    });
  });

  group('loadRecentPayments', () {
    test('returns the payment records from the Horizon payments page',
        () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId') {
          // accountExists() probe.
          return http.Response(json.encode(accountJson()), 200);
        }
        if (request.url.path == '/accounts/$accountId/payments') {
          return http.Response(
              json.encode(paymentsPage([
                paymentRecord('1001'),
                paymentRecord('1002'),
              ])),
              200);
        }
        fail('Unexpected request path: ${request.url.path}');
      });

      final payments =
          await accountServiceWith(mock).loadRecentPayments(accountId);

      expect(payments, hasLength(2));
      expect(payments.first, isA<flutter_sdk.PaymentOperationResponse>());
      final first = payments.first as flutter_sdk.PaymentOperationResponse;
      expect(first.id, '1001');
      expect(first.amount, '100.0000000');
      expect(first.from, accountId);
    });

    test('returns an empty list when the account does not exist (404)',
        () async {
      var sawPayments = false;
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId/payments') {
          sawPayments = true;
        }
        // accountExists() probe returns 404 -> no payments request expected.
        return http.Response(notFoundBody(), 404);
      });

      final payments =
          await accountServiceWith(mock).loadRecentPayments(accountId);

      expect(payments, isEmpty);
      expect(sawPayments, isFalse,
          reason: 'payments must not be queried for a missing account');
    });

    test('honors an in-range limit by passing it through to Horizon',
        () async {
      String? capturedLimit;
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId') {
          return http.Response(json.encode(accountJson()), 200);
        }
        if (request.url.path == '/accounts/$accountId/payments') {
          capturedLimit = request.url.queryParameters['limit'];
          return http.Response(
              json.encode(paymentsPage([paymentRecord('1001')])), 200);
        }
        fail('Unexpected request path: ${request.url.path}');
      });

      await accountServiceWith(mock)
          .loadRecentPayments(accountId, limit: 25);

      expect(capturedLimit, '25');
    });

    test('clamps a limit above 100 to the 100 page maximum', () async {
      String? capturedLimit;
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId') {
          return http.Response(json.encode(accountJson()), 200);
        }
        if (request.url.path == '/accounts/$accountId/payments') {
          capturedLimit = request.url.queryParameters['limit'];
          return http.Response(
              json.encode(paymentsPage([paymentRecord('1001')])), 200);
        }
        fail('Unexpected request path: ${request.url.path}');
      });

      await accountServiceWith(mock)
          .loadRecentPayments(accountId, limit: 500);

      expect(capturedLimit, '100');
    });

    test('rejects a non-positive limit with a ValidationException', () async {
      final mock = MockClient((request) async {
        fail('No request should be made for an invalid limit: ${request.url}');
      });

      expect(
        () => accountServiceWith(mock).loadRecentPayments(accountId, limit: 0),
        throwsA(isA<ValidationException>()),
      );
    });

    test('requests payments in descending order', () async {
      String? capturedOrder;
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId') {
          return http.Response(json.encode(accountJson()), 200);
        }
        if (request.url.path == '/accounts/$accountId/payments') {
          capturedOrder = request.url.queryParameters['order'];
          return http.Response(
              json.encode(paymentsPage([paymentRecord('1001')])), 200);
        }
        fail('Unexpected request path: ${request.url.path}');
      });

      await accountServiceWith(mock).loadRecentPayments(accountId);

      expect(capturedOrder, 'desc');
    });
  });

  group('loadRecentTransactions', () {
    test('returns the transaction records from the Horizon transactions page',
        () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId') {
          return http.Response(json.encode(accountJson()), 200);
        }
        if (request.url.path == '/accounts/$accountId/transactions') {
          return http.Response(
              json.encode(transactionsPage([
                transactionRecord(
                    'aaaa0000000000000000000000000000000000000000000000000000000a'),
                transactionRecord(
                    'bbbb0000000000000000000000000000000000000000000000000000000b'),
              ])),
              200);
        }
        fail('Unexpected request path: ${request.url.path}');
      });

      final transactions =
          await accountServiceWith(mock).loadRecentTransactions(accountId);

      expect(transactions, hasLength(2));
      expect(transactions.first, isA<flutter_sdk.TransactionResponse>());
      expect(transactions.first.sourceAccount, accountId);
      expect(transactions.first.operationCount, 1);
      expect(transactions.first.feeCharged, 100);
    });

    test('returns an empty list when the account does not exist (404)',
        () async {
      var sawTransactions = false;
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId/transactions') {
          sawTransactions = true;
        }
        return http.Response(notFoundBody(), 404);
      });

      final transactions =
          await accountServiceWith(mock).loadRecentTransactions(accountId);

      expect(transactions, isEmpty);
      expect(sawTransactions, isFalse,
          reason: 'transactions must not be queried for a missing account');
    });

    test('honors an in-range limit by passing it through to Horizon',
        () async {
      String? capturedLimit;
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId') {
          return http.Response(json.encode(accountJson()), 200);
        }
        if (request.url.path == '/accounts/$accountId/transactions') {
          capturedLimit = request.url.queryParameters['limit'];
          return http.Response(
              json.encode(transactionsPage([
                transactionRecord(
                    'aaaa0000000000000000000000000000000000000000000000000000000a'),
              ])),
              200);
        }
        fail('Unexpected request path: ${request.url.path}');
      });

      await accountServiceWith(mock)
          .loadRecentTransactions(accountId, limit: 7);

      expect(capturedLimit, '7');
    });

    test('clamps a limit above 100 to the 100 page maximum', () async {
      String? capturedLimit;
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId') {
          return http.Response(json.encode(accountJson()), 200);
        }
        if (request.url.path == '/accounts/$accountId/transactions') {
          capturedLimit = request.url.queryParameters['limit'];
          return http.Response(
              json.encode(transactionsPage([
                transactionRecord(
                    'aaaa0000000000000000000000000000000000000000000000000000000a'),
              ])),
              200);
        }
        fail('Unexpected request path: ${request.url.path}');
      });

      await accountServiceWith(mock)
          .loadRecentTransactions(accountId, limit: 250);

      expect(capturedLimit, '100');
    });

    test('rejects a non-positive limit with a ValidationException', () async {
      final mock = MockClient((request) async {
        fail('No request should be made for an invalid limit: ${request.url}');
      });

      expect(
        () =>
            accountServiceWith(mock).loadRecentTransactions(accountId, limit: -5),
        throwsA(isA<ValidationException>()),
      );
    });

    test('requests transactions in descending order', () async {
      String? capturedOrder;
      final mock = MockClient((request) async {
        if (request.url.path == '/accounts/$accountId') {
          return http.Response(json.encode(accountJson()), 200);
        }
        if (request.url.path == '/accounts/$accountId/transactions') {
          capturedOrder = request.url.queryParameters['order'];
          return http.Response(
              json.encode(transactionsPage([
                transactionRecord(
                    'aaaa0000000000000000000000000000000000000000000000000000000a'),
              ])),
              200);
        }
        fail('Unexpected request path: ${request.url.path}');
      });

      await accountServiceWith(mock).loadRecentTransactions(accountId);

      expect(capturedOrder, 'desc');
    });
  });
}
