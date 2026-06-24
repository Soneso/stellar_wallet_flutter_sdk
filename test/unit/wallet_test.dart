// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// Unit tests for the Wallet SDK entry point (lib/src/wallet.dart).
///
/// These exercise the pure factory/configuration wiring of [Wallet],
/// [StellarConfiguration], [ApplicationConfiguration] and [Config], plus the
/// factory methods that produce [Stellar], [Anchor], [Recovery] and SEP-7
/// objects. Where a produced object needs an injected http client, a
/// package:http/testing MockClient is used so the assertions stay offline.
void main() {
  // A classic, valid base64 TransactionEnvelope XDR used to build a SEP-7 'tx'
  // URI. Borrowed from the existing uri_test.dart fixture.
  const classicTxXdr =
      'AAAAAgAAAACCMXQVfkjpO2gAJQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAGQABqQMAAAA'
      'AQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAACCMXQVfkjpO2gA'
      'JQzKsUsPfdBCyfrvy7sr8+35cOxOSwAAAAAAmJaAAAAAAAAAAAFw7E5LAAAAQBu4V+/l'
      'ttEONNM6KFwdSf5TEEogyEBy0jTOHJKuUzKScpLHyvDJGY+xH9Ri4cIuA7AaB8aL+Vdl'
      'ucCfsNYpKAY=';

  group('StellarConfiguration', () {
    test('testNet preset maps to the TESTNET network and testnet Horizon URL',
        () {
      final cfg = StellarConfiguration.testNet;
      expect(cfg.network, same(flutter_sdk.Network.TESTNET));
      expect(cfg.network.networkPassphrase,
          'Test SDF Network ; September 2015');
      expect(cfg.horizonUrl, 'https://horizon-testnet.stellar.org');
    });

    test('futureNet preset maps to the FUTURENET network and futurenet URL',
        () {
      final cfg = StellarConfiguration.futureNet;
      expect(cfg.network, same(flutter_sdk.Network.FUTURENET));
      expect(cfg.horizonUrl, 'https://horizon-futurenet.stellar.org');
    });

    test('publicNet preset maps to the PUBLIC network and public Horizon URL',
        () {
      final cfg = StellarConfiguration.publicNet;
      expect(cfg.network, same(flutter_sdk.Network.PUBLIC));
      expect(cfg.network.networkPassphrase,
          'Public Global Stellar Network ; September 2015');
      expect(cfg.horizonUrl, 'https://horizon.stellar.org');
    });

    test('named-argument defaults: MIN_BASE_FEE fee and a 3 minute timeout',
        () {
      final cfg = StellarConfiguration(
          flutter_sdk.Network.TESTNET, 'https://example.org');
      expect(cfg.baseFee, flutter_sdk.AbstractTransaction.MIN_BASE_FEE);
      expect(cfg.baseFee, 100);
      expect(cfg.defaultTimeout, const Duration(minutes: 3));
      expect(cfg.network, same(flutter_sdk.Network.TESTNET));
      expect(cfg.horizonUrl, 'https://example.org');
    });

    test('explicit baseFee and defaultTimeout override the defaults', () {
      final cfg = StellarConfiguration(
          flutter_sdk.Network.PUBLIC, 'https://horizon.example.org',
          baseFee: 500, defaultTimeout: const Duration(minutes: 7));
      expect(cfg.baseFee, 500);
      expect(cfg.defaultTimeout, const Duration(minutes: 7));
    });
  });

  group('ApplicationConfiguration', () {
    test('defaults: defaultSigner is a DefaultSigner, rest are null', () {
      final app = ApplicationConfiguration();
      expect(app.defaultSigner, isA<DefaultSigner>());
      expect(app.defaultClientDomain, isNull);
      expect(app.defaultClient, isNull);
      expect(app.defaultHttpRequestHeaders, isNull);
    });

    test('retains a provided signer instead of constructing a DefaultSigner',
        () {
      final signer = _RecordingSigner();
      final app = ApplicationConfiguration(defaultSigner: signer);
      expect(app.defaultSigner, same(signer));
    });

    test('passes through clientDomain, client and request headers', () {
      final mock = MockClient((request) async => http.Response('{}', 200));
      final headers = {'Authorization': 'Bearer token', 'X-Test': '1'};
      final app = ApplicationConfiguration(
        defaultClientDomain: 'client.example.org',
        defaultClient: mock,
        defaultHttpRequestHeaders: headers,
      );
      expect(app.defaultClientDomain, 'client.example.org');
      expect(app.defaultClient, same(mock));
      expect(app.defaultHttpRequestHeaders, same(headers));
      // The default signer is still installed when only other fields are given.
      expect(app.defaultSigner, isA<DefaultSigner>());
    });
  });

  group('Wallet presets', () {
    test('Wallet.testNet carries the testNet StellarConfiguration', () {
      expect(Wallet.testNet.stellarConfiguration, same(StellarConfiguration.testNet));
      expect(Wallet.testNet.stellarConfiguration.network,
          same(flutter_sdk.Network.TESTNET));
      expect(Wallet.testNet.stellarConfiguration.horizonUrl,
          'https://horizon-testnet.stellar.org');
    });

    test('Wallet.publicNet carries the publicNet StellarConfiguration', () {
      expect(Wallet.publicNet.stellarConfiguration,
          same(StellarConfiguration.publicNet));
      expect(Wallet.publicNet.stellarConfiguration.network,
          same(flutter_sdk.Network.PUBLIC));
      expect(Wallet.publicNet.stellarConfiguration.horizonUrl,
          'https://horizon.stellar.org');
    });

    test('Wallet.futureNet carries the futureNet StellarConfiguration', () {
      expect(Wallet.futureNet.stellarConfiguration,
          same(StellarConfiguration.futureNet));
      expect(Wallet.futureNet.stellarConfiguration.network,
          same(flutter_sdk.Network.FUTURENET));
      expect(Wallet.futureNet.stellarConfiguration.horizonUrl,
          'https://horizon-futurenet.stellar.org');
    });
  });

  group('Wallet constructor', () {
    test('without applicationConfiguration builds a default one', () {
      final wallet = Wallet(StellarConfiguration.testNet);
      expect(wallet.applicationConfiguration, isNotNull);
      expect(wallet.applicationConfiguration, isA<ApplicationConfiguration>());
      // The auto-built ApplicationConfiguration carries a DefaultSigner.
      expect(wallet.applicationConfiguration.defaultSigner,
          isA<DefaultSigner>());
      expect(wallet.applicationConfiguration.defaultClient, isNull);
    });

    test('retains a provided applicationConfiguration', () {
      final app = ApplicationConfiguration(
          defaultClientDomain: 'client.example.org');
      final wallet = Wallet(StellarConfiguration.publicNet,
          applicationConfiguration: app);
      expect(wallet.applicationConfiguration, same(app));
      expect(wallet.applicationConfiguration.defaultClientDomain,
          'client.example.org');
      expect(wallet.stellarConfiguration, same(StellarConfiguration.publicNet));
    });
  });

  group('Wallet.stellar', () {
    test('returns a Stellar whose Config carries the wallet configs', () {
      final app = ApplicationConfiguration();
      final wallet = Wallet(StellarConfiguration.testNet,
          applicationConfiguration: app);

      final stellar = wallet.stellar();
      expect(stellar, isA<Stellar>());
      expect(stellar.cfg.stellar, same(wallet.stellarConfiguration));
      expect(stellar.cfg.app, same(app));
      expect(stellar.cfg.stellar.horizonUrl,
          'https://horizon-testnet.stellar.org');
    });

    test('account() returns an AccountService bound to the same Config', () {
      final wallet = Wallet(StellarConfiguration.testNet);
      final stellar = wallet.stellar();
      final account = stellar.account();
      expect(account, isA<AccountService>());
      expect(account.cfg, same(stellar.cfg));
    });

    test('the injected default client is reachable through the built sdk',
        () async {
      const accountId =
          'GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7';
      var hitHorizon = false;
      final mock = MockClient((request) async {
        hitHorizon = true;
        expect(request.url.host, 'horizon-testnet.stellar.org');
        expect(request.url.path, '/accounts/$accountId');
        return http.Response(_accountJson(accountId), 200);
      });

      final wallet = Wallet(
        StellarConfiguration.testNet,
        applicationConfiguration:
            ApplicationConfiguration(defaultClient: mock),
      );

      final response = await wallet.stellar().account().getInfo(accountId);
      expect(hitHorizon, isTrue);
      expect(response.accountId, accountId);
    });
  });

  group('Wallet.anchor', () {
    test('returns an Anchor with the given home domain and the wallet Config',
        () {
      final wallet = Wallet(StellarConfiguration.testNet);
      final anchor = wallet.anchor('anchor.example.org');
      expect(anchor, isA<Anchor>());
      expect(anchor.homeDomain, 'anchor.example.org');
      expect(anchor.cfg.stellar, same(wallet.stellarConfiguration));
      expect(anchor.cfg.app, same(wallet.applicationConfiguration));
    });

    test('forwards the explicitly supplied client and request headers', () {
      final mock = MockClient((request) async => http.Response('{}', 200));
      final headers = {'X-Anchor': 'yes'};
      final wallet = Wallet(StellarConfiguration.testNet);
      final anchor = wallet.anchor('anchor.example.org',
          httpClient: mock, httpRequestHeaders: headers);
      expect(anchor.httpClient, same(mock));
      expect(anchor.httpRequestHeaders, same(headers));
    });

    test('falls back to the ApplicationConfiguration defaults for client/headers',
        () {
      final mock = MockClient((request) async => http.Response('{}', 200));
      final headers = {'X-Default': 'header'};
      final wallet = Wallet(
        StellarConfiguration.testNet,
        applicationConfiguration: ApplicationConfiguration(
            defaultClient: mock, defaultHttpRequestHeaders: headers),
      );
      final anchor = wallet.anchor('anchor.example.org');
      expect(anchor.httpClient, same(mock));
      expect(anchor.httpRequestHeaders, same(headers));
    });
  });

  group('Wallet.recovery', () {
    final servers = <RecoveryServerKey, RecoveryServer>{
      RecoveryServerKey('first'): RecoveryServer('https://recovery.example.org',
          'https://auth.example.org', 'recovery.example.org'),
    };

    test('returns a Recovery carrying the wallet Config and servers', () {
      final wallet = Wallet(StellarConfiguration.testNet);
      final recovery = wallet.recovery(servers);
      expect(recovery, isA<Recovery>());
      expect(recovery.cfg.stellar, same(wallet.stellarConfiguration));
      expect(recovery.cfg.app, same(wallet.applicationConfiguration));
      expect(recovery.servers, same(servers));
      expect(recovery.stellar, same(wallet.stellarConfiguration));
    });

    test('forwards an explicitly supplied http client and headers', () {
      final mock = MockClient((request) async => http.Response('{}', 200));
      final headers = {'X-Recovery': 'yes'};
      final wallet = Wallet(StellarConfiguration.testNet);
      final recovery = wallet.recovery(servers,
          httpClient: mock, httpRequestHeaders: headers);
      expect(recovery.httpClient, same(mock));
      expect(recovery.httpRequestHeaders, same(headers));
    });

    test('falls back to ApplicationConfiguration defaults for client/headers',
        () {
      final mock = MockClient((request) async => http.Response('{}', 200));
      final headers = {'X-Default-Recovery': 'header'};
      final wallet = Wallet(
        StellarConfiguration.testNet,
        applicationConfiguration: ApplicationConfiguration(
            defaultClient: mock, defaultHttpRequestHeaders: headers),
      );
      final recovery = wallet.recovery(servers);
      expect(recovery.httpClient, same(mock));
      expect(recovery.httpRequestHeaders, same(headers));
    });
  });

  group('Wallet.parseSep7Uri', () {
    test('parses a valid tx URI into a Sep7Tx that round-trips the xdr',
        () {
      // Build a valid 'tx' URI from a known transaction, then parse it back.
      final sep7Source = Sep7Tx.forTransaction(
          flutter_sdk.AbstractTransaction.fromEnvelopeXdrString(classicTxXdr));
      final uri = sep7Source.toString();

      final wallet = Wallet(StellarConfiguration.testNet);
      final parsed = wallet.parseSep7Uri(uri);

      expect(parsed, isA<Sep7Tx>());
      expect((parsed as Sep7Tx).getXdr(), classicTxXdr);
      expect(parsed.operationType, Sep7OperationType.tx);
    });

    test('throws Sep7InvalidUri on an invalid URI without any network call',
        () {
      final mock = MockClient((request) async {
        fail('parseSep7Uri must not perform any network request');
      });
      final wallet = Wallet(StellarConfiguration.testNet);
      expect(
        () => wallet.parseSep7Uri('web+stellar:tx?xdr=not-valid-xdr',
            httpClient: mock),
        throwsA(isA<Sep7InvalidUri>()),
      );
    });
  });

  group('Config', () {
    test('wires the stellar and app fields exactly as supplied', () {
      final stellarCfg = StellarConfiguration.futureNet;
      final appCfg = ApplicationConfiguration();
      final config = Config(stellarCfg, appCfg);
      expect(config.stellar, same(stellarCfg));
      expect(config.app, same(appCfg));
    });
  });

  group('Wallet.versionNumber', () {
    test('is a non-empty, version-shaped string', () {
      expect(Wallet.versionNumber, isNotEmpty);
      // Must look like a semantic version (e.g. "1.2.3").
      expect(
          RegExp(r'^\d+\.\d+\.\d+$').hasMatch(Wallet.versionNumber), isTrue,
          reason:
              'versionNumber should be a dotted semantic version string');
    });
  });
}

/// Minimal WalletSigner used to assert that a provided signer is retained.
class _RecordingSigner extends WalletSigner {
  @override
  void signWithClientAccount(
      {required flutter_sdk.AbstractTransaction tnx,
      required flutter_sdk.Network network,
      required AccountKeyPair account}) {}

  @override
  Future<String> signWithDomainAccount(
      {required String transactionXDR,
      required String networkPassPhrase}) async {
    return transactionXDR;
  }
}

/// A valid, fully populated Horizon account document parseable by the base
/// SDK's AccountResponse.fromJson.
String _accountJson(String accountId) => json.encode({
      'account_id': accountId,
      'sequence': '123456789012345',
      'paging_token': '123456789012345',
      'subentry_count': 1,
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
        'self': {'href': '/accounts/$accountId'},
        'transactions': {'href': '/accounts/$accountId/transactions'},
        'operations': {'href': '/accounts/$accountId/operations'},
        'payments': {'href': '/accounts/$accountId/payments'},
        'effects': {'href': '/accounts/$accountId/effects'},
        'offers': {'href': '/accounts/$accountId/offers'},
        'trades': {'href': '/accounts/$accountId/trades'},
        'data': {'href': '/accounts/$accountId/data/{key}', 'templated': true},
      },
      'num_sponsoring': 0,
      'num_sponsored': 0,
    });
